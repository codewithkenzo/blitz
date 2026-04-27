const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");
const edit_support = @import("edit_support.zig");
const symbols = @import("symbols.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = Io.Dir;

const ApplyOperation = enum {
    replace_body_span,
    insert_body_span,
    wrap_body,
    insert_after_symbol,
};

const TargetRange = enum { body, node };

const MatchKind = enum { default_single, first, last, only, index };

const MatchSelector = struct {
    kind: MatchKind,
    index: usize = 0,
};

const ApplyTarget = struct {
    symbol: []const u8,
    kind: ?[]const u8 = null,
    range: ?[]const u8 = null,
};

const ApplyOptions = struct {
    dryRun: ?bool = null,
    requireParseClean: ?bool = null,
    requireSingleMatch: ?bool = null,
    diffContext: ?usize = null,
};

const ApplyRequest = struct {
    version: u8,
    file: []const u8,
    operation: []const u8,
    target: ApplyTarget,
    edit: std.json.Value,
    options: ?ApplyOptions = null,
};

const ValidationResult = struct {
    parseBeforeClean: bool,
    parseAfterClean: bool,
    singleMatch: bool,
    rejectedReason: ?[]const u8 = null,
};

const RangesResult = struct {
    targetStart: usize,
    targetEnd: usize,
    bodyStart: ?usize = null,
    bodyEnd: ?usize = null,
    editStart: usize,
    editEnd: usize,
};

const MetricsResult = struct {
    fileBytesBefore: usize,
    fileBytesAfter: usize,
    requestBytes: usize,
    changedBytesBefore: usize,
    changedBytesAfter: usize,
    wallMs: u64,
};

const ApplyResult = struct {
    status: []const u8,
    command: []const u8 = "apply",
    operation: []const u8,
    file: []const u8,
    symbol: []const u8,
    language: []const u8,
    dryRun: bool,
    changed: bool,
    validation: ValidationResult,
    ranges: RangesResult,
    metrics: MetricsResult,
    diffSummary: []const u8,
    diff: ?[]const u8 = null,
};

const MatchSpan = struct {
    start: usize,
    end: usize,
    single_match: bool,
    total: usize,
};

const OpResult = struct {
    contents: []u8,
    range: RangesResult,
    single_match: bool,
    changed_before: usize,
    changed_after: usize,
};

const EditSpan = struct { start: usize, end: usize };

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
    NoMatches,
    AmbiguousMatches,
    ParseFailedBefore,
    ParseFailedAfter,
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
    const start = Io.Clock.awake.now(io);

    const parsed = std.json.parseFromSlice(ApplyRequest, allocator, request_bytes, .{}) catch |err| {
        return emitFailure(err, null, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    defer parsed.deinit();

    const req = parsed.value;

    if (req.version != 1) return emitFailure(ApplyError.UnsupportedVersion, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (req.file.len == 0) return emitFailure(ApplyError.MissingFile, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    if (req.target.symbol.len == 0) return emitFailure(ApplyError.MissingSymbol, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);

    const operation = parseOperation(req.operation) catch |err| {
        return emitFailure(err, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };
    const target_range = parseTargetRange(req.target.range) catch |err| {
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

    const original = Dir.cwd().readFileAlloc(io, real_path, allocator, .unlimited) catch |err| {
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

    const target_node = symbols.findEditableSymbolNode(original, root, req.target.symbol) orelse {
        return emitFailure(ApplyError.SymbolNotFound, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
    };

    const target_start: usize = @intCast(target_node.startByte());
    const target_end: usize = @intCast(target_node.endByte());
    const body_range = if (operation == .insert_after_symbol)
        edit_support.ByteRange{ .start = target_start, .end = target_end }
    else
        edit_support.replacementRangeFor(lang, original, target_node);

    const op_result = switch (operation) {
        .replace_body_span => blk: {
            if (target_range != .body) return emitFailure(ApplyError.UnsupportedTargetRange, req, request_bytes, json_output, stdout, stderr, false, false, request_bytes.len);
            const edit_obj = try expectObject(req.edit);
            const find = try requireString(edit_obj, "find");
            const replace = try requireString(edit_obj, "replace");
            const selector = parseMatchSelector(edit_obj.get("occurrence"));
            const match = try selectMatch(original[body_range.start..body_range.end], find, selector, require_single_match);
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
            const match = try selectMatch(original[body_range.start..body_range.end], anchor, selector, require_single_match);
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
    };

    defer allocator.free(op_result.contents);

    var parse_after: bool = undefined;
    if (edit_support.validateEditedSourceIncremental(&parser, &source_tree, original, op_result.contents)) {
        parse_after = true;
    } else |_| {
        parse_after = false;
    }

    if (!parse_after) {
        return emitFailure(ApplyError.ParseFailedAfter, req, request_bytes, json_output, stdout, stderr, true, false, request_bytes.len);
    }

    const changed = !std.mem.eql(u8, original, op_result.contents);
    if (changed and !dry_run) {
        const cache_dir = try backup.defaultCacheDir(allocator);
        defer allocator.free(cache_dir);
        try backup.store(allocator, io, cache_dir, real_path, original);
        try backup.atomicWrite(allocator, io, real_path, op_result.contents);
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
        .symbol = req.target.symbol,
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
        .diff = if (diff_requested and changed and !dry_run) op_result.contents else null,
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
    const reason = switch (err) {
        ApplyError.InvalidJson => "invalid JSON request",
        ApplyError.UnsupportedVersion => "unsupported request version",
        ApplyError.UnsupportedOperation => "unsupported operation",
        ApplyError.UnsupportedLanguage => "unsupported language",
        ApplyError.UnsupportedTargetRange => "unsupported target range",
        ApplyError.MissingSymbol => "missing target symbol",
        ApplyError.MissingFile => "missing file",
        ApplyError.MissingField => "missing required edit field",
        ApplyError.FieldTypeMismatch => "invalid edit field type",
        ApplyError.InvalidOccurrence => "invalid occurrence value",
        ApplyError.InvalidPosition => "invalid position value",
        ApplyError.PatternEmpty => "pattern is empty",
        ApplyError.SymbolNotFound => "symbol not found",
        ApplyError.NoMatches => "no matching pattern",
        ApplyError.AmbiguousMatches => "ambiguous pattern match",
        ApplyError.ParseFailedBefore => "source did not parse before edit",
        ApplyError.ParseFailedAfter => "edited source did not parse",
        else => "apply failed",
    };

    if (!json_output) {
        try stderr.print("blitz apply: {s}\n", .{reason});
        return 1;
    }

    const operation = if (request) |r| r.operation else "";
    const file = if (request) |r| r.file else "";
    const symbol = if (request) |r| r.target.symbol else "";
    const probe = ApplyResult{
        .status = "rejected",
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

fn parseOperation(raw: []const u8) !ApplyOperation {
    if (std.mem.eql(u8, raw, "replace_body_span")) return .replace_body_span;
    if (std.mem.eql(u8, raw, "insert_body_span")) return .insert_body_span;
    if (std.mem.eql(u8, raw, "wrap_body")) return .wrap_body;
    if (std.mem.eql(u8, raw, "insert_after_symbol")) return .insert_after_symbol;
    return ApplyError.UnsupportedOperation;
}

fn parseTargetRange(raw: ?[]const u8) !TargetRange {
    if (raw == null) return .body;
    const value = raw.?;
    if (std.mem.eql(u8, value, "body")) return .body;
    if (std.mem.eql(u8, value, "node")) return .node;
    return ApplyError.UnsupportedTargetRange;
}

fn parseMatchSelector(raw: ?std.json.Value) MatchSelector {
    const candidate = raw orelse return .{ .kind = .default_single };
    return switch (candidate) {
        .string => |value| {
            if (std.mem.eql(u8, value, "first")) return .{ .kind = .first };
            if (std.mem.eql(u8, value, "last")) return .{ .kind = .last };
            if (std.mem.eql(u8, value, "only")) return .{ .kind = .only };
            return .{ .kind = .default_single };
        },
        .integer => |value| if (value > 0) .{ .kind = .index, .index = @intCast(value) } else .{ .kind = .default_single },
        .float => |value| blk: {
            if (value <= 0.0 or @round(value) != value) return .{ .kind = .default_single };
            break :blk .{ .kind = .index, .index = @intFromFloat(value) };
        },
        else => .{ .kind = .default_single },
    };
}

fn selectMatch(haystack: []const u8, needle: []const u8, selector: MatchSelector, require_single_match: bool) !MatchSpan {
    if (needle.len == 0) return ApplyError.PatternEmpty;

    var first: ?EditSpan = null;
    var selected: ?EditSpan = null;
    var total: usize = 0;
    var cursor: usize = 0;

    while (std.mem.indexOfPos(u8, haystack, cursor, needle)) |start| {
        const span = EditSpan{ .start = start, .end = start + needle.len };
        if (first == null) first = span;
        total += 1;
        if (selector.kind == .first and selected == null) selected = span;
        if (selector.kind == .index and selector.index == total) selected = span;
        cursor = start + 1;
    }

    const chosen = switch (selector.kind) {
        .default_single => blk: {
            if (require_single_match and total != 1) return if (total == 0) ApplyError.NoMatches else ApplyError.AmbiguousMatches;
            if (first == null) return ApplyError.NoMatches;
            break :blk first.?;
        },
        .first => first orelse return ApplyError.NoMatches,
        .last => blk: {
            if (total == 0) return ApplyError.NoMatches;
            var last: ?EditSpan = null;
            cursor = 0;
            while (std.mem.indexOfPos(u8, haystack, cursor, needle)) |start| {
                last = EditSpan{ .start = start, .end = start + needle.len };
                cursor = start + 1;
            }
            break :blk last orelse return ApplyError.NoMatches;
        },
        .only => blk: {
            if (total != 1) return ApplyError.AmbiguousMatches;
            break :blk first orelse return ApplyError.NoMatches;
        },
        .index => selected orelse return ApplyError.NoMatches,
    };

    return MatchSpan{
        .start = chosen.start,
        .end = chosen.end,
        .single_match = total == 1,
        .total = total,
    };
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

    return out[0..di];
}

fn concat3(allocator: Allocator, a: []const u8, b: []const u8, c: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len + c.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len .. a.len + b.len], b);
    @memcpy(out[a.len + b.len ..], c);
    return out;
}

fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    switch (value) {
        .object => |obj| return obj,
        else => return ApplyError.FieldTypeMismatch,
    }
}

fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const node = object.get(field) orelse return ApplyError.MissingField;
    switch (node) {
        .string => |value| return value,
        else => return ApplyError.FieldTypeMismatch,
    }
}

fn languageName(lang: bindings.Language) []const u8 {
    return switch (lang) {
        .rust => "rust",
        .typescript => "typescript",
        .tsx => "tsx",
        .python => "python",
        .go => "go",
    };
}
