const std = @import("std");

const bindings = @import("../tree_sitter/bindings.zig");
const edit_support = @import("../edit_support.zig");

pub const SingleRangeEdit = struct {
    start: usize,
    end: usize,
    replacement: []const u8,
};

pub fn parseAfterEdit(
    allocator: std.mem.Allocator,
    parser: *bindings.Parser,
    source_tree: *bindings.Tree,
    original: []const u8,
    next_source: []const u8,
    full_parse: bool,
    single_range: ?SingleRangeEdit,
) !bool {
    if (full_parse) return fullParseClean(parser, next_source);

    if (single_range) |range| {
        edit_support.validateSingleRangeEditIncremental(
            allocator,
            parser,
            source_tree,
            original,
            next_source,
            range.start,
            range.end,
            range.replacement,
        ) catch |err| return cleanAfterSingleRangeValidationError(parser, next_source, err);
        return true;
    }

    edit_support.validateEditedSourceIncremental(parser, source_tree, original, next_source) catch return fullParseClean(parser, next_source);
    return true;
}

fn cleanAfterSingleRangeValidationError(parser: *bindings.Parser, next_source: []const u8, err: anyerror) bool {
    return switch (err) {
        error.ChangedRangesTooBroad => false,
        else => fullParseClean(parser, next_source),
    };
}

fn fullParseClean(parser: *bindings.Parser, next_source: []const u8) bool {
    var final_tree = parser.parseString(next_source) orelse return false;
    defer final_tree.deinit();
    return !final_tree.rootNode().isNull() and !final_tree.rootNode().hasError();
}

test "single-range changed ranges too broad fails closed" {
    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    try std.testing.expect(!cleanAfterSingleRangeValidationError(&parser, "function ok() { return 2; }", error.ChangedRangesTooBroad));
    try std.testing.expect(cleanAfterSingleRangeValidationError(&parser, "function ok() { return 2; }", error.ParseFailed));
}

test "parseAfterEdit reports parse failures" {
    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    {
        var tree = parser.parseString("function ok() { return 1; }") orelse return error.TestExpectedFail;
        defer tree.deinit();
        try std.testing.expect(try parseAfterEdit(std.testing.allocator, &parser, &tree, "function ok() { return 1; }", "function ok() { return 2; }", false, null));
    }

    {
        var tree = parser.parseString("function ok() { return 1; }") orelse return error.TestExpectedFail;
        defer tree.deinit();
        try std.testing.expect(!(try parseAfterEdit(std.testing.allocator, &parser, &tree, "function ok() { return 1; }", "function ok( { return 2; }", false, null)));
    }

    {
        var tree = parser.parseString("function ok() { return 1; }") orelse return error.TestExpectedFail;
        defer tree.deinit();
        try std.testing.expect(!(try parseAfterEdit(std.testing.allocator, &parser, &tree, "function ok() { return 1; }", "function ok( { return 2; }", true, null)));
    }
}
