pub const errors = @import("errors.zig");
pub const validate = @import("validate.zig");

const std = @import("std");
const builtin = @import("builtin");

const apply_errors = @import("errors.zig");
const apply_ir = @import("ir.zig");
const apply_ops = @import("operations.zig");
const apply_diff = @import("diff.zig");
const apply_patch = @import("patch.zig");
const apply_target = @import("target.zig");
const apply_validate = @import("validate.zig");
const ast = @import("../ast.zig");
const backup = @import("../backup.zig");
const bindings = @import("../tree_sitter/bindings.zig");
const edit_support = @import("../edit_support.zig");
const file_lock = @import("../lock.zig");
const grammar_config = @import("../grammar_config.zig");
const workspace = @import("../workspace.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = Io.Dir;
const MAX_SOURCE_BYTES = 32 * 1024 * 1024;

const ApplyOperation = apply_ops.ApplyOperation;
const TargetRange = apply_target.TargetRange;
const requireArray = apply_ir.requireArray;
const requireOptionalString = apply_ir.requireOptionalString;
const requireOptionalBool = apply_ir.requireOptionalBool;
const requireTupleString = apply_ops.requireTupleString;
const tupleOptionalValue = apply_ops.tupleOptionalValue;
const tupleOptionalIndent = apply_ops.tupleOptionalIndent;
const MatchKind = apply_ops.MatchKind;
const MatchSelector = apply_ops.MatchSelector;
const ApplyOptions = apply_ir.ApplyOptions;
const ApplyRequest = apply_ir.ApplyRequest;
const ValidationResult = apply_ir.ValidationResult;
const RangesResult = apply_ir.RangesResult;
const MetricsResult = apply_ir.MetricsResult;
const ApplyResult = apply_ir.ApplyResult;
const ApplyFailureResult = apply_ir.ApplyFailureResult;

fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |obj| obj,
        else => return ApplyError.FieldTypeMismatch,
    };
}

fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const node = object.get(field) orelse return ApplyError.MissingField;
    return switch (node) {
        .string => |value| value,
        else => return ApplyError.FieldTypeMismatch,
    };
}

const MatchSpan = apply_ops.MatchSpan;
const OpResult = apply_ops.OpResult;
const MultiEdit = apply_ops.MultiEdit;
const ComposeResult = apply_ops.ComposeResult;
const KeepSliceResult = apply_ops.KeepSliceResult;
const EditSpan = apply_ops.EditSpan;
const ApplyError = error{
    InvalidJson,
    UnsupportedVersion,
    UnsupportedOperation,
    UnsupportedLanguage,
    UnsupportedTargetRange,
    MissingSymbol,
    MissingFile,
    MissingField,
    FieldTypeMismatch,
    InvalidOccurrence,
    InvalidPosition,
    PatternEmpty,
    SymbolNotFound,
    SymbolAmbiguous,
    BodyNotFound,
    NoMatches,
    AmbiguousMatches,
    OverlappingEdits,
    UnsupportedMultiEditOperation,
    ParseFailedBefore,
    ParseFailedAfter,
    ValidationFailed,
    BackupFailed,
    IoError,
    NeedsHostMerge,
};

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
    if (builtin.is_test) {
        defer workspace.setRoot(null);
    }

    const start = Io.Clock.awake.now(io);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, request_bytes, .{}) catch |err| {
        return emitFailure(if (err == error.OutOfMemory) ApplyError.IoError else ApplyError.InvalidJson, null, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer parsed.deinit();

    const req = apply_ir.parseRequest(parsed.value) catch |err| {
        return emitFailure(err, null, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    if (req.file.len == 0) return emitFailure(ApplyError.MissingFile, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const operation = apply_ops.parseOperation(req.operation) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    if (operation != .multi_body and operation != .patch) {
        const target = req.target orelse return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        if (target.symbol.len == 0) return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }

    const target_range = if (operation == .multi_body or operation == .patch) TargetRange.body else apply_target.parseTargetRange(req.target.?.range) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    const require_single_match = if (req.options) |opts| opts.requireSingleMatch orelse true else true;
    const dry_run = if (cli_dry_run) true else if (req.options) |opts| opts.dryRun orelse false else false;

    const ext = std.fs.path.extension(req.file);
    const lang = grammar_config.languageForExtension(ext) orelse {
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

    const target_node: ?bindings.Node = if (operation == .multi_body or operation == .patch)
        null
    else
        apply_target.resolveEditableSymbol(original, root, req.target.?.symbol) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const target_start: usize = if (target_node) |node| @intCast(node.startByte()) else 0;
    const target_end: usize = if (target_node) |node| @intCast(node.endByte()) else 0;
    const body_range = if (operation == .multi_body or operation == .insert_after_symbol)
        edit_support.ByteRange{ .start = target_start, .end = target_end }
    else if (operation == .patch)
        edit_support.ByteRange{ .start = 0, .end = 0 }
    else
        apply_target.bodyRangeFor(lang, original, target_node.?) orelse return emitFailure(ApplyError.BodyNotFound, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const op_result_result: anyerror!OpResult = switch (operation) {
        .replace_body_span => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try apply_ir.expectObject(req.edit);
            const find = apply_ir.requireString(edit_obj, "find") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const replace = apply_ir.requireString(edit_obj, "replace") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const selector = apply_target.parseMatchSelector(edit_obj.get("occurrence"));
            const match = apply_target.selectMatch(original[body_range.start..body_range.end], find, selector, require_single_match) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const edit_start = body_range.start + match.start;
            const edit_end = body_range.start + match.end;
            break :blk OpResult{
                .contents = try apply_diff.spliceText(allocator, original, edit_start, edit_end, replace),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = edit_start, .editEnd = edit_end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replace.len,
            };
        },
        .insert_body_span => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const anchor = apply_ir.requireString(edit_obj, "anchor") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const text = apply_ir.requireString(edit_obj, "text") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const raw_pos = apply_ir.requireString(edit_obj, "position") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const selector = apply_target.parseMatchSelector(edit_obj.get("occurrence"));
            const match = apply_target.selectMatch(original[body_range.start..body_range.end], anchor, selector, require_single_match) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const insert_at = if (std.mem.eql(u8, raw_pos, "after"))
                body_range.start + match.end
            else if (std.mem.eql(u8, raw_pos, "before"))
                body_range.start + match.start
            else
                return emitFailure(ApplyError.InvalidPosition, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            break :blk OpResult{
                .contents = try apply_diff.spliceText(allocator, original, insert_at, insert_at, text),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = insert_at, .editEnd = insert_at },
                .single_match = match.single_match,
                .changed_before = 0,
                .changed_after = text.len,
            };
        },
        .wrap_body => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const before = apply_ir.requireString(edit_obj, "before") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const keep = apply_ir.requireString(edit_obj, "keep") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            const after = apply_ir.requireString(edit_obj, "after") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
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
            const kept_body = if (indent == 0) try allocator.dupe(u8, body) else try apply_patch.indentBody(allocator, body, indent);
            defer allocator.free(kept_body);
            const wrapped = try apply_patch.concat3(allocator, before, kept_body, after);
            defer allocator.free(wrapped);
            break :blk OpResult{
                .contents = try apply_diff.spliceText(allocator, original, body_range.start, body_range.end, wrapped),
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

            const new_contents = try apply_diff.spliceText(allocator, original, body_range.start, body_range.end, compose.contents);
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
            const code = apply_ir.requireString(edit_obj, "code") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            break :blk OpResult{
                .contents = try apply_diff.spliceText(allocator, original, target_end, target_end, code),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = target_start, .bodyEnd = target_end, .editStart = target_end, .editEnd = target_end },
                .single_match = true,
                .changed_before = 0,
                .changed_after = code.len,
            };
        },
        .set_body => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const body = apply_ir.requireString(edit_obj, "body") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
            break :blk OpResult{
                .contents = try apply_diff.spliceText(allocator, original, body_range.start, body_range.end, body),
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body_range.end - body_range.start,
                .changed_after = body.len,
            };
        },
        .patch => apply_patch.makeCompactPatchOp(
            allocator,
            lang,
            root,
            original,
            req.edit,
            require_single_match,
        ),
        .multi_body => apply_patch.makeMultiBodyOp(
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

    const parse_after = try apply_validate.parseAfterEdit(
        &parser,
        &source_tree,
        original,
        op_result.contents,
        operation == .multi_body or operation == .patch,
    );

    if (!parse_after) {
        return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    }

    const changed = !std.mem.eql(u8, original, op_result.contents);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, op_result.contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
    }

    const end = Io.Clock.awake.now(io);
    const wall_ms = start.durationTo(end).toMilliseconds();
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -{d}", .{ op_result.changed_after, op_result.changed_before })
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .file = real_path,
        .symbol = if (req.target) |target| target.symbol else "",
        .language = languageName(lang),
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = true, .parseAfterClean = parse_after, .singleMatch = op_result.single_match },
        .ranges = op_result.range,
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = op_result.contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = op_result.changed_before,
            .changedBytesAfter = op_result.changed_after,
            .wallMs = @intCast(wall_ms),
        },
        .diffSummary = diffSummary,
        .diff = if (diff_requested and changed) diffSummary else null,
    };

    if (!json_output) {
        if (changed and !dry_run) try stdout.print("Applied {s}: {s}\n", .{ req.file, status }) else try stdout.print("No changes for {s}: {s}\n", .{ req.file, status });
        return 0;
    }

    try stdout.print("{f}\n", .{std.json.fmt(result, .{})});
    return 0;
}

fn emitFailure(
    err: anyerror,
    request: ?ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    parse_before: bool,
    parse_after: bool,
    request_bytes_len: usize,
) !u8 {
    const reason = apply_errors.reason(err);
    const code = apply_errors.code(err);
    const status = apply_errors.status(err);

    if (!json_output) {
        try stderr.print("blitz apply: {s}\n", .{reason});
        return 1;
    }

    const operation = if (request) |r| r.operation else "";
    const file = if (request) |r| r.file else "";
    const symbol = if (request) |r| if (r.target) |target| target.symbol else "" else "";
    const probe = ApplyFailureResult{
        .status = status,
        .code = code,
        .operation = operation,
        .file = file,
        .symbol = symbol,
        .language = "",
        .dryRun = false,
        .changed = false,
        .validation = .{ .parseBeforeClean = parse_before, .parseAfterClean = parse_after, .singleMatch = false, .rejectedReason = reason },
        .ranges = .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 },
        .metrics = .{ .fileBytesBefore = request_bytes_len, .fileBytesAfter = 0, .requestBytes = request_bytes.len, .changedBytesBefore = 0, .changedBytesAfter = 0, .wallMs = 0 },
        .diffSummary = reason,
    };
    try stdout.print("{f}\n", .{std.json.fmt(probe, .{})});
    return 1;
}

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
                break :blk apply_target.KeepSliceResult{ .span = .{ .start = 0, .end = body.len }, .single_match = true };
            },
            .object => |keep_obj| try apply_target.parseKeepSpan(body, keep_obj, require_single_match),
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

fn languageName(lang: bindings.Language) []const u8 {
    return grammar_config.languageName(lang);
}

fn runApplyTest(allocator: Allocator, io: Io, request_template: []const u8, file_path: []const u8) ![]u8 {
    const request = try std.mem.replaceOwned(u8, allocator, request_template, "{FILE}", file_path);
    defer allocator.free(request);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run(allocator, io, request, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 0), status);
    return allocator.dupe(u8, stdout_buf.written());
}

fn runApplyTestExpectFailure(allocator: Allocator, io: Io, request_template: []const u8, file_path: []const u8) ![]u8 {
    const request = try std.mem.replaceOwned(u8, allocator, request_template, "{FILE}", file_path);
    defer allocator.free(request);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run(allocator, io, request, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    return allocator.dupe(u8, stdout_buf.written());
}

test "apply replace_body_span occurrence last" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function hugeCompute(seed: number): number {
        \\  let total = seed;
        \\  return total;
        \\  return total;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"hugeCompute"},"edit":{"find":"return total;","replace":"return total + 1;","occurrence":"last"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, post, "return total + 1;"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, post, "return total;"));
}

test "apply replace_body_span ambiguous rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function repeated(): number {
        \\  return 1;
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"repeated"},"edit":{"find":"return 1;","replace":"return 2;"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "ambiguous pattern match") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply compose_body with text + keep body prefix/suffix" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function composeKeepSpan(value: number): number {
        \\  const doubled = value * 2;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"compose_body","target":{"symbol":"composeKeepSpan"},"edit":{"segments":[{"text":"\n  const marker = \"compose\";\n"},{"keep":"body"},{"text":"\n  const suffix = marker;\n"}]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "function composeKeepSpan(value: number): number {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const marker = \"compose\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const suffix = marker;") != null);
    const marker_pos = std.mem.indexOf(u8, post, "const marker = \"compose\";");
    const doubled_pos = std.mem.indexOf(u8, post, "const doubled = value * 2;");
    try std.testing.expect(marker_pos != null and doubled_pos != null and marker_pos.? < doubled_pos.?);
}

test "apply compose_body beforeKeep/afterKeep keeps island" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function composeIsland(value: number): string {
        \\  const method = value.toString();
        \\  if (method !== "GET" && method !== "POST") {
        \\    return "bad";
        \\  }
        \\  return method;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"compose_body","target":{"symbol":"composeIsland"},"edit":{"segments":[{"text":"\n  const prefix = true;\n"},{"keep":{"beforeKeep":"if (method !== \"GET\" && method !== \"POST\") {","afterKeep":"  }","includeBefore":true,"includeAfter":true,"occurrence":"only"}},{"text":"\n  const suffix = true;\n"}]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const prefix = true;") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "if (method !== \"GET\" && method !== \"POST\") {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return \"bad\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const suffix = true;") != null);
}

test "apply compose_body ambiguous keep rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function ambiguousKeep(value: number): number {
        \\  const marker = value;
        \\  const marker = value;
        \\  return marker;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"compose_body","target":{"symbol":"ambiguousKeep"},"edit":{"segments":[{"keep":{"beforeKeep":"const marker = value;"}}]}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "ambiguous pattern match") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply compose_body parse failure rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function parseFail(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"compose_body","target":{"symbol":"parseFail"},"edit":{"segments":"bad"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"rejected\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply set_body replaces complete body" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function settable(value: number): number {
        \\  const doubled = value * 2;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"settable"},"edit":{"body":"\n  return value + 1;\n"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"operation\":\"set_body\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"language\":\"typescript\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "function settable(value: number): number {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value + 1;") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "doubled") == null);
}

test "apply set_body invalid body type rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function x() { return 1; }
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"x"},"edit":{"body":123}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"rejected\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"code\":\"INVALID_FIELD\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply invalid target symbol type rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function settable(value: number): number {
        \\  return value * 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":123},"edit":{"body":"return value;"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"rejected\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"code\":\"INVALID_FIELD\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply insert_body_span after anchor" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function greet(): string {
        \\  const name = "kenzo";
        \\  return name;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"insert_body_span","target":{"symbol":"greet"},"edit":{"anchor":"const name = \"kenzo\";","position":"after","text":"\n  const upper = name.toUpperCase();","occurrence":"only"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, post, "const upper = name.toUpperCase();") != null);
}

test "apply wrap_body preserves signature" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function wrapy(value: number): number {
        \\  const doubled = value * 2;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"wrap_body","target":{"symbol":"wrapy"},"edit":{"before":"\n  try {","keep":"body","after":"  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n","indentKeptBodyBy":2}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, post, "function wrapy(value: number): number {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "  try {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "    const doubled = value * 2;") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "  } catch (error) {") != null);
}
test "apply patch with 3 ops succeeds" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function alpha(value: number): number {
        \\  return value;
        \\}
        \\function beta(value: string): string {
        \\  const trimmed = value.trim();
        \\  return trimmed;
        \\}
        \\function gamma(value: number): number {
        \\  const doubled = value * 2;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace","alpha","return value;","return value + 1;"],["insert_after","beta","const trimmed = value.trim();","\n  const upper = trimmed.toUpperCase();"],["wrap","gamma","\n  if (value > 0) {","\n  }\n",2]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value + 1;") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const upper = trimmed.toUpperCase();") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "if (value > 0) {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "  const doubled = value * 2;") != null);
}

test "apply patch replace_return rewrites return expr" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function scale(value: number): number {
        \\  return value * 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","scale","value * 3"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value * 3;") != null);
}

test "apply patch try_catch wraps body" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function guarded(value: number): number {
        \\  const doubled = value * 2;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["try_catch","guarded","  console.error(error);\n  throw error;"] ]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "try {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "catch (error)") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "console.error(error);") != null);
}

test "apply patch ambiguous replace_return rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function ambiguous(value: number): number {
        \\  if (value > 0) {
        \\    return value;
        \\  }
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","ambiguous","value + 1"]]}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "ambiguous pattern match") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply multi_body three edits on same file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function adjust(value: number): number {
        \\  const base = value;
        \\  return base;
        \\}
        \\function emit(value: string): string {
        \\  const marker = value;
        \\  return marker;
        \\}
        \\function risky(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"multi_body","edit":{"edits":[{"symbol":"adjust","op":"replace_body_span","find":"return base;","replace":"return base + 1;","occurrence":"only"},{"symbol":"emit","op":"insert_body_span","anchor":"const marker = value;","position":"after","text":"\n  const markerUpper = value.toUpperCase();\n","occurrence":"only"},{"symbol":"risky","op":"wrap_body","before":"\n  try {","keep":"body","after":"  } catch (error) {\n    throw error;\n  }\n","indentKeptBodyBy":2}]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return base + 1;") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "const markerUpper = value.toUpperCase();") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "try {") != null);
}

test "apply multi_body overlaps reject with no mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function overlap(value: number): number {
        \\  const doubled = value;
        \\  return doubled;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"multi_body","edit":{"edits":[{"symbol":"overlap","op":"replace_body_span","find":"return doubled;","replace":"return doubled + 1;","occurrence":"only"},{"symbol":"overlap","op":"insert_body_span","anchor":"eturn doubled","position":"after","text":"\n  // overlap marker\n","occurrence":"only"}]}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "overlapping edits") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply multi_body ambiguous anchor rejects without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function ambiguous(value: number): number {
        \\  return value;
        \\  return value;
        \\}
        \\function anchor(value: string): string {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"multi_body","edit":{"edits":[{"symbol":"ambiguous","op":"replace_body_span","find":"return value;","replace":"return value + 1;"},{"symbol":"anchor","op":"insert_body_span","anchor":"return value;","position":"before","text":"\n  const upper = value.toUpperCase();\n","occurrence":"only"}]}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "ambiguous pattern match") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply async replace_return in TSX succeeds" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\export async function choose(value: number): Promise<number> {
        \\  return value * 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.tsx", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.tsx", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","choose","value * 3"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.tsx", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value * 3;") != null);
}

test "apply arrow replace_return rewrites return expression" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\const formatCount = (value: number): string => {
        \\  return value.toString();
        \\};
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","formatCount","value.toFixed(0)"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value.toFixed(0);") != null);
}

test "apply class method wrap_body applies to method body" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\class Counter {
        \\  bump(value: number): number {
        \\    return value + 1;
        \\  }
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"wrap_body","target":{"symbol":"bump"},"edit":{"before":"\n    if (value < 0) {\n      return 0;\n    }\n","keep":"body","after":"","indentKeptBodyBy":0}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "class Counter {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "if (value < 0)") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return value + 1;") != null);
}

test "apply TSX component replace_return rewrites JSX" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\export function Card() {
        \\  return <div>old</div>;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "card.tsx", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "card.tsx", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","Card","<section>new</section>"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "card.tsx", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return <section>new</section>;") != null);
}

test "apply error taxonomy maps specified future and fallback codes" {
    try std.testing.expectEqualStrings("HASH_MISMATCH", apply_errors.code(error.HashMismatch));
    try std.testing.expectEqualStrings("VALIDATION_FAILED", apply_errors.code(error.ValidationFailed));
    try std.testing.expectEqualStrings("NEEDS_HOST_MERGE", apply_errors.code(error.NeedsHostMerge));
    try std.testing.expectEqualStrings("OUTSIDE_WORKSPACE", apply_errors.code(error.PathEscapesWorkspace));
}

test "apply duplicate symbol returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const original =
        \\function dup() {
        \\  return 1;
        \\}
        \\function dup() {
        \\  return 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "dup.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "dup.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"dup\"}},\"edit\":{{\"body\":\"return 3;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"SYMBOL_AMBIGUOUS\"") != null);
}

test "apply class method wrap_body succeeds" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\class Greeter {
        \\  greet(value: number): number {
        \\    return value * 2;
        \\  }
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["try_catch","greet","  console.error(error);\n  throw error;"] ]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "try {") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "catch (error)") != null);
}

test "apply TSX component return replacement succeeds" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\export function Component(): any {
        \\  return <div>hello</div>;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.tsx", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.tsx", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","Component","<span>world</span>"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const post = try tmp.dir.readFileAlloc(io, "a.tsx", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, post, "return <span>world</span>;") != null);
}

test "apply invalid json returns stable code" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run(allocator, io, "{", false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"INVALID_JSON\"") != null);
}

test "apply unsupported version returns stable code" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const request =
        \\{"version":2,"file":"x.ts","operation":"set_body","target":{"symbol":"x"},"edit":{"body":"x"}}
    ;
    const status = try run(allocator, io, request, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"UNSUPPORTED_SCHEMA_VERSION\"") != null);
}

test "apply missing field returns stable code" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run(allocator, io, "{\"version\":1,\"file\":\"x.ts\"}", false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"MISSING_FIELD\"") != null);
}

test "apply unsupported operation returns stable code" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = "{\"version\":1,\"file\":\"x.ts\",\"operation\":\"nope\",\"target\":{\"symbol\":\"x\"},\"edit\":{\"body\":\"x\"}}";
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"UNSUPPORTED_OPERATION\"") != null);
}

test "apply symbol not found returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.ts", .data = "function x() { return 1; }" });
    const path = try tmp.dir.realPathFileAlloc(io, "x.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"missing\"}},\"edit\":{{\"body\":\"x\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"SYMBOL_NOT_FOUND\"") != null);
}

test "apply ambiguous match returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const original =
        \\function x() {
        \\  return 1;
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "x.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"replace_body_span\",\"target\":{{\"symbol\":\"x\"}},\"edit\":{{\"find\":\"return 1;\",\"replace\":\"return 2;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"AMBIGUOUS_MATCH\"") != null);
}

test "apply unsupported language returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.zig", .data = "const x = 1;" });
    const path = try tmp.dir.realPathFileAlloc(io, "x.zig", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"x\"}},\"edit\":{{\"body\":\"const y = 1;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"UNSUPPORTED_LANGUAGE\"") != null);
}

test "apply unsupported language snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.zig", .data = "const x = 1;" });
    const path = try tmp.dir.realPathFileAlloc(io, "x.zig", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"x\"}},\"edit\":{{\"body\":\"const y = 1;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    const parsed = try parseApplyJson(allocator, stdout_buf.written());
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "rejected");
    try expectJsonFieldString(obj, "code", "UNSUPPORTED_LANGUAGE");
}

test "apply file not found returns stable code" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = "{\"version\":1,\"file\":\"/definitely/not/present.ts\",\"operation\":\"set_body\",\"target\":{\"symbol\":\"x\"},\"edit\":{\"body\":\"x\"}}";
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"FILE_NOT_FOUND\"") != null);
}

test "apply body not found returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.ts", .data = "const x = 1;" });
    const path = try tmp.dir.realPathFileAlloc(io, "x.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"x\"}},\"edit\":{{\"body\":\"return 2;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"BODY_NOT_FOUND\"") != null);
}

test "apply no match returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const original =
        \\function onlyOne() {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "x.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "x.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"replace_body_span\",\"target\":{{\"symbol\":\"onlyOne\"}},\"edit\":{{\"find\":\"missing\",\"replace\":\"present\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"NO_MATCH\"") != null);
}

test "apply parse failure before edit returns stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "broken.ts", .data = "function broken( {" });
    const path = try tmp.dir.realPathFileAlloc(io, "broken.ts", allocator);
    defer allocator.free(path);
    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const req = try std.fmt.allocPrint(allocator, "{{\"version\":1,\"file\":\"{s}\",\"operation\":\"set_body\",\"target\":{{\"symbol\":\"broken\"}},\"edit\":{{\"body\":\"const y = 1;\"}}}}", .{path});
    defer allocator.free(req);
    const status = try run(allocator, io, req, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "\"code\":\"PARSE_ERROR_BEFORE\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "broken.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings("function broken( {", post);
}

test "apply write-path errors map to stable backup and io codes" {
    try std.testing.expectEqualStrings("BACKUP_FAILED", apply_errors.code(error.CacheDirUnavailable));
    try std.testing.expectEqualStrings("BACKUP_FAILED", apply_errors.code(error.AtomicWriteFailed));
    try std.testing.expectEqualStrings("BACKUP_FAILED", apply_errors.code(error.NoBackup));
    try std.testing.expectEqualStrings("IO_ERROR", apply_errors.code(error.LockContended));
    try std.testing.expectEqualStrings("IO_ERROR", apply_errors.code(error.LockInvalidPath));
    try std.testing.expectEqualStrings("IO_ERROR", apply_errors.code(error.OutOfMemory));
}

fn parseApplyJson(allocator: Allocator, bytes: []const u8) !std.json.Parsed(std.json.Value) {
    return try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
}

fn expectJsonFieldString(obj: std.json.ObjectMap, field: []const u8, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, obj.get(field).?.string);
}

test "apply json success snapshot exposes stable fields" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function snap(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"snap"},"edit":{"body":"\n  return value + 1;\n"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try std.testing.expectEqualStrings("apply", obj.get("command").?.string);
    try std.testing.expectEqualStrings("applied", obj.get("status").?.string);
    try std.testing.expectEqualStrings("set_body", obj.get("operation").?.string);
    try std.testing.expectEqualStrings(path, obj.get("file").?.string);
    try std.testing.expect(obj.get("diffSummary") != null);
    try std.testing.expect(obj.get("code") == null);
}

test "apply json rejection snapshot exposes stable code" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function reject(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"reject"},"edit":{"body":123}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try std.testing.expectEqualStrings("apply", obj.get("command").?.string);
    try std.testing.expectEqualStrings("rejected", obj.get("status").?.string);
    try std.testing.expectEqualStrings("INVALID_FIELD", obj.get("code").?.string);
}

test "apply json patch success snapshot exposes stable code-free response" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function patchy(value: number): number {
        \\  return value * 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","patchy","value * 3"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "command", "apply");
    try expectJsonFieldString(obj, "status", "applied");
    try std.testing.expect(obj.get("code") == null);
    try expectJsonFieldString(obj, "operation", "patch");
}

test "apply json replace_body_span snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function one(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"one"},"edit":{"find":"return 1;","replace":"return 2;"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "replace_body_span");
    try std.testing.expect(obj.get("ranges") != null);
}

test "apply json insert_body_span snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function insertMe(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"insert_body_span","target":{"symbol":"insertMe"},"edit":{"anchor":"return 1;","position":"before","text":"  const x = 0;\n","occurrence":"only"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "insert_body_span");
    try std.testing.expect(obj.get("ranges") != null);
}

test "apply json set_body snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function setMe(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"setMe"},"edit":{"body":"\n  return 2;\n"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "set_body");
    try std.testing.expect(obj.get("ranges") != null);
}

test "apply json wrap_body snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function wrapme(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"wrap_body","target":{"symbol":"wrapme"},"edit":{"before":"try {\n","keep":"body","after":"\n} finally {\n  cleanup();\n}","indentKeptBodyBy":2}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "wrap_body");
    try std.testing.expect(obj.get("diffSummary") != null);
}

test "apply json multi_body snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function a(): number {
        \\  return 1;
        \\}
        \\function b(): number {
        \\  return 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"multi_body","edit":{"edits":[{"symbol":"a","op":"replace_body_span","find":"return 1;","replace":"return 10;"},{"symbol":"b","op":"replace_body_span","find":"return 2;","replace":"return 20;"}]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "multi_body");
    try std.testing.expect(obj.get("ranges") != null);
}

test "apply json async function snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\export async function asyncOne(value: number): Promise<number> {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","asyncOne","value + 1"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "patch");
}

test "apply json arrow function snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\const arrowOne = (value: number): number => {
        \\  return value;
        \\};
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","arrowOne","value * 2"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "patch");
}

test "apply json class method snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\class C {
        \\  method(value: number): number {
        \\    return value;
        \\  }
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","method","value + 2"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "patch");
}

test "apply json duplicate symbol rejection snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function dup() {
        \\  return 1;
        \\}
        \\function dup() {
        \\  return 2;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"dup"},"edit":{"body":"return 3;"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "rejected");
    try expectJsonFieldString(obj, "code", "SYMBOL_AMBIGUOUS");
}

test "apply json nested return snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function outer(value: number): number {
        \\  function inner(): number {
        \\    return value;
        \\  }
        \\  return inner();
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"patch","edit":{"ops":[["replace_return","inner","value + 1"]]}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "applied");
    try expectJsonFieldString(obj, "operation", "patch");
}

test "apply json parse-after rejection snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function parseAfter(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"parseAfter"},"edit":{"body":"return )"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "rejected");
    try expectJsonFieldString(obj, "code", "PARSE_ERROR_AFTER");
}

test "apply json parse-before rejection snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function parseBefore( {
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_body","target":{"symbol":"parseBefore"},"edit":{"body":"return 1;"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "rejected");
    try expectJsonFieldString(obj, "code", "PARSE_ERROR_BEFORE");
}

test "apply json no match rejection snapshot is structured" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function noMatch(value: number): number {
        \\  return value;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"noMatch"},"edit":{"find":"missing","replace":"present"}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "rejected");
    try expectJsonFieldString(obj, "code", "NO_MATCH");
}
