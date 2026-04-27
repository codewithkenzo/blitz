const std = @import("std");

const bindings = @import("tree_sitter/bindings.zig");
const incremental = @import("incremental.zig");
const splice = @import("splice.zig");
const symbols = @import("symbols.zig");

pub const EditMode = enum {
    replace,
    after,
};

pub const ApplyResult = struct {
    contents: []u8,
    target_start: usize,
    target_end: usize,
    target_bytes_before: usize,
    target_bytes_after: usize,
    snippet_bytes: usize,
    used_markers: bool,
};

const typescript_comment_styles = [_][]const u8{ "//", "/*" };
const python_comment_styles = [_][]const u8{"#"};

pub fn applyToSource(
    allocator: std.mem.Allocator,
    lang: bindings.Language,
    source: []const u8,
    symbol: []const u8,
    snippet: []const u8,
    mode: EditMode,
) !ApplyResult {
    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return error.UnsupportedLanguage;
    var tree = try parseStrict(&parser, source);
    defer tree.deinit();

    const target = symbols.findEditableSymbolNode(source, tree.rootNode(), symbol) orelse return error.SymbolNotFound;

    const target_start: usize = @intCast(target.startByte());
    const target_end: usize = @intCast(target.endByte());
    const body_range = replacementRangeFor(lang, source, target);

    var replacement: []const u8 = snippet;
    var used_markers = false;
    var owned_replacement: ?[]u8 = null;
    var owned_normalized_snippet: ?[]u8 = null;
    defer if (owned_replacement) |owned| allocator.free(owned);
    defer if (owned_normalized_snippet) |owned| allocator.free(owned);

    switch (mode) {
        .replace => {
            const original_body = source[body_range.start..body_range.end];
            const normalized = try normalizeReplaceSnippet(allocator, lang, original_body, snippet);
            replacement = normalized;
            owned_normalized_snippet = normalized;

            const maybe_merged = splice.maybeSplice(
                allocator,
                original_body,
                replacement,
                commentStylesFor(lang),
            ) catch |err| switch (err) {
                error.AnchorNotFound => return error.AnchorNotFound,
                error.MarkerGrammarInvalid => return error.MarkerGrammarInvalid,
                error.AmbiguousAnchor => return error.AmbiguousAnchor,
                else => return err,
            };

            if (maybe_merged) |merged| {
                replacement = merged.merged;
                used_markers = merged.used_markers;
                owned_replacement = merged.merged;
            }
        },
        .after => {
            const normalized = try normalizeAfterSnippet(allocator, snippet);
            replacement = normalized;
            owned_replacement = normalized;
        },
    }

    const replace_start = if (mode == .after) target_end else body_range.start;
    const replace_end = if (mode == .after) target_end else body_range.end;
    const new_len = source.len - (replace_end - replace_start) + replacement.len;
    const next_contents = try allocator.alloc(u8, new_len);
    errdefer allocator.free(next_contents);

    @memcpy(next_contents[0..replace_start], source[0..replace_start]);
    @memcpy(next_contents[replace_start .. replace_start + replacement.len], replacement);
    @memcpy(next_contents[replace_start + replacement.len ..], source[replace_end..]);

    validateEditedSourceIncremental(&parser, &tree, source, next_contents) catch {
        var full_tree = try parseStrict(&parser, next_contents);
        full_tree.deinit();
    };
    return .{
        .contents = next_contents,
        .target_start = target_start,
        .target_end = target_end,
        .target_bytes_before = target_end - target_start,
        .target_bytes_after = replacement.len,
        .snippet_bytes = snippet.len,
        .used_markers = used_markers,
    };
}

pub fn validateSource(lang: bindings.Language, source: []const u8) !void {
    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return error.UnsupportedLanguage;
    var tree = try parseStrict(&parser, source);
    defer tree.deinit();
}

pub fn validateEditedSourceIncremental(
    parser: *bindings.Parser,
    old_tree: *bindings.Tree,
    original_source: []const u8,
    next_source: []const u8,
) !void {
    const input_edit = try incremental.makeInputEditBetween(original_source, next_source);
    old_tree.edit(input_edit);

    var new_tree = parser.parseStringWithOld(next_source, old_tree) orelse return error.ParseFailed;
    defer new_tree.deinit();
    if (new_tree.rootNode().isNull() or new_tree.rootNode().hasError()) return error.ParseFailed;
}

pub fn commentStylesFor(language: bindings.Language) []const []const u8 {
    return switch (language) {
        .typescript, .tsx => &typescript_comment_styles,
        .rust, .go => &typescript_comment_styles,
        .python => &python_comment_styles,
    };
}

fn parseStrict(parser: *bindings.Parser, source: []const u8) !bindings.Tree {
    var tree = parser.parseString(source) orelse return error.ParseFailed;
    if (tree.rootNode().isNull() or tree.rootNode().hasError()) {
        tree.deinit();
        return error.ParseFailed;
    }
    return tree;
}

pub const ByteRange = struct {
    start: usize,
    end: usize,
};

pub fn replacementRangeFor(lang: bindings.Language, source: []const u8, target: bindings.Node) ByteRange {
    const fallback: ByteRange = .{ .start = @intCast(target.startByte()), .end = @intCast(target.endByte()) };
    const body = findBodyNode(target) orelse return fallback;
    const body_start: usize = @intCast(body.startByte());
    const body_end: usize = @intCast(body.endByte());
    if (body_end <= body_start or body_end > source.len) return fallback;

    return switch (lang) {
        .typescript, .tsx, .rust, .go => braceInteriorRange(source, body_start, body_end) orelse fallback,
        .python => .{ .start = body_start, .end = body_end },
    };
}

pub fn findBodyNode(target: bindings.Node) ?bindings.Node {
    var i: u32 = 0;
    while (i < target.childCount()) : (i += 1) {
        if (target.fieldNameForChild(i)) |field_name| {
            if (std.mem.eql(u8, field_name, "body")) return target.child(i);
        }
    }

    i = 0;
    while (i < target.namedChildCount()) : (i += 1) {
        const child = target.namedChild(i) orelse continue;
        const kind = child.kind();
        if (std.mem.eql(u8, kind, "statement_block") or
            std.mem.eql(u8, kind, "block") or
            std.mem.eql(u8, kind, "class_body") or
            std.mem.eql(u8, kind, "declaration_list")) return child;
    }
    return null;
}

pub fn braceInteriorRange(source: []const u8, start: usize, end: usize) ?ByteRange {
    if (end <= start + 1 or end > source.len) return null;
    var left = start;
    while (left < end and std.ascii.isWhitespace(source[left])) : (left += 1) {}
    var right = end;
    while (right > left and std.ascii.isWhitespace(source[right - 1])) : (right -= 1) {}
    if (right <= left + 1 or source[left] != '{' or source[right - 1] != '}') return null;
    return .{ .start = left + 1, .end = right - 1 };
}

fn normalizeReplaceSnippet(allocator: std.mem.Allocator, lang: bindings.Language, original_body: []const u8, snippet: []const u8) ![]u8 {
    return switch (lang) {
        .typescript, .tsx, .rust, .go => normalizeBraceBodySnippet(allocator, original_body, snippet),
        .python => normalizePythonBodySnippet(allocator, snippet),
    };
}

fn outerBraceInterior(snippet: []const u8) ?ByteRange {
    var depth: usize = 0;
    var open: ?usize = null;
    var last_range: ?ByteRange = null;
    var i: usize = 0;
    while (i < snippet.len) : (i += 1) {
        switch (snippet[i]) {
            '{' => {
                if (depth == 0) open = i;
                depth += 1;
            },
            '}' => {
                if (depth == 0) return null;
                depth -= 1;
                if (depth == 0) {
                    const start = open orelse return null;
                    last_range = .{ .start = start + 1, .end = i };
                    open = null;
                }
            },
            else => {},
        }
    }
    const range = last_range orelse return null;
    const trailing = std.mem.trim(u8, snippet[range.end + 1 ..], " \t\r\n\x0b\x0c");
    if (trailing.len != 0) return null;
    return range;
}

fn normalizeBraceBodySnippet(allocator: std.mem.Allocator, original_body: []const u8, snippet: []const u8) ![]u8 {
    if (outerBraceInterior(snippet)) |range| {
        return allocator.dupe(u8, snippet[range.start..range.end]);
    }

    const trimmed = std.mem.trim(u8, snippet, "\r\n");
    if (trimmed.len == 0) return allocator.dupe(u8, "");

    const original_has_newline = std.mem.indexOfScalar(u8, original_body, '\n') != null;
    const leading_byte: ?u8 = if (original_has_newline and trimmed[0] != '\n') '\n' else if (original_body.len > 0 and isBoundaryWhitespace(original_body[0]) and !isBoundaryWhitespace(trimmed[0])) original_body[0] else null;
    const trailing_byte: ?u8 = if (original_has_newline and trimmed[trimmed.len - 1] != '\n') '\n' else if (original_body.len > 0 and isBoundaryWhitespace(original_body[original_body.len - 1]) and !isBoundaryWhitespace(trimmed[trimmed.len - 1])) original_body[original_body.len - 1] else null;

    const out_len = trimmed.len + @intFromBool(leading_byte != null) + @intFromBool(trailing_byte != null);
    const out = try allocator.alloc(u8, out_len);
    var at: usize = 0;
    if (leading_byte) |byte| {
        out[at] = byte;
        at += 1;
    }
    @memcpy(out[at .. at + trimmed.len], trimmed);
    at += trimmed.len;
    if (trailing_byte) |byte| out[at] = byte;
    return out;
}

fn isBoundaryWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\n' or byte == '\r';
}

fn normalizePythonBodySnippet(allocator: std.mem.Allocator, snippet: []const u8) ![]u8 {
    const trimmed = std.mem.trimEnd(u8, snippet, " \t\r\n\x0b\x0c");
    const out = try allocator.alloc(u8, trimmed.len + 1);
    @memcpy(out[0..trimmed.len], trimmed);
    out[trimmed.len] = '\n';
    return out;
}

fn normalizeAfterSnippet(allocator: std.mem.Allocator, snippet: []const u8) ![]u8 {
    const trimmed = std.mem.trimEnd(u8, snippet, " \t\r\n\x0b\x0c");
    const out = try allocator.alloc(u8, trimmed.len + 1);
    @memcpy(out[0..trimmed.len], trimmed);
    out[trimmed.len] = '\n';
    return out;
}
