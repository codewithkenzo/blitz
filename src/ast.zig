const std = @import("std");

const bindings = @import("tree_sitter/bindings.zig");
const grammar_config = @import("grammar_config.zig");

pub const ResolveError = error{
    SymbolNotFound,
    AmbiguousSymbol,
};

pub const ByteRange = struct {
    start: usize,
    end: usize,
};

pub fn parseStrict(parser: *bindings.Parser, source: []const u8) !bindings.Tree {
    var tree = parser.parseString(source) orelse return error.ParseFailed;
    if (tree.rootNode().isNull() or tree.rootNode().hasError()) {
        tree.deinit();
        return error.ParseFailed;
    }
    return tree;
}

pub fn findEditableSymbolNode(source: []const u8, root: bindings.Node, symbol: []const u8) ?bindings.Node {
    return findDeclarationNode(source, root, symbol);
}

pub fn resolveEditableSymbol(source: []const u8, root: bindings.Node, symbol: []const u8) ResolveError!bindings.Node {
    const count = countEditableSymbolMatches(source, root, symbol);
    if (count == 0) return error.SymbolNotFound;
    if (count > 1) return error.AmbiguousSymbol;
    return findDeclarationNode(source, root, symbol) orelse error.SymbolNotFound;
}

pub fn countEditableSymbolMatches(source: []const u8, root: bindings.Node, symbol: []const u8) usize {
    return countDeclarationNodes(source, root, symbol);
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
        if (grammar_config.isBodyKind(child.kind())) return child;
    }

    i = 0;
    while (i < target.namedChildCount()) : (i += 1) {
        const child = target.namedChild(i) orelse continue;
        if (findBodyNode(child)) |body| return body;
    }

    return null;
}

pub fn bodyRangeFor(language: bindings.Language, source: []const u8, target: bindings.Node) ?ByteRange {
    const body = findBodyNode(target) orelse return null;
    const body_start: usize = @intCast(body.startByte());
    const body_end: usize = @intCast(body.endByte());
    if (body_end <= body_start or body_end > source.len) return null;

    return switch (language) {
        .typescript, .tsx, .rust, .go => braceInteriorRange(source, body_start, body_end),
        .python => .{ .start = body_start, .end = body_end },
    };
}

pub fn replacementRangeFor(language: bindings.Language, source: []const u8, target: bindings.Node) ByteRange {
    return bodyRangeFor(language, source, target) orelse .{ .start = @intCast(target.startByte()), .end = @intCast(target.endByte()) };
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

fn findDeclarationNode(source: []const u8, node: bindings.Node, symbol: []const u8) ?bindings.Node {
    if (grammar_config.isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, symbol)) {
        return node;
    }

    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findDeclarationNode(source, child, symbol)) |found| return found;
        }
    }

    return null;
}

fn countDeclarationNodes(source: []const u8, node: bindings.Node, symbol: []const u8) usize {
    var count: usize = 0;
    if (grammar_config.isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, symbol)) {
        count += 1;
    }

    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            count += countDeclarationNodes(source, child, symbol);
            if (count > 1) return count;
        }
    }

    return count;
}

fn nodeHasSymbolName(source: []const u8, node: bindings.Node, symbol: []const u8) bool {
    const name_field = grammar_config.nameFieldForKind(node.kind()) orelse return false;
    const child_count = node.childCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.fieldNameForChild(child_i)) |field_name| {
            if (!std.mem.eql(u8, field_name, name_field)) continue;
            if (node.child(child_i)) |child| {
                const text = source[@intCast(child.startByte())..@intCast(child.endByte())];
                return std.mem.eql(u8, text, symbol);
            }
        }
    }
    return false;
}

test "ast symbol resolver counts duplicate declarations" {
    const source =
        \\function repeat() {}
        \\function repeat() {}
    ;

    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = try parseStrict(&parser, source);
    defer tree.deinit();

    try std.testing.expectEqual(@as(usize, 2), countEditableSymbolMatches(source, tree.rootNode(), "repeat"));
    try std.testing.expectError(error.AmbiguousSymbol, resolveEditableSymbol(source, tree.rootNode(), "repeat"));
}
