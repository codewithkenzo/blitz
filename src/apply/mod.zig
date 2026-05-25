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
const PhaseMetricsResult = apply_ir.PhaseMetricsResult;
const RouteDecision = apply_ir.RouteDecision;

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
    cli_route_override: ?[]const u8,
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

    if (operation != .replace_unique and operation != .insert_after_anchor and operation != .insert_before_anchor and operation != .replace_between and operation != .append_section and operation != .ensure_line and operation != .delete_range and operation != .set_key and operation != .multi_body and operation != .patch) {
        const target = req.target orelse return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        if (target.symbol.len == 0) return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }

    const target_range = if (operation == .replace_unique or operation == .insert_after_anchor or operation == .insert_before_anchor or operation == .replace_between or operation == .append_section or operation == .ensure_line or operation == .delete_range or operation == .set_key or operation == .multi_body or operation == .patch) TargetRange.body else apply_target.parseTargetRange(req.target.?.range) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    const require_single_match = if (req.options) |opts| opts.requireSingleMatch orelse true else true;
    const dry_run = if (cli_dry_run) true else if (req.options) |opts| opts.dryRun orelse false else false;
    const json_route = if (req.options) |opts| opts.route else null;
    const route_option = cli_route_override orelse (json_route orelse "auto");
    const route_requested = cli_route_override != null or json_route != null;

    const real_path = Dir.cwd().realPathFileAlloc(io, req.file, allocator) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer allocator.free(real_path);
    workspace.enforce(real_path) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    const read_start = Io.Clock.awake.now(io);
    const original = Dir.cwd().readFileAlloc(io, real_path, allocator, .limited(MAX_SOURCE_BYTES)) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    const read_ms = msSince(read_start, Io.Clock.awake.now(io));
    defer allocator.free(original);

    if (isDirectTextOperation(operation) and shouldExplain(route_option, dry_run, route_requested)) {
        const decision = estimateRouteDecision(operation, route_option);
        return emitExplainResult(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original.len, read_ms, "text", decision, if (std.mem.eql(u8, decision.route, "core_edit")) "needs_host_merge" else "preview");
    }

    if (operation == .replace_unique) {
        return runReplaceUnique(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    if (operation == .insert_after_anchor or operation == .insert_before_anchor) {
        return runInsertAnchor(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested, operation);
    }
    if (operation == .replace_between) {
        return runReplaceBetween(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    if (operation == .append_section) {
        return runAppendSection(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    if (operation == .ensure_line) {
        return runEnsureLine(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    if (operation == .delete_range) {
        return runDeleteRange(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    if (operation == .set_key) {
        if (shouldExplain(route_option, dry_run, route_requested)) {
            const ext = std.fs.path.extension(req.file);
            if (!std.mem.eql(u8, ext, ".json")) return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const decision = if (std.mem.eql(u8, route_option, "force-core")) estimateRouteDecision(operation, route_option) else formatTextRouteDecision("format_text_json_set_key");
            return emitExplainResult(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original.len, read_ms, "json", decision, if (std.mem.eql(u8, decision.route, "core_edit")) "needs_host_merge" else "preview");
        }
        return runSetKey(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original, read_ms, dry_run, diff_requested);
    }
    const route_decision = estimateRouteDecision(operation, route_option);
    const use_route_fallback = shouldExplain(route_option, dry_run, route_requested) or (route_requested and std.mem.eql(u8, route_decision.route, "core_edit"));

    const ext = std.fs.path.extension(req.file);
    const lang = grammar_config.languageForExtension(ext) orelse {
        if (use_route_fallback and (std.mem.eql(u8, route_decision.route, "core_edit") or std.mem.eql(u8, route_decision.fallbackRoute, "core_edit"))) {
            return emitExplainResult(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original.len, read_ms, "unsupported", route_decision, "needs_host_merge");
        }
        return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    if (use_route_fallback) {
        return emitExplainResult(allocator, io, start, req, request_bytes, json_output, stdout, stderr, real_path, original.len, read_ms, languageName(lang), route_decision, if (std.mem.eql(u8, route_decision.route, "core_edit")) "needs_host_merge" else "preview");
    }

    const parser_init_start = Io.Clock.awake.now(io);
    var parser = bindings.Parser.init();
    defer parser.deinit();
    if (!parser.setLanguage(lang)) return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const parser_init_ms = msSince(parser_init_start, Io.Clock.awake.now(io));

    const parse_before_start = Io.Clock.awake.now(io);
    var source_tree = parser.parseString(original) orelse return emitFailure(ApplyError.ParseFailedBefore, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer source_tree.deinit();

    const root = source_tree.rootNode();
    if (root.isNull() or root.hasError()) return emitFailure(ApplyError.ParseFailedBefore, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const parse_before_ms = msSince(parse_before_start, Io.Clock.awake.now(io));

    const target_resolve_start = Io.Clock.awake.now(io);
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
    const target_resolve_ms = msSince(target_resolve_start, Io.Clock.awake.now(io));

    const plan_start = Io.Clock.awake.now(io);
    const op_result_result: anyerror!OpResult = switch (operation) {
        .replace_unique, .insert_after_anchor, .insert_before_anchor, .replace_between, .append_section, .ensure_line, .delete_range => unreachable,
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
        .set_key => unreachable,
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
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    defer allocator.free(op_result.contents);

    const parse_after_start = Io.Clock.awake.now(io);
    const replacement_end = op_result.range.editStart + op_result.changed_after;
    const parse_after_single_range: ?apply_validate.SingleRangeEdit = if (operation == .multi_body or operation == .patch or replacement_end > op_result.contents.len)
        null
    else
        .{
            .start = op_result.range.editStart,
            .end = op_result.range.editEnd,
            .replacement = op_result.contents[op_result.range.editStart..replacement_end],
        };
    const parse_after = try apply_validate.parseAfterEdit(
        allocator,
        &parser,
        &source_tree,
        original,
        op_result.contents,
        operation == .multi_body or operation == .patch,
        parse_after_single_range,
    );

    if (!parse_after) {
        return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    }
    const parse_after_ms = msSince(parse_after_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, op_result.contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, op_result.contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, parse_after, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

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
        .route = "ast_narrow",
        .routeReasonCode = normalRouteReason(route_option),
        .routeDecision = appliedAstRouteDecision(route_option),
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
            .phaseMs = .{
                .read = read_ms,
                .parserInit = parser_init_ms,
                .parseBefore = parse_before_ms,
                .targetResolve = target_resolve_ms,
                .plan = plan_ms,
                .parseAfter = parse_after_ms,
                .write = write_ms,
                .total = @intCast(wall_ms),
            },
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

fn runReplaceUnique(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const find = apply_ir.requireString(edit_obj, "find") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const replace = apply_ir.requireString(edit_obj, "replace") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const match = apply_ops.selectMatch(original, find, .{ .kind = .only }, true) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const contents = apply_diff.spliceText(allocator, original, match.start, match.end, replace) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -{d}", .{ replace.len, find.len })
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const decision = directTextRouteDecision("direct_text_unique_match");
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = "direct_text_unique_match",
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = match.start, .targetEnd = match.end, .bodyStart = null, .bodyEnd = null, .editStart = match.start, .editEnd = match.end },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = find.len,
            .changedBytesAfter = replace.len,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

fn runInsertAnchor(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
    operation: ApplyOperation,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const anchor = apply_ir.requireString(edit_obj, "anchor") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const text = apply_ir.requireString(edit_obj, "text") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const match = apply_ops.selectMatch(original, anchor, .{ .kind = .only }, true) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const insert_at = switch (operation) {
        .insert_after_anchor => match.end,
        .insert_before_anchor => match.start,
        else => unreachable,
    };
    const contents = apply_diff.spliceText(allocator, original, insert_at, insert_at, text) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -0", .{text.len})
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = switch (operation) {
        .insert_after_anchor => "direct_text_insert_after_anchor",
        .insert_before_anchor => "direct_text_insert_before_anchor",
        else => unreachable,
    };
    const decision = directTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = match.start, .targetEnd = match.end, .bodyStart = null, .bodyEnd = null, .editStart = insert_at, .editEnd = insert_at },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = 0,
            .changedBytesAfter = text.len,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

fn runReplaceBetween(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const start_anchor = apply_ir.requireString(edit_obj, "start") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const end_anchor = apply_ir.requireString(edit_obj, "end") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const replace = apply_ir.requireString(edit_obj, "replace") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const start_match = apply_ops.selectMatch(original, start_anchor, .{ .kind = .only }, true) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const end_match = apply_ops.selectMatch(original, end_anchor, .{ .kind = .only }, true) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (end_match.start < start_match.end) return emitFailure(ApplyError.NoMatches, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const edit_start = start_match.end;
    const edit_end = end_match.start;
    const end_anchor_end = end_match.end;
    const contents = apply_diff.spliceText(allocator, original, edit_start, edit_end, replace) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -{d}", .{ replace.len, edit_end - edit_start })
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = "direct_text_replace_between";
    const decision = directTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = start_match.start, .targetEnd = end_anchor_end, .bodyStart = null, .bodyEnd = null, .editStart = edit_start, .editEnd = edit_end },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = edit_end - edit_start,
            .changedBytesAfter = replace.len,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

const SectionHeadingMatch = struct {
    start: usize,
    next_line_start: usize,
    level: usize,
};

fn markdownHeadingLevel(line: []const u8) ?usize {
    var level: usize = 0;
    while (level < line.len and line[level] == '#') : (level += 1) {}
    if (level == 0 or level >= line.len or line[level] != ' ') return null;
    return level;
}

fn lineWithoutTrailingCr(line: []const u8) []const u8 {
    if (line.len > 0 and line[line.len - 1] == '\r') return line[0 .. line.len - 1];
    return line;
}

fn findUniqueMarkdownHeading(source: []const u8, heading: []const u8) !SectionHeadingMatch {
    const heading_level = markdownHeadingLevel(heading) orelse return ApplyError.InvalidPosition;
    var found: ?SectionHeadingMatch = null;
    var line_start: usize = 0;
    while (line_start <= source.len) {
        const rest = source[line_start..];
        const rel_end = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
        const line = lineWithoutTrailingCr(rest[0..rel_end]);
        if (std.mem.eql(u8, line, heading)) {
            if (found != null) return ApplyError.AmbiguousMatches;
            found = .{ .start = line_start, .next_line_start = if (line_start + rel_end < source.len) line_start + rel_end + 1 else source.len, .level = heading_level };
        }
        if (line_start + rel_end >= source.len) break;
        line_start += rel_end + 1;
    }
    return found orelse ApplyError.NoMatches;
}

fn findMarkdownSectionEnd(source: []const u8, start: usize, level: usize) usize {
    var line_start = start;
    while (line_start < source.len) {
        const rest = source[line_start..];
        const rel_end = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
        const line = lineWithoutTrailingCr(rest[0..rel_end]);
        if (markdownHeadingLevel(line)) |candidate_level| {
            if (candidate_level <= level) return line_start;
        }
        if (line_start + rel_end >= source.len) break;
        line_start += rel_end + 1;
    }
    return source.len;
}

fn countTrailingNewlines(source: []const u8, end: usize) usize {
    var count: usize = 0;
    var cursor = end;
    while (cursor > 0 and source[cursor - 1] == '\n') {
        count += 1;
        cursor -= 1;
    }
    return count;
}

fn buildAppendSectionContents(allocator: Allocator, original: []const u8, insert_at: usize, text: []const u8) ![]u8 {
    const block = std.mem.trim(u8, text, "\r\n");
    if (block.len == 0) return ApplyError.PatternEmpty;

    const trailing_newlines = countTrailingNewlines(original, insert_at);
    const sep_before: []const u8 = if (trailing_newlines >= 2) "" else if (trailing_newlines == 1) "\n" else "\n\n";
    const sep_after: []const u8 = if (insert_at < original.len) "\n" else "";
    const contents = try std.fmt.allocPrint(allocator, "{s}{s}{s}\n{s}{s}", .{ original[0..insert_at], sep_before, block, sep_after, original[insert_at..] });
    errdefer allocator.free(contents);
    if (contents.len == 0 or contents[contents.len - 1] == '\n') return contents;
    const with_final_newline = try std.fmt.allocPrint(allocator, "{s}\n", .{contents});
    allocator.free(contents);
    return with_final_newline;
}

fn runAppendSection(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const heading = apply_ir.requireString(edit_obj, "heading") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const text = apply_ir.requireString(edit_obj, "text") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (text.len == 0) return emitFailure(ApplyError.PatternEmpty, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const heading_match = findUniqueMarkdownHeading(original, heading) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const insert_at = findMarkdownSectionEnd(original, heading_match.next_line_start, heading_match.level);
    const contents = buildAppendSectionContents(allocator, original, insert_at, text) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const changed_after = contents.len - original.len;
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -0", .{changed_after})
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = "direct_text_append_section";
    const decision = directTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = heading_match.start, .targetEnd = insert_at, .bodyStart = heading_match.next_line_start, .bodyEnd = insert_at, .editStart = insert_at, .editEnd = insert_at },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = 0,
            .changedBytesAfter = changed_after,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

fn hasFullLine(source: []const u8, line: []const u8) bool {
    var start: usize = 0;
    while (start <= source.len) {
        const rest = source[start..];
        const rel_end = std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len;
        var current = rest[0..rel_end];
        if (current.len > 0 and current[current.len - 1] == '\r') current = current[0 .. current.len - 1];
        if (std.mem.eql(u8, current, line)) return true;
        if (start + rel_end >= source.len) break;
        start += rel_end + 1;
    }
    return false;
}

fn buildEnsureLineContents(allocator: Allocator, original: []const u8, line: []const u8) ![]u8 {
    if (original.len == 0) return std.fmt.allocPrint(allocator, "{s}\n", .{line});
    const separator: []const u8 = if (original[original.len - 1] == '\n') "" else "\n";
    return std.fmt.allocPrint(allocator, "{s}{s}{s}\n", .{ original, separator, line });
}

fn runEnsureLine(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const line = apply_ir.requireString(edit_obj, "line") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (line.len == 0) return emitFailure(ApplyError.PatternEmpty, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (std.mem.indexOfAny(u8, line, "\r\n") != null) return emitFailure(ApplyError.InvalidPosition, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const position = apply_ir.requireOptionalString(edit_obj, "position") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (position) |value| {
        if (!std.mem.eql(u8, value, "append")) return emitFailure(ApplyError.InvalidPosition, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }

    const exists = hasFullLine(original, line);
    const contents = if (exists)
        try allocator.dupe(u8, original)
    else
        buildEnsureLineContents(allocator, original, line) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const changed_after = contents.len - original.len;
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -0", .{changed_after})
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = "direct_text_ensure_line";
    const decision = directTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = original.len, .targetEnd = original.len, .bodyStart = null, .bodyEnd = null, .editStart = original.len, .editEnd = original.len },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = 0,
            .changedBytesAfter = changed_after,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

fn runDeleteRange(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const edit_start = apply_ir.requireUsize(edit_obj, "start") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const edit_end = apply_ir.requireUsize(edit_obj, "end") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const expected = apply_ir.requireString(edit_obj, "expected") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (edit_start > edit_end or edit_end > original.len) return emitFailure(ApplyError.InvalidPosition, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (!std.mem.eql(u8, original[edit_start..edit_end], expected)) return emitFailure(ApplyError.NoMatches, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const contents = apply_diff.spliceText(allocator, original, edit_start, edit_end, "") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(contents);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+0 -{d}", .{edit_end - edit_start})
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = "direct_text_delete_range";
    const decision = directTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "direct_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "text",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = true },
        .ranges = .{ .targetStart = edit_start, .targetEnd = edit_end, .bodyStart = null, .bodyEnd = null, .editStart = edit_start, .editEnd = edit_end },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = edit_end - edit_start,
            .changedBytesAfter = 0,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

const JsonBuildResult = struct {
    contents: []u8,
    edit_start: usize,
    edit_end: usize,
};

const JsonKeyMatch = struct {
    value_start: usize = 0,
    value_end: usize = 0,
    close_brace: usize,
    first_key_start: ?usize = null,
    found: bool = false,
    empty: bool = false,
};

fn skipJsonWs(source: []const u8, index: usize) usize {
    var i = index;
    while (i < source.len and (source[i] == ' ' or source[i] == '\n' or source[i] == '\r' or source[i] == '\t')) : (i += 1) {}
    return i;
}

fn skipJsonString(source: []const u8, start: usize) !usize {
    if (start >= source.len or source[start] != '"') return ApplyError.InvalidJson;
    var i = start + 1;
    while (i < source.len) : (i += 1) {
        if (source[i] == '"') return i + 1;
        if (source[i] == '\\') {
            i += 1;
            if (i >= source.len) return ApplyError.InvalidJson;
        }
    }
    return ApplyError.InvalidJson;
}

fn skipJsonValue(source: []const u8, start: usize) !usize {
    var i = skipJsonWs(source, start);
    if (i >= source.len) return ApplyError.InvalidJson;
    if (source[i] == '"') return skipJsonString(source, i);
    if (source[i] == '{') {
        i += 1;
        i = skipJsonWs(source, i);
        if (i < source.len and source[i] == '}') return i + 1;
        while (i < source.len) {
            const key_end = try skipJsonString(source, i);
            i = skipJsonWs(source, key_end);
            if (i >= source.len or source[i] != ':') return ApplyError.InvalidJson;
            i = try skipJsonValue(source, i + 1);
            i = skipJsonWs(source, i);
            if (i < source.len and source[i] == '}') return i + 1;
            if (i >= source.len or source[i] != ',') return ApplyError.InvalidJson;
            i = skipJsonWs(source, i + 1);
        }
        return ApplyError.InvalidJson;
    }
    if (source[i] == '[') {
        i += 1;
        i = skipJsonWs(source, i);
        if (i < source.len and source[i] == ']') return i + 1;
        while (i < source.len) {
            i = try skipJsonValue(source, i);
            i = skipJsonWs(source, i);
            if (i < source.len and source[i] == ']') return i + 1;
            if (i >= source.len or source[i] != ',') return ApplyError.InvalidJson;
            i = skipJsonWs(source, i + 1);
        }
        return ApplyError.InvalidJson;
    }
    while (i < source.len and !std.ascii.isWhitespace(source[i]) and source[i] != ',' and source[i] != '}' and source[i] != ']') : (i += 1) {}
    return i;
}

fn decodedJsonString(allocator: Allocator, source: []const u8) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return ApplyError.InvalidJson;
    defer parsed.deinit();
    return switch (parsed.value) {
        .string => |value| allocator.dupe(u8, value),
        else => ApplyError.InvalidJson,
    };
}

fn findJsonTopLevelKey(allocator: Allocator, source: []const u8, wanted: []const u8) !JsonKeyMatch {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return ApplyError.ParseFailedBefore;
    defer parsed.deinit();
    if (parsed.value != .object) return ApplyError.ParseFailedBefore;

    var owned_keys = std.ArrayList([]u8).empty;
    defer {
        for (owned_keys.items) |key| allocator.free(key);
        owned_keys.deinit(allocator);
    }

    var i = skipJsonWs(source, 0);
    if (i >= source.len or source[i] != '{') return ApplyError.ParseFailedBefore;
    i = skipJsonWs(source, i + 1);
    if (i < source.len and source[i] == '}') {
        const end = skipJsonWs(source, i + 1);
        if (end != source.len) return ApplyError.ParseFailedBefore;
        return .{ .close_brace = i, .empty = true };
    }

    var result = JsonKeyMatch{ .close_brace = 0 };
    while (i < source.len) {
        const key_start = i;
        const key_end = try skipJsonString(source, key_start);
        if (result.first_key_start == null) result.first_key_start = key_start;
        const key = try decodedJsonString(allocator, source[key_start..key_end]);
        errdefer allocator.free(key);
        for (owned_keys.items) |seen| {
            if (std.mem.eql(u8, seen, key)) return ApplyError.AmbiguousMatches;
        }
        try owned_keys.append(allocator, key);

        i = skipJsonWs(source, key_end);
        if (i >= source.len or source[i] != ':') return ApplyError.ParseFailedBefore;
        const value_start = skipJsonWs(source, i + 1);
        const value_end = try skipJsonValue(source, value_start);
        if (std.mem.eql(u8, key, wanted)) {
            result.found = true;
            result.value_start = value_start;
            result.value_end = value_end;
        }
        i = skipJsonWs(source, value_end);
        if (i < source.len and source[i] == '}') {
            result.close_brace = i;
            const end = skipJsonWs(source, i + 1);
            if (end != source.len) return ApplyError.ParseFailedBefore;
            return result;
        }
        if (i >= source.len or source[i] != ',') return ApplyError.ParseFailedBefore;
        i = skipJsonWs(source, i + 1);
    }
    return ApplyError.ParseFailedBefore;
}

fn validateSetKeyName(key: []const u8) !void {
    if (key.len == 0 or std.mem.indexOfAny(u8, key, ".[]/") != null) return ApplyError.InvalidPosition;
}

fn canonicalJsonValue(allocator: Allocator, value: std.json.Value) ![]u8 {
    return std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(value, .{})});
}

fn buildInsertedJsonKey(allocator: Allocator, original: []const u8, match: JsonKeyMatch, key: []const u8, encoded_value: []const u8) !JsonBuildResult {
    const encoded_key = try canonicalJsonValue(allocator, .{ .string = key });
    defer allocator.free(encoded_key);

    if (match.empty) {
        const replacement = try std.fmt.allocPrint(allocator, "\n  {s}: {s}\n", .{ encoded_key, encoded_value });
        defer allocator.free(replacement);
        return .{ .contents = try apply_diff.spliceText(allocator, original, match.close_brace, match.close_brace, replacement), .edit_start = match.close_brace, .edit_end = match.close_brace };
    }

    if (match.close_brace == 0 or match.close_brace > original.len) return ApplyError.InvalidPosition;
    const close_line_start = if (std.mem.lastIndexOfScalar(u8, original[0..match.close_brace], '\n')) |pos| pos + 1 else return ApplyError.InvalidPosition;
    const close_indent = original[close_line_start..match.close_brace];
    for (close_indent) |c| if (c != ' ' and c != '\t') return ApplyError.InvalidPosition;
    const first_key_start = match.first_key_start orelse return ApplyError.InvalidPosition;
    const first_key_line_start = if (std.mem.lastIndexOfScalar(u8, original[0..first_key_start], '\n')) |pos| pos + 1 else return ApplyError.InvalidPosition;
    const entry_indent = original[first_key_line_start..first_key_start];
    for (entry_indent) |c| if (c != ' ' and c != '\t') return ApplyError.InvalidPosition;
    const insert_at = if (match.close_brace > 0 and original[match.close_brace - 1] == '\n') match.close_brace - 1 else return ApplyError.InvalidPosition;
    const replacement = try std.fmt.allocPrint(allocator, ",\n{s}{s}: {s}", .{ entry_indent, encoded_key, encoded_value });
    defer allocator.free(replacement);
    return .{ .contents = try apply_diff.spliceText(allocator, original, insert_at, insert_at, replacement), .edit_start = insert_at, .edit_end = insert_at };
}

fn jsonObjectValid(allocator: Allocator, source: []const u8) bool {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, source, .{}) catch return false;
    defer parsed.deinit();
    return parsed.value == .object;
}

fn runSetKey(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    original: []const u8,
    read_ms: u64,
    dry_run: bool,
    diff_requested: bool,
) !u8 {
    const ext = std.fs.path.extension(req.file);
    if (!std.mem.eql(u8, ext, ".json")) return emitFailure(ApplyError.UnsupportedLanguage, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const plan_start = Io.Clock.awake.now(io);
    const edit_obj = apply_ir.expectObject(req.edit) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const key = apply_ir.requireString(edit_obj, "key") catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    validateSetKeyName(key) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const value = edit_obj.get("value") orelse return emitFailure(ApplyError.MissingField, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const encoded_value = canonicalJsonValue(allocator, value) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    defer allocator.free(encoded_value);
    const match = findJsonTopLevelKey(allocator, original, key) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    const built: JsonBuildResult = if (match.found)
        .{ .contents = apply_diff.spliceText(allocator, original, match.value_start, match.value_end, encoded_value) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len), .edit_start = match.value_start, .edit_end = match.value_end }
    else
        buildInsertedJsonKey(allocator, original, match, key, encoded_value) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    defer allocator.free(built.contents);
    if (!jsonObjectValid(allocator, built.contents)) return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    const plan_ms = msSince(plan_start, Io.Clock.awake.now(io));

    const changed = !std.mem.eql(u8, original, built.contents);
    const write_start = Io.Clock.awake.now(io);
    if (changed and !dry_run) {
        var lock_guard = file_lock.acquire(allocator, io, real_path) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, true, request_bytes.len);
        defer lock_guard.release();
        const cache_dir = backup.defaultCacheDir(allocator) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, true, request_bytes.len);
        defer allocator.free(cache_dir);
        backup.store(allocator, io, cache_dir, real_path, original) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, true, request_bytes.len);
        backup.atomicWrite(allocator, io, real_path, built.contents) catch |err| return emitFailure(err, req, request_bytes, json_output, stdout, stderr, true, true, request_bytes.len);
    }
    const write_ms = msSince(write_start, Io.Clock.awake.now(io));

    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const status = if (dry_run) "preview" else if (changed) "applied" else "no_changes";
    const changed_before = built.edit_end - built.edit_start;
    const changed_after = built.contents.len - (original.len - changed_before);
    const diffSummary = if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -{d}", .{ changed_after, changed_before })
    else
        try allocator.dupe(u8, "no changes");
    defer allocator.free(diffSummary);

    const reason_code = "format_text_json_set_key";
    const decision = formatTextRouteDecision(reason_code);
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = "format_text",
        .routeReasonCode = reason_code,
        .routeDecision = decision,
        .file = real_path,
        .symbol = "",
        .language = "json",
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = true, .parseAfterClean = true, .singleMatch = match.found },
        .ranges = .{ .targetStart = 0, .targetEnd = original.len, .bodyStart = null, .bodyEnd = null, .editStart = built.edit_start, .editEnd = built.edit_end },
        .metrics = .{
            .fileBytesBefore = original.len,
            .fileBytesAfter = built.contents.len,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = changed_before,
            .changedBytesAfter = changed_after,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = plan_ms, .parseAfter = 0, .write = write_ms, .total = wall_ms },
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

fn formatTextRouteDecision(reason_code: []const u8) RouteDecision {
    return .{
        .route = "format_text",
        .fallbackRoute = "core_edit",
        .confidence = 0.95,
        .reasonCode = reason_code,
        .risk = .{ .correctnessRisk = 0.02, .unsupportedFormatRisk = 0.02, .retryRisk = 0.02 },
    };
}

fn directTextRouteDecision(reason_code: []const u8) RouteDecision {
    return .{
        .route = "direct_text",
        .fallbackRoute = "core_edit",
        .confidence = 1.0,
        .reasonCode = reason_code,
        .risk = .{ .correctnessRisk = 0.01, .unsupportedFormatRisk = 0, .retryRisk = 0.01 },
    };
}

fn isDirectTextOperation(operation: ApplyOperation) bool {
    return switch (operation) {
        .replace_unique, .insert_after_anchor, .insert_before_anchor, .replace_between, .append_section, .ensure_line, .delete_range => true,
        else => false,
    };
}

fn shouldExplain(route_option: []const u8, dry_run: bool, route_requested: bool) bool {
    if (!route_requested) return false;
    if (std.mem.eql(u8, route_option, "explain")) return true;
    if (std.mem.eql(u8, route_option, "force-core")) return true;
    if (dry_run and std.mem.eql(u8, route_option, "auto")) return true;
    return false;
}

fn estimateRouteDecision(operation: ApplyOperation, route_option: []const u8) RouteDecision {
    if (std.mem.eql(u8, route_option, "force-core")) {
        return .{
            .route = "core_edit",
            .fallbackRoute = "ast_narrow",
            .confidence = 1.0,
            .reasonCode = "forced_core",
            .risk = .{ .correctnessRisk = 0.05, .unsupportedFormatRisk = 0, .retryRisk = 0.05 },
        };
    }
    if (std.mem.eql(u8, route_option, "force-blitz")) {
        return .{
            .route = "ast_narrow",
            .fallbackRoute = "core_edit",
            .confidence = 1.0,
            .reasonCode = "forced_apply_ast",
            .risk = .{ .correctnessRisk = 0.10, .unsupportedFormatRisk = 0, .retryRisk = 0.10 },
        };
    }

    switch (operation) {
        .replace_unique => return directTextRouteDecision("direct_text_unique_match"),
        .insert_after_anchor => return directTextRouteDecision("direct_text_insert_after_anchor"),
        .insert_before_anchor => return directTextRouteDecision("direct_text_insert_before_anchor"),
        .replace_between => return directTextRouteDecision("direct_text_replace_between"),
        .append_section => return directTextRouteDecision("direct_text_append_section"),
        .ensure_line => return directTextRouteDecision("direct_text_ensure_line"),
        .delete_range => return directTextRouteDecision("direct_text_delete_range"),
        .set_key => return formatTextRouteDecision("format_text_json_set_key"),
        .replace_body_span => return .{
            .route = "core_edit",
            .fallbackRoute = "ast_narrow",
            .confidence = 0.85,
            .reasonCode = "core_favored_span_replace",
            .risk = .{ .correctnessRisk = 0.05, .unsupportedFormatRisk = 0, .retryRisk = 0.05 },
        },
        .multi_body => return .{
            .route = "core_edit",
            .fallbackRoute = "ast_batch",
            .confidence = 0.80,
            .reasonCode = "core_favored_multi_body",
            .risk = .{ .correctnessRisk = 0.06, .unsupportedFormatRisk = 0, .retryRisk = 0.06 },
        },
        .wrap_body, .insert_body_span, .compose_body => return .{
            .route = "ast_narrow",
            .fallbackRoute = "core_edit",
            .confidence = 0.80,
            .reasonCode = "structural_core_failed_or_risky",
            .risk = .{ .correctnessRisk = 0.08, .unsupportedFormatRisk = 0, .retryRisk = 0.08 },
        },
        .patch => return .{
            .route = "ast_batch",
            .fallbackRoute = "core_edit",
            .confidence = 0.80,
            .reasonCode = "structural_core_failed_or_risky",
            .risk = .{ .correctnessRisk = 0.08, .unsupportedFormatRisk = 0, .retryRisk = 0.08 },
        },
        .insert_after_symbol, .set_body => {},
    }

    return .{
        .route = "ast_narrow",
        .fallbackRoute = "core_edit",
        .confidence = 0.75,
        .reasonCode = "supported_ast_operation",
        .risk = .{ .correctnessRisk = 0.10, .unsupportedFormatRisk = 0, .retryRisk = 0.10 },
    };
}

fn appliedAstRouteDecision(route_option: []const u8) RouteDecision {
    if (std.mem.eql(u8, route_option, "force-blitz")) {
        return .{
            .route = "ast_narrow",
            .fallbackRoute = "core_edit",
            .confidence = 1.0,
            .reasonCode = "forced_apply_ast",
            .risk = .{ .correctnessRisk = 0.10, .unsupportedFormatRisk = 0, .retryRisk = 0.10 },
        };
    }

    return .{
        .route = "ast_narrow",
        .fallbackRoute = "core_edit",
        .confidence = 0.75,
        .reasonCode = "supported_ast_operation",
        .risk = .{ .correctnessRisk = 0.10, .unsupportedFormatRisk = 0, .retryRisk = 0.10 },
    };
}

fn rejectedRouteDecision(reason_code: []const u8) RouteDecision {
    const unsupported_format_risk: f32 = if (std.mem.eql(u8, reason_code, "UNSUPPORTED_LANGUAGE")) 1.0 else 0.25;
    return .{
        .route = "rejected",
        .fallbackRoute = "core_edit",
        .confidence = 0.0,
        .reasonCode = reason_code,
        .risk = .{ .correctnessRisk = 1.0, .unsupportedFormatRisk = unsupported_format_risk, .retryRisk = 0.50 },
    };
}

fn normalRouteReason(route_option: []const u8) []const u8 {
    if (std.mem.eql(u8, route_option, "force-blitz")) return "forced_apply_ast";
    return "supported_ast_operation";
}

fn emitExplainResult(
    allocator: Allocator,
    io: Io,
    start: anytype,
    req: ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    real_path: []const u8,
    file_bytes: usize,
    read_ms: u64,
    language: []const u8,
    decision: RouteDecision,
    status: []const u8,
) !u8 {
    _ = stderr;
    const end = Io.Clock.awake.now(io);
    const wall_ms: u64 = @intCast(start.durationTo(end).toMilliseconds());
    const result = ApplyResult{
        .status = status,
        .operation = req.operation,
        .route = decision.route,
        .routeReasonCode = decision.reasonCode,
        .routeDecision = decision,
        .file = real_path,
        .symbol = if (req.target) |target| target.symbol else "",
        .language = language,
        .dryRun = true,
        .changed = false,
        .validation = .{ .parseBeforeClean = false, .parseAfterClean = false, .singleMatch = false },
        .ranges = .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 },
        .metrics = .{
            .fileBytesBefore = file_bytes,
            .fileBytesAfter = file_bytes,
            .requestBytes = request_bytes.len,
            .changedBytesBefore = 0,
            .changedBytesAfter = 0,
            .wallMs = wall_ms,
            .phaseMs = .{ .read = read_ms, .parserInit = 0, .parseBefore = 0, .targetResolve = 0, .plan = 0, .parseAfter = 0, .write = 0, .total = wall_ms },
        },
        .diffSummary = "route explain: no mutation",
    };
    if (!json_output) {
        try stdout.print("Route {s}: {s}\n", .{ real_path, decision.route });
        return 0;
    }
    _ = allocator;
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
        .route = "rejected",
        .routeReasonCode = code,
        .routeDecision = rejectedRouteDecision(code),
        .file = file,
        .symbol = symbol,
        .language = "",
        .dryRun = false,
        .changed = false,
        .validation = .{ .parseBeforeClean = parse_before, .parseAfterClean = parse_after, .singleMatch = false, .rejectedReason = reason },
        .ranges = .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 },
        .metrics = .{ .fileBytesBefore = request_bytes_len, .fileBytesAfter = 0, .requestBytes = request_bytes.len, .changedBytesBefore = 0, .changedBytesAfter = 0, .wallMs = 0, .phaseMs = zeroPhaseMs() },
        .diffSummary = reason,
    };
    try stdout.print("{f}\n", .{std.json.fmt(probe, .{})});
    return 1;
}

fn msSince(start: anytype, end: anytype) u64 {
    return @intCast(start.durationTo(end).toMilliseconds());
}

fn zeroPhaseMs() PhaseMetricsResult {
    return .{
        .read = 0,
        .parserInit = 0,
        .parseBefore = 0,
        .targetResolve = 0,
        .plan = 0,
        .parseAfter = 0,
        .write = 0,
        .total = 0,
    };
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
    const status = try run(allocator, io, request, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, request, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    return allocator.dupe(u8, stdout_buf.written());
}

test "apply set_key updates existing JSON value by local span" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\{
        \\  "name": "old",
        \\  "keep": true
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.json", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.json", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_key","edit":{"key":"name","value":"new"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"route\":\"format_text\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"routeReasonCode\":\"format_text_json_set_key\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"parseBeforeClean\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"parseAfterClean\":true") != null);
    const post = try tmp.dir.readFileAlloc(io, "a.json", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(
        \\{
        \\  "name": "new",
        \\  "keep": true
        \\}
    , post);
}

test "apply set_key inserts missing JSON key in empty object" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    try tmp.dir.writeFile(io, .{ .sub_path = "empty.json", .data = "{}" });
    const path = try tmp.dir.realPathFileAlloc(io, "empty.json", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_key","edit":{"key":"added","value":{"ok":true}}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"status\":\"applied\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "empty.json", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(
        \\{
        \\  "added": {"ok":true}
        \\}
    , post);
}

test "apply set_key rejects duplicate JSON keys without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original = "{\"a\":1,\"a\":2}";
    try tmp.dir.writeFile(io, .{ .sub_path = "dup.json", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "dup.json", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"set_key","edit":{"key":"a","value":3}}
    ;
    const out = try runApplyTestExpectFailure(allocator, io, req, path);
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"code\":\"PARSE_ERROR_BEFORE\"") != null or std.mem.indexOf(u8, out, "\"code\":\"AMBIGUOUS_MATCH\"") != null);
    const post = try tmp.dir.readFileAlloc(io, "dup.json", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "apply set_key rejects non-json extension and nested key syntax" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original = "{\"a\":1}";
    try tmp.dir.writeFile(io, .{ .sub_path = "a.txt", .data = original });
    try tmp.dir.writeFile(io, .{ .sub_path = "a.json", .data = original });
    const txt_path = try tmp.dir.realPathFileAlloc(io, "a.txt", allocator);
    defer allocator.free(txt_path);
    const json_path = try tmp.dir.realPathFileAlloc(io, "a.json", allocator);
    defer allocator.free(json_path);
    const ext_req =
        \\{"version":1,"file":"{FILE}","operation":"set_key","edit":{"key":"a","value":2}}
    ;
    const ext_out = try runApplyTestExpectFailure(allocator, io, ext_req, txt_path);
    defer allocator.free(ext_out);
    try std.testing.expect(std.mem.indexOf(u8, ext_out, "\"code\":\"UNSUPPORTED_LANGUAGE\"") != null);
    const nested_req =
        \\{"version":1,"file":"{FILE}","operation":"set_key","edit":{"key":"a.b","value":2}}
    ;
    const nested_out = try runApplyTestExpectFailure(allocator, io, nested_req, json_path);
    defer allocator.free(nested_out);
    try std.testing.expect(std.mem.indexOf(u8, nested_out, "\"code\":\"INVALID_FIELD\"") != null);
    const txt_post = try tmp.dir.readFileAlloc(io, "a.txt", allocator, .unlimited);
    defer allocator.free(txt_post);
    const json_post = try tmp.dir.readFileAlloc(io, "a.json", allocator, .unlimited);
    defer allocator.free(json_post);
    try std.testing.expectEqualStrings(original, txt_post);
    try std.testing.expectEqualStrings(original, json_post);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, "{", false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, request, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, "{\"version\":1,\"file\":\"x.ts\"}", false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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
    const status = try run(allocator, io, req, false, false, true, null, &stdout_buf.writer, &stderr_buf.writer);
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

fn expectRouteDecisionString(obj: std.json.ObjectMap, field: []const u8, expected: []const u8) !void {
    const decision = try apply_ir.expectObject(obj.get("routeDecision").?);
    try std.testing.expectEqualStrings(expected, decision.get(field).?.string);
}

test "route explain replace_body_span favors core without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function spanRoute(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"spanRoute"},"edit":{"find":"return 1;","replace":"return 2;"},"options":{"route":"explain"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "needs_host_merge");
    try expectJsonFieldString(obj, "route", "core_edit");
    try expectJsonFieldString(obj, "routeReasonCode", "core_favored_span_replace");
    try expectRouteDecisionString(obj, "reasonCode", "core_favored_span_replace");
    try std.testing.expectEqual(false, obj.get("changed").?.bool);
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "force-blitz replace_body_span keeps ast route" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function forcedBlitz(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"replace_body_span","target":{"symbol":"forcedBlitz"},"edit":{"find":"return 1;","replace":"return 2;"},"options":{"route":"force-blitz","dryRun":true}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "preview");
    try expectJsonFieldString(obj, "route", "ast_narrow");
    try expectJsonFieldString(obj, "routeReasonCode", "forced_apply_ast");
    try expectRouteDecisionString(obj, "route", "ast_narrow");
    const post = try tmp.dir.readFileAlloc(io, "a.ts", allocator, .unlimited);
    defer allocator.free(post);
    try std.testing.expectEqualStrings(original, post);
}

test "route explain wrap_body keeps ast route for structural edit" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    const original =
        \\function wrapRoute(): number {
        \\  return 1;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "a.ts", .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, "a.ts", allocator);
    defer allocator.free(path);
    const req =
        \\{"version":1,"file":"{FILE}","operation":"wrap_body","target":{"symbol":"wrapRoute"},"edit":{"before":"try {\n","keep":"body","after":"\n} catch (error) {\n  throw error;\n}","indentKeptBodyBy":2},"options":{"route":"explain"}}
    ;
    const out = try runApplyTest(allocator, io, req, path);
    defer allocator.free(out);
    const parsed = try parseApplyJson(allocator, out);
    defer parsed.deinit();
    const obj = try apply_ir.expectObject(parsed.value);
    try expectJsonFieldString(obj, "status", "preview");
    try expectJsonFieldString(obj, "route", "ast_narrow");
    try expectJsonFieldString(obj, "routeReasonCode", "structural_core_failed_or_risky");
    try expectRouteDecisionString(obj, "reasonCode", "structural_core_failed_or_risky");
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
