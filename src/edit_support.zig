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

    var replacement: []const u8 = snippet;
    var used_markers = false;
    var owned_replacement: ?[]u8 = null;
    defer if (owned_replacement) |owned| allocator.free(owned);

    switch (mode) {
        .replace => {
            const original_body = source[target_start..target_end];
            const maybe_merged = splice.maybeSplice(
                allocator,
                original_body,
                snippet,
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

    const replace_start = if (mode == .after) target_end else target_start;
    const replace_end = target_end;
    const new_len = source.len - (replace_end - replace_start) + replacement.len;
    const next_contents = try allocator.alloc(u8, new_len);
    errdefer allocator.free(next_contents);

    @memcpy(next_contents[0..replace_start], source[0..replace_start]);
    @memcpy(next_contents[replace_start .. replace_start + replacement.len], replacement);
    @memcpy(next_contents[replace_start + replacement.len ..], source[replace_end..]);

    try validateEditedSourceIncremental(&parser, &tree, source, next_contents);
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

fn normalizeAfterSnippet(allocator: std.mem.Allocator, snippet: []const u8) ![]u8 {
    const trimmed = std.mem.trimEnd(u8, snippet, " \t\r\n\x0b\x0c");
    const out = try allocator.alloc(u8, trimmed.len + 1);
    @memcpy(out[0..trimmed.len], trimmed);
    out[trimmed.len] = '\n';
    return out;
}
