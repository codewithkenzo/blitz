const std = @import("std");

const bindings = @import("../tree_sitter/bindings.zig");
const edit_support = @import("../edit_support.zig");

pub fn parseAfterEdit(
    parser: *bindings.Parser,
    source_tree: *bindings.Tree,
    original: []const u8,
    next_source: []const u8,
    full_parse: bool,
) !bool {
    if (full_parse) {
        var final_tree = parser.parseString(next_source) orelse return false;
        defer final_tree.deinit();
        return !final_tree.rootNode().isNull() and !final_tree.rootNode().hasError();
    }

    edit_support.validateEditedSourceIncremental(parser, source_tree, original, next_source) catch return false;
    return true;
}

test "parseAfterEdit reports parse failures" {
    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = parser.parseString("function ok() { return 1; }") orelse return error.TestExpectedFail;
    defer tree.deinit();

    try std.testing.expect(try parseAfterEdit(&parser, &tree, "function ok() { return 1; }", "function ok() { return 2; }", false));
    try std.testing.expect(!(try parseAfterEdit(&parser, &tree, "function ok() { return 1; }", "function ok( { return 2; }", false)));
    try std.testing.expect(!(try parseAfterEdit(&parser, &tree, "function ok() { return 1; }", "function ok() { return ; }", true)));
}
