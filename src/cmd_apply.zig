const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");
const edit_support = @import("edit_support.zig");
const file_lock = @import("lock.zig");
const symbols = @import("symbols.zig");
const workspace = @import("workspace.zig");
const apply_payload = @import("apply_payload.zig");
const apply_metrics = @import("apply_metrics.zig");
const apply_ops = @import("apply_ops.zig");
const apply_response = @import("apply_response.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = Io.Dir;
const MAX_SOURCE_BYTES = apply_payload.MAX_SOURCE_BYTES;
const ApplyOperation = apply_payload.ApplyOperation;
const TargetRange = apply_payload.TargetRange;
const MatchSelector = apply_payload.MatchSelector;
const ApplyRequest = apply_payload.ApplyRequest;
const RangesResult = apply_payload.RangesResult;
const ApplyResult = apply_payload.ApplyResult;
const MatchSpan = apply_payload.MatchSpan;
const OpResult = apply_payload.OpResult;
const MultiEdit = apply_payload.MultiEdit;
const ComposeResult = apply_payload.ComposeResult;
const KeepSliceResult = apply_payload.KeepSliceResult;
const EditSpan = apply_payload.EditSpan;
const ApplyError = apply_payload.ApplyError;

pub fn run(
    allocator: Allocator,
    io: Io,
    request_bytes: []const u8,
    cli_dry_run: bool,
    diff_requested: bool,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
) !u8 {
    const start = Io.Clock.awake.now(io);

    const parsed = std.json.parseFromSlice(ApplyRequest, allocator, request_bytes, .{}) catch |err| {
        return emitFailure(err, null, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer parsed.deinit();

    const req = parsed.value;

    if (req.version != 1) return emitFailure(ApplyError.UnsupportedVersion, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (req.file.len == 0) return emitFailure(ApplyError.MissingFile, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const operation = parseOperation(req.operation) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    if (operation != .multi_body and operation != .patch) {
        const target = req.target orelse return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        if (target.symbol.len == 0) return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }

    const target_range = if (operation == .multi_body or operation == .patch) TargetRange.body else parseTargetRange(req.target.?.range) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    const require_single_match = if (req.options) |opts| opts.requireSingleMatch orelse true else true;
    const dry_run = if (cli_dry_run) true else if (req.options) |opts| opts.dryRun orelse false else false;

    const ext = std.fs.path.extension(req.file);
    const lang = bindings.Language.fromExtension(ext) orelse {
        return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    const real_path = Dir.cwd().realPathFileAlloc(io, req.file, allocator) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer allocator.free(real_path);
    workspace.enforce(real_path) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    const original = Dir.cwd().readFileAlloc(io, real_path, allocator, .limited(MAX_SOURCE_BYTES)) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer allocator.free(original);

    var parser = bindings.Parser.init();
    defer parser.deinit();
    if (!parser.setLanguage(lang)) return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    var source_tree = parser.parseString(original) orelse return emitFailure(ApplyError.ParseFailedBefore, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer source_tree.deinit();

    const root = source_tree.rootNode();
    if (root.isNull() or root.hasError()) return emitFailure(ApplyError.ParseFailedBefore, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const target_node: ?bindings.Node = if (operation == .multi_body or operation == .patch) null else symbols.findEditableSymbolNode(original, root, req.target.?.symbol);
    if (operation != .multi_body and operation != .patch and target_node == null) {
        return emitFailure(ApplyError.SymbolNotFound, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }

    const target_start: usize = if (target_node) |node| @intCast(node.startByte()) else 0;
    const target_end: usize = if (target_node) |node| @intCast(node.endByte()) else 0;
    const body_range = if (operation == .multi_body or operation == .insert_after_symbol)
        edit_support.ByteRange{ .start = target_start, .end = target_end }
    else if (operation == .patch)
        edit_support.ByteRange{ .start = 0, .end = 0 }
    else
        edit_support.replacementRangeFor(lang, original, target_node.?);

    const op_result_result: anyerror!OpResult = switch (operation) {
        .replace_body_span => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const find = try requireString(edit_obj, "find");
            const replace = try requireString(edit_obj, "replace");
            const selector = parseMatchSelector(edit_obj.get("occurrence"));
            const match = selectMatch(original[body_range.start..body_range.end], find, selector, require_single_match) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const edit_start = body_range.start + match.start;
            const edit_end = body_range.start + match.end;
            break :blk OpResult{
                .contents = try spliceText(allocator, original, edit_start, edit_end, replace),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = edit_start, .editEnd = edit_end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replace.len,
            };
        },
        .insert_body_span => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const anchor = try requireString(edit_obj, "anchor");
            const text = try requireString(edit_obj, "text");
            const raw_pos = try requireString(edit_obj, "position");
            const selector = parseMatchSelector(edit_obj.get("occurrence"));
            const match = selectMatch(original[body_range.start..body_range.end], anchor, selector, require_single_match) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const insert_at = if (std.mem.eql(u8, raw_pos, "after"))
                body_range.start + match.end
            else if (std.mem.eql(u8, raw_pos, "before"))
                body_range.start + match.start
            else
                return emitFailure(ApplyError.InvalidPosition, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            break :blk OpResult{
                .contents = try spliceText(allocator, original, insert_at, insert_at, text),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = insert_at, .editEnd = insert_at },
                .single_match = match.single_match,
                .changed_before = 0,
                .changed_after = text.len,
            };
        },
        .wrap_body => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const before = try requireString(edit_obj, "before");
            const keep = try requireString(edit_obj, "keep");
            const after = try requireString(edit_obj, "after");
            if (!std.mem.eql(u8, keep, "body")) return emitFailure(ApplyError.FieldTypeMismatch, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const indent = if (edit_obj.get("indentKeptBodyBy")) |indent_raw| switch (indent_raw) {
                .integer => |v| if (v < 0) return emitFailure(ApplyError.InvalidOccurrence, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len) else @as(usize, @intCast(v)),
                .float => |v| float_blk: {
                    const rounded = @round(v);
                    if (v < 0 or rounded != v) return emitFailure(ApplyError.InvalidOccurrence, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
                    break :float_blk @as(usize, @intFromFloat(rounded));
                },
                else => 0,
            } else 0;

            const body = original[body_range.start..body_range.end];
            const kept_body = if (indent == 0) try allocator.dupe(u8, body) else try indentBody(allocator, body, indent);
            defer allocator.free(kept_body);
            const wrapped = try concat3(allocator, before, kept_body, after);
            defer allocator.free(wrapped);
            break :blk OpResult{
                .contents = try spliceText(allocator, original, body_range.start, body_range.end, wrapped),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body.len,
                .changed_after = wrapped.len,
            };
        },
        .compose_body => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const segments = requireArray(edit_obj, "segments") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);

            const compose = composeBody(
                allocator,
                original[body_range.start..body_range.end],
                segments,
                require_single_match,
            ) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);

            const new_contents = try spliceText(allocator, original, body_range.start, body_range.end, compose.contents);
            defer allocator.free(compose.contents);

            break :blk OpResult{
                .contents = new_contents,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = compose.single_match,
                .changed_before = body_range.end - body_range.start,
                .changed_after = compose.contents.len,
            };
        },
        .insert_after_symbol => blk: {
            const edit_obj = try expectObject(req.edit);
            const code = try requireString(edit_obj, "code");
            break :blk OpResult{
                .contents = try spliceText(allocator, original, target_end, target_end, code),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = target_start, .bodyEnd = target_end, .editStart = target_end, .editEnd = target_end },
                .single_match = true,
                .changed_before = 0,
                .changed_after = code.len,
            };
        },
        .set_body => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const body = try requireString(edit_obj, "body");
            break :blk OpResult{
                .contents = try spliceText(allocator, original, body_range.start, body_range.end, body),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body_range.end - body_range.start,
                .changed_after = body.len,
            };
        },
        .patch => makeCompactPatchOp(
            allocator,
            lang,
            root,
            original,
            req.edit,
            require_single_match,
        ),
        .multi_body => makeMultiBodyOp(
            allocator,
            lang,
            root,
            original,
            req.edit,
            require_single_match,
        ),
    };

    const op_result = op_result_result catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);

    defer allocator.free(op_result.contents);

    var parse_after: bool = undefined;
    if (operation == .multi_body or operation == .patch) {
        var final_tree = parser.parseString(op_result.contents) orelse return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
        defer final_tree.deinit();
        parse_after = !final_tree.rootNode().isNull() and !final_tree.rootNode().hasError();
    } else {
        if (edit_support.validateEditedSourceIncremental(&parser, &source_tree, original, op_result.contents)) {
            parse_after = true;
        } else |_| {
            parse_after = false;
        }
    }

    if (!parse_after) {
        return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    }

    const changed = !std.mem.eql(u8, original, op_result.contents);
    if (changed and !dry_run) {
        var lock_guard = try file_lock.acquire(allocator, io, real_path);
        defer lock_guard.release();
        const cache_dir = try backup.defaultCacheDir(allocator);
        defer allocator.free(cache_dir);
        try backup.store(allocator, io, cache_dir, real_path, original);
        try backup.atomicWrite(allocator, io, real_path, op_result.contents);
    }

    const end = Io.Clock.awake.now(io);
    const wall_ms = start.durationTo(end).toMilliseconds();
    const status = apply_metrics.statusLabel(dry_run, changed);
    const diffSummary = try apply_metrics.diffSummary(allocator, op_result, changed);
    defer allocator.free(diffSummary);

    const result = apply_metrics.buildResult(
        status,
        req.operation,
        real_path,
        if (req.target) |target| target.symbol else "",
        lang,
        dry_run,
        changed,
        parse_after,
        op_result,
        original.len,
        request_bytes.len,
        @intCast(wall_ms),
        diffSummary,
        diff_requested,
    );

    return apply_response.emitSuccess(result, json_output, changed, dry_run, req.file, status, stdout);
}

const emitFailure = apply_response.emitFailure;
const parseOperation = apply_ops.parseOperation;
const parseTargetRange = apply_ops.parseTargetRange;
const requireArray = apply_ops.requireArray;
const requireOptionalString = apply_ops.requireOptionalString;
const requireOptionalBool = apply_ops.requireOptionalBool;

fn composeBody(
    allocator: Allocator,
    body: []const u8,
    segments: std.json.Array,
    require_single_match: bool,
) !ComposeResult {
    if (segments.items.len == 0) return ApplyError.PatternEmpty;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var all_single_match = true;

    for (segments.items) |segment| {
        const segment_obj = switch (segment) {
            .object => |obj| obj,
            else => return ApplyError.FieldTypeMismatch,
        };

        var has_text = false;
        var has_keep = false;
        var it = segment_obj.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, "text")) {
                has_text = true;
                continue;
            }
            if (std.mem.eql(u8, entry.key_ptr.*, "keep")) {
                has_keep = true;
                continue;
            }
            return ApplyError.FieldTypeMismatch;
        }

        if (has_text == has_keep) return ApplyError.FieldTypeMismatch;

        if (segment_obj.get("text")) |text_node| {
            const text = switch (text_node) {
                .string => |value| value,
                else => return ApplyError.FieldTypeMismatch,
            };
            try out.appendSlice(allocator, text);
            continue;
        }

        const keep = segment_obj.get("keep").?;
        const keep_slice = switch (keep) {
            .string => |keep_text| blk: {
                if (!std.mem.eql(u8, keep_text, "body")) return ApplyError.FieldTypeMismatch;
                break :blk KeepSliceResult{ .span = .{ .start = 0, .end = body.len }, .single_match = true };
            },
            .object => |keep_obj| try parseKeepSpan(body, keep_obj, require_single_match),
            else => return ApplyError.FieldTypeMismatch,
        };

        const body_span = body[keep_slice.span.start..keep_slice.span.end];
        try out.appendSlice(allocator, body_span);
        all_single_match = all_single_match and keep_slice.single_match;
    }

    return ComposeResult{
        .contents = try out.toOwnedSlice(allocator),
        .single_match = all_single_match,
    };
}

fn parseKeepSpan(
    body: []const u8,
    keep_obj: std.json.ObjectMap,
    require_single_match: bool,
) !KeepSliceResult {
    var it = keep_obj.iterator();
    while (it.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "beforeKeep") and
            !std.mem.eql(u8, entry.key_ptr.*, "afterKeep") and
            !std.mem.eql(u8, entry.key_ptr.*, "includeBefore") and
            !std.mem.eql(u8, entry.key_ptr.*, "includeAfter") and
            !std.mem.eql(u8, entry.key_ptr.*, "occurrence")) return ApplyError.FieldTypeMismatch;
    }

    const before_keep = try requireOptionalString(keep_obj, "beforeKeep");
    const after_keep = try requireOptionalString(keep_obj, "afterKeep");
    if (before_keep == null and after_keep == null) return ApplyError.FieldTypeMismatch;

    const include_before = if (try requireOptionalBool(keep_obj, "includeBefore")) |value| value else false;
    const include_after = if (try requireOptionalBool(keep_obj, "includeAfter")) |value| value else false;
    const selector = parseMatchSelector(keep_obj.get("occurrence"));
    const require_single = if (selector.kind == .default_single) require_single_match else false;

    const before_match = if (before_keep) |needle| try selectMatch(body, needle, selector, require_single) else null;
    const after_match = if (after_keep) |needle| try selectMatch(body, needle, selector, require_single) else null;

    const start: usize = if (before_match) |match| if (include_before) match.start else match.end else 0;
    const end: usize = if (after_match) |match| if (include_after) match.end else match.start else body.len;

    if (start > end) return ApplyError.InvalidPosition;

    return KeepSliceResult{
        .span = .{ .start = start, .end = end },
        .single_match = (before_match == null or before_match.?.single_match) and (after_match == null or after_match.?.single_match),
    };
}

const parseMatchSelector = apply_ops.parseMatchSelector;
const selectMatch = apply_ops.selectMatch;
const selectSpanFromCandidates = apply_ops.selectSpanFromCandidates;

fn resolveCompactPatchEdits(
    allocator: Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    source: []const u8,
    ops: std.json.Array,
    require_single_match: bool,
) ![]MultiEdit {
    if (ops.items.len == 0) return ApplyError.PatternEmpty;

    var resolved = std.ArrayList(MultiEdit).empty;
    errdefer {
        for (resolved.items) |entry| {
            if (entry.replacement_owned) allocator.free(entry.replacement);
        }
        resolved.deinit(allocator);
    }

    for (ops.items) |op_item| {
        const op_arr = switch (op_item) {
            .array => |arr| arr,
            else => return ApplyError.FieldTypeMismatch,
        };
        if (op_arr.items.len < 2) return ApplyError.MissingField;

        const op_name = try requireTupleString(op_arr, 0);
        const symbol = try requireTupleString(op_arr, 1);
        const target_node = symbols.findEditableSymbolNode(source, root, symbol) orelse return ApplyError.SymbolNotFound;
        const target_start: usize = @intCast(target_node.startByte());
        const target_end: usize = @intCast(target_node.endByte());
        const body_range = edit_support.replacementRangeFor(lang, source, target_node);
        const body = source[body_range.start..body_range.end];

        if (std.mem.eql(u8, op_name, "replace")) {
            if (op_arr.items.len < 4) return ApplyError.MissingField;
            const find = try requireTupleString(op_arr, 2);
            const replace = try requireTupleString(op_arr, 3);
            const selector = parseMatchSelector(tupleOptionalValue(op_arr, 4));
            const match = try selectMatch(body, find, selector, require_single_match);
            const edit_start = body_range.start + match.start;
            const edit_end = body_range.start + match.end;
            try resolved.append(allocator, .{
                .start = edit_start,
                .end = edit_end,
                .replacement = replace,
                .replacement_owned = false,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = edit_start, .editEnd = edit_end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replace.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "insert_after")) {
            if (op_arr.items.len < 4) return ApplyError.MissingField;
            const anchor = try requireTupleString(op_arr, 2);
            const text = try requireTupleString(op_arr, 3);
            const selector = parseMatchSelector(tupleOptionalValue(op_arr, 4));
            const match = try selectMatch(body, anchor, selector, require_single_match);
            const insert_at = body_range.start + match.end;
            try resolved.append(allocator, .{
                .start = insert_at,
                .end = insert_at,
                .replacement = text,
                .replacement_owned = false,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = insert_at, .editEnd = insert_at },
                .single_match = match.single_match,
                .changed_before = 0,
                .changed_after = text.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "wrap")) {
            if (op_arr.items.len < 4) return ApplyError.MissingField;
            const before = try requireTupleString(op_arr, 2);
            const after = try requireTupleString(op_arr, 3);
            const indent = try tupleOptionalIndent(op_arr, 4, 0);
            const kept_body = if (indent == 0) try allocator.dupe(u8, body) else try indentBody(allocator, body, indent);
            defer allocator.free(kept_body);
            const wrapped = try concat3(allocator, before, kept_body, after);
            try resolved.append(allocator, .{
                .start = body_range.start,
                .end = body_range.end,
                .replacement = wrapped,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body.len,
                .changed_after = wrapped.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "replace_return")) {
            if (op_arr.items.len < 3) return ApplyError.MissingField;
            const expr = try requireTupleString(op_arr, 2);
            const selector = parseMatchSelector(tupleOptionalValue(op_arr, 3));
            const body_node = edit_support.findBodyNode(target_node) orelse return ApplyError.UnsupportedMultiEditOperation;
            const returns = try collectReturnStatements(allocator, source, body_node);
            defer allocator.free(returns);
            const match = try selectSpanFromCandidates(returns, selector, require_single_match);
            const replacement = try buildReturnReplacement(allocator, lang, expr);
            try resolved.append(allocator, .{
                .start = match.start,
                .end = match.end,
                .replacement = replacement,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = match.start, .editEnd = match.end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replacement.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "try_catch")) {
            if (op_arr.items.len < 3) return ApplyError.MissingField;
            if (lang != .typescript and lang != .tsx) return ApplyError.UnsupportedMultiEditOperation;
            const catch_body = try normalizeMultilineTrim(allocator, try requireTupleString(op_arr, 2));
            defer allocator.free(catch_body);
            const indent = try tupleOptionalIndent(op_arr, 3, 2);
            const wrapped = try buildTryCatchWrapped(allocator, body, catch_body, indent);
            try resolved.append(allocator, .{
                .start = body_range.start,
                .end = body_range.end,
                .replacement = wrapped,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body.len,
                .changed_after = wrapped.len,
            });
            continue;
        }

        return ApplyError.UnsupportedMultiEditOperation;
    }

    return resolved.toOwnedSlice(allocator);
}

fn collectReturnStatements(allocator: Allocator, source: []const u8, node: bindings.Node) ![]EditSpan {
    var spans = std.ArrayList(EditSpan).empty;
    errdefer spans.deinit(allocator);
    try collectReturnStatementsRecursive(allocator, &spans, source, node);
    return spans.toOwnedSlice(allocator);
}

fn collectReturnStatementsRecursive(allocator: Allocator, list: *std.ArrayList(EditSpan), source: []const u8, node: bindings.Node) !void {
    const kind = node.kind();
    if (isReturnNodeKind(kind)) {
        try list.append(allocator, .{ .start = @intCast(node.startByte()), .end = @intCast(node.endByte()) });
        return;
    }

    const child_count = node.namedChildCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.namedChild(i)) |child| {
            try collectReturnStatementsRecursive(allocator, list, source, child);
        }
    }
}

fn isReturnNodeKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "return_statement") or std.mem.eql(u8, kind, "return_expression");
}

fn buildReturnReplacement(allocator: Allocator, lang: bindings.Language, expr: []const u8) ![]u8 {
    const cleaned = trimReturnExpr(expr);
    const suffix = switch (lang) {
        .python => "",
        else => ";",
    };
    return concat3(allocator, "return ", cleaned, suffix);
}

fn trimAscii(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t\r\n");
}

fn trimReturnExpr(value: []const u8) []const u8 {
    var cleaned = trimAscii(value);
    if (cleaned.len > 0 and cleaned[cleaned.len - 1] == ';') {
        cleaned = trimAscii(cleaned[0 .. cleaned.len - 1]);
    }
    return cleaned;
}

fn normalizeMultilineTrim(allocator: Allocator, value: []const u8) ![]u8 {
    const cleaned = trimAscii(value);
    var out = std.ArrayList(u8).empty;
    var it = std.mem.splitScalar(u8, cleaned, '\n');
    var first = true;
    while (it.next()) |line| {
        if (!first) try out.append(allocator, '\n');
        first = false;
        try out.appendSlice(allocator, trimAscii(line));
    }
    return out.toOwnedSlice(allocator);
}

fn requireTupleString(items: std.json.Array, index: usize) ![]const u8 {
    if (index >= items.items.len) return ApplyError.MissingField;
    return switch (items.items[index]) {
        .string => |value| value,
        else => ApplyError.FieldTypeMismatch,
    };
}

fn tupleOptionalValue(items: std.json.Array, index: usize) ?std.json.Value {
    if (index >= items.items.len) return null;
    return items.items[index];
}

fn tupleOptionalIndent(items: std.json.Array, index: usize, default_value: usize) !usize {
    const value = tupleOptionalValue(items, index) orelse return default_value;
    return switch (value) {
        .integer => |v| if (v < 0) return ApplyError.InvalidOccurrence else @as(usize, @intCast(v)),
        .float => |v| blk: {
            const rounded = @round(v);
            if (v < 0 or rounded != v) return ApplyError.InvalidOccurrence;
            break :blk @as(usize, @intFromFloat(rounded));
        },
        else => ApplyError.FieldTypeMismatch,
    };
}

fn concat4(allocator: Allocator, a: []const u8, b: []const u8, c: []const u8, d: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len + c.len + d.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len .. a.len + b.len], b);
    @memcpy(out[a.len + b.len .. a.len + b.len + c.len], c);
    @memcpy(out[a.len + b.len + c.len ..], d);
    return out;
}

fn concat5(allocator: Allocator, a: []const u8, b: []const u8, c: []const u8, d: []const u8, e: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len + c.len + d.len + e.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len .. a.len + b.len], b);
    @memcpy(out[a.len + b.len .. a.len + b.len + c.len], c);
    @memcpy(out[a.len + b.len + c.len .. a.len + b.len + c.len + d.len], d);
    @memcpy(out[a.len + b.len + c.len + d.len ..], e);
    return out;
}

fn makeCompactPatchOp(
    allocator: Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    original: []const u8,
    edit_value: std.json.Value,
    require_single_match: bool,
) !OpResult {
    const edit_obj = try expectObject(edit_value);
    const ops = try requireArray(edit_obj, "ops");
    const patch = try resolveCompactPatchEdits(
        allocator,
        lang,
        root,
        original,
        ops,
        require_single_match,
    );
    defer {
        for (patch) |edit| {
            if (edit.replacement_owned) allocator.free(edit.replacement);
        }
        allocator.free(patch);
    }

    const contents = try applyResolvedEdits(allocator, original, patch);
    return OpResult{
        .contents = contents,
        .range = combinedRangeFromEdits(patch),
        .single_match = allSingleMatch(patch),
        .changed_before = totalChangedBefore(patch),
        .changed_after = totalChangedAfter(patch),
    };
}

fn makeMultiBodyOp(
    allocator: Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    original: []const u8,
    edit_value: std.json.Value,
    require_single_match: bool,
) !OpResult {
    const edit_obj = try expectObject(edit_value);
    const edits = try requireArray(edit_obj, "edits");
    const resolved = try resolveMultiBodyEdits(
        allocator,
        lang,
        root,
        original,
        edits,
        require_single_match,
    );
    defer {
        for (resolved) |edit| {
            if (edit.replacement_owned) allocator.free(edit.replacement);
        }
        allocator.free(resolved);
    }

    const out = try applyResolvedEdits(allocator, original, resolved);
    const combined = combinedRangeFromEdits(resolved);
    return OpResult{
        .contents = out,
        .range = combined,
        .single_match = allSingleMatch(resolved),
        .changed_before = totalChangedBefore(resolved),
        .changed_after = totalChangedAfter(resolved),
    };
}

fn resolveMultiBodyEdits(
    allocator: Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    source: []const u8,
    edits: std.json.Array,
    require_single_match: bool,
) ![]MultiEdit {
    if (edits.items.len == 0) return ApplyError.PatternEmpty;

    var resolved = std.ArrayList(MultiEdit).empty;
    errdefer {
        for (resolved.items) |entry| {
            if (entry.replacement_owned) allocator.free(entry.replacement);
        }
        resolved.deinit(allocator);
    }

    for (edits.items) |edit_item| {
        const edit_obj = switch (edit_item) {
            .object => |obj| obj,
            else => return ApplyError.FieldTypeMismatch,
        };

        const symbol = try requireString(edit_obj, "symbol");
        const op_raw = try requireString(edit_obj, "op");
        const op = try parseOperation(op_raw);

        const target_node = symbols.findEditableSymbolNode(source, root, symbol) orelse {
            return ApplyError.SymbolNotFound;
        };

        const target_start: usize = @intCast(target_node.startByte());
        const target_end: usize = @intCast(target_node.endByte());
        const body_range = edit_support.replacementRangeFor(lang, source, target_node);

        switch (op) {
            .patch, .set_body => return ApplyError.UnsupportedMultiEditOperation,
            .replace_body_span => {
                const find = try requireString(edit_obj, "find");
                const replace = try requireString(edit_obj, "replace");
                const selector = parseMatchSelector(edit_obj.get("occurrence"));
                const match = try selectMatch(source[body_range.start..body_range.end], find, selector, require_single_match);
                const edit_start = body_range.start + match.start;
                const edit_end = body_range.start + match.end;
                const range = RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = edit_start,
                    .editEnd = edit_end,
                };
                try resolved.append(allocator, .{
                    .start = edit_start,
                    .end = edit_end,
                    .replacement = replace,
                    .replacement_owned = false,
                    .range = range,
                    .single_match = match.single_match,
                    .changed_before = match.end - match.start,
                    .changed_after = replace.len,
                });
            },
            .insert_body_span => {
                const anchor = try requireString(edit_obj, "anchor");
                const text = try requireString(edit_obj, "text");
                const raw_pos = try requireString(edit_obj, "position");
                const selector = parseMatchSelector(edit_obj.get("occurrence"));
                const match = try selectMatch(source[body_range.start..body_range.end], anchor, selector, require_single_match);
                const insert_at = if (std.mem.eql(u8, raw_pos, "after"))
                    body_range.start + match.end
                else if (std.mem.eql(u8, raw_pos, "before"))
                    body_range.start + match.start
                else
                    return ApplyError.InvalidPosition;

                const range = RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = insert_at,
                    .editEnd = insert_at,
                };

                try resolved.append(allocator, .{
                    .start = insert_at,
                    .end = insert_at,
                    .replacement = text,
                    .replacement_owned = false,
                    .range = range,
                    .single_match = match.single_match,
                    .changed_before = 0,
                    .changed_after = text.len,
                });
            },
            .wrap_body => {
                const before = try requireString(edit_obj, "before");
                const keep = try requireString(edit_obj, "keep");
                const after = try requireString(edit_obj, "after");
                if (!std.mem.eql(u8, keep, "body")) return ApplyError.FieldTypeMismatch;

                const indent = if (edit_obj.get("indentKeptBodyBy")) |indent_raw| switch (indent_raw) {
                    .integer => |v| if (v < 0) return ApplyError.InvalidOccurrence else @as(usize, @intCast(v)),
                    .float => |v| float_blk: {
                        const rounded = @round(v);
                        if (v < 0 or rounded != v) return ApplyError.InvalidOccurrence;
                        break :float_blk @as(usize, @intFromFloat(rounded));
                    },
                    else => 0,
                } else 0;

                const body = source[body_range.start..body_range.end];
                const kept_body = if (indent == 0) body else try indentBody(allocator, body, indent);
                defer if (indent != 0) allocator.free(kept_body);
                const wrapped = try concat3(allocator, before, kept_body, after);

                const range = RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = body_range.start,
                    .editEnd = body_range.end,
                };

                try resolved.append(allocator, .{
                    .start = body_range.start,
                    .end = body_range.end,
                    .replacement = wrapped,
                    .replacement_owned = true,
                    .range = range,
                    .single_match = true,
                    .changed_before = body.len,
                    .changed_after = wrapped.len,
                });
            },
            .compose_body => {
                // Multi-body compose_body stays unsupported until nested span composition is proven safe.
                return ApplyError.UnsupportedMultiEditOperation;
            },
            .multi_body, .insert_after_symbol => return ApplyError.UnsupportedMultiEditOperation,
        }
    }

    return resolved.toOwnedSlice(allocator);
}

fn applyResolvedEdits(allocator: Allocator, original: []const u8, edits: []MultiEdit) ![]u8 {
    if (edits.len == 0) return ApplyError.PatternEmpty;

    sortMultiEditsDescending(edits);

    if (hasOverlappingEdits(edits)) return ApplyError.OverlappingEdits;

    var current = try allocator.dupe(u8, original);
    errdefer allocator.free(current);

    for (edits) |edit| {
        const next = try spliceText(allocator, current, edit.start, edit.end, edit.replacement);
        allocator.free(current);
        current = next;
    }

    return current;
}

fn sortMultiEditsDescending(edits: []MultiEdit) void {
    var i: usize = 1;
    while (i < edits.len) : (i += 1) {
        var j = i;
        while (j > 0) {
            if (edits[j].start <= edits[j - 1].start) break;
            std.mem.swap(MultiEdit, &edits[j], &edits[j - 1]);
            j -= 1;
        }
    }
}

fn hasOverlappingEdits(edits: []MultiEdit) bool {
    if (edits.len < 2) return false;

    for (edits[0 .. edits.len - 1], edits[1..]) |left, right| {
        if (left.end > right.start and right.end > left.start) return true;
    }

    return false;
}

fn combinedRangeFromEdits(edits: []MultiEdit) RangesResult {
    if (edits.len == 0) return .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 };

    var target_start = edits[0].range.targetStart;
    var target_end = edits[0].range.targetEnd;
    var body_start: ?usize = edits[0].range.bodyStart;
    var body_end: ?usize = edits[0].range.bodyEnd;
    var edit_start = edits[0].range.editStart;
    var edit_end = edits[0].range.editEnd;

    for (edits[1..]) |edit| {
        if (edit.range.targetStart < target_start) target_start = edit.range.targetStart;
        if (edit.range.targetEnd > target_end) target_end = edit.range.targetEnd;
        if (edit.range.bodyStart) |value| {
            if (body_start == null or value < body_start.?) body_start = value;
        }
        if (edit.range.bodyEnd) |value| {
            if (body_end == null or value > body_end.?) body_end = value;
        }
        if (edit.range.editStart < edit_start) edit_start = edit.range.editStart;
        if (edit.range.editEnd > edit_end) edit_end = edit.range.editEnd;
    }

    return RangesResult{
        .targetStart = target_start,
        .targetEnd = target_end,
        .bodyStart = body_start,
        .bodyEnd = body_end,
        .editStart = edit_start,
        .editEnd = edit_end,
    };
}

fn allSingleMatch(edits: []MultiEdit) bool {
    for (edits) |edit| if (!edit.single_match) return false;
    return true;
}

fn totalChangedBefore(edits: []MultiEdit) usize {
    var total: usize = 0;
    for (edits) |edit| total += edit.changed_before;
    return total;
}

fn totalChangedAfter(edits: []MultiEdit) usize {
    var total: usize = 0;
    for (edits) |edit| total += edit.changed_after;
    return total;
}

fn spliceText(allocator: Allocator, source: []const u8, start: usize, end: usize, replacement: []const u8) ![]u8 {
    if (start > end or end > source.len) return ApplyError.InvalidPosition;
    const out_len = source.len - (end - start) + replacement.len;
    const out = try allocator.alloc(u8, out_len);
    @memcpy(out[0..start], source[0..start]);
    @memcpy(out[start .. start + replacement.len], replacement);
    @memcpy(out[start + replacement.len ..], source[end..]);
    return out;
}

fn firstContentIndent(body: []const u8) usize {
    var i: usize = 0;
    while (i < body.len) {
        var count: usize = 0;
        while (i < body.len and body[i] == ' ') : (i += 1) count += 1;
        if (i >= body.len) return 0;
        if (body[i] == '\n') {
            i += 1;
            continue;
        }
        if (body[i] == '\r') {
            i += 1;
            if (i < body.len and body[i] == '\n') i += 1;
            continue;
        }
        return count;
    }
    return 0;
}

fn spaces(allocator: Allocator, count: usize) ![]u8 {
    const out = try allocator.alloc(u8, count);
    @memset(out, ' ');
    return out;
}

fn buildTryCatchWrapped(allocator: Allocator, body: []const u8, catch_body: []const u8, indent: usize) ![]u8 {
    const body_clean = std.mem.trimEnd(u8, body, " \t");
    const trailing_outer = body[body_clean.len..];
    const base_indent = firstContentIndent(body_clean);
    const base = try spaces(allocator, base_indent);
    defer allocator.free(base);
    const catch_indent = base_indent + indent;
    const catch_prefix = try spaces(allocator, catch_indent);
    defer allocator.free(catch_prefix);
    const body_for_try = if (indent == 0) try allocator.dupe(u8, body_clean) else try indentBody(allocator, body_clean, indent);
    defer allocator.free(body_for_try);
    const catch_for_try = if (catch_indent == 0) try allocator.dupe(u8, catch_body) else try indentBody(allocator, catch_body, catch_indent);
    defer allocator.free(catch_for_try);

    const len = 1 + base.len + "try {".len + body_for_try.len + base.len + "} catch (error) {\n".len + catch_for_try.len + 1 + base.len + "}\n".len + trailing_outer.len;
    const out = try allocator.alloc(u8, len);
    var pos: usize = 0;
    const parts = [_][]const u8{ "\n", base, "try {", body_for_try, base, "} catch (error) {\n", catch_for_try, "\n", base, "}\n", trailing_outer };
    for (parts) |part| {
        @memcpy(out[pos .. pos + part.len], part);
        pos += part.len;
    }
    return out;
}

fn indentBody(allocator: Allocator, body: []const u8, indent: usize) ![]u8 {
    var line_count: usize = 1;
    for (body) |ch| {
        if (ch == '\n') line_count += 1;
    }
    const out = try allocator.alloc(u8, body.len + (line_count * indent));

    var si: usize = 0;
    var di: usize = 0;
    var at_line_start = true;
    while (si < body.len) : (si += 1) {
        if (at_line_start) {
            if (body[si] == '\n') {
                out[di] = '\n';
                di += 1;
                at_line_start = true;
                continue;
            }
            if (body[si] == '\r' and si + 1 < body.len and body[si + 1] == '\n') {
                out[di] = '\r';
                out[di + 1] = '\n';
                di += 2;
                si += 1;
                at_line_start = true;
                continue;
            }
            var i: usize = 0;
            while (i < indent) : (i += 1) out[di + i] = ' ';
            di += indent;
            at_line_start = false;
        }

        out[di] = body[si];
        di += 1;
        at_line_start = body[si] == '\n' or (body[si] == '\r' and si + 1 < body.len and body[si + 1] == '\n');
    }

    return try allocator.realloc(out, di);
}

fn concat3(allocator: Allocator, a: []const u8, b: []const u8, c: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len + c.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len .. a.len + b.len], b);
    @memcpy(out[a.len + b.len ..], c);
    return out;
}

const expectObject = apply_ops.expectObject;
const requireString = apply_ops.requireString;
