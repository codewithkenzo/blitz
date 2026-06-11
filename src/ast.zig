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
    return resolveEditableSymbolWithKind(source, root, symbol, null);
}

pub fn resolveEditableSymbolWithKind(source: []const u8, root: bindings.Node, symbol: []const u8, target_kind: ?[]const u8) ResolveError!bindings.Node {
    const count = countEditableSymbolMatchesWithKind(source, root, symbol, target_kind);
    if (count == 0) return error.SymbolNotFound;
    if (count > 1) return error.AmbiguousSymbol;
    return findDeclarationNodeWithKind(source, root, symbol, target_kind) orelse error.SymbolNotFound;
}

pub fn resolveEditableSymbolOccurrence(source: []const u8, root: bindings.Node, symbol: []const u8, occurrence: usize) ResolveError!bindings.Node {
    return resolveEditableSymbolOccurrenceWithKind(source, root, symbol, occurrence, null);
}

pub fn resolveEditableSymbolOccurrenceWithKind(source: []const u8, root: bindings.Node, symbol: []const u8, occurrence: usize, target_kind: ?[]const u8) ResolveError!bindings.Node {
    var seen: usize = 0;
    return findDeclarationNodeOccurrenceWithKind(source, root, symbol, occurrence, target_kind, &seen) orelse error.SymbolNotFound;
}

pub fn resolveEditableSymbolWithParent(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8) ResolveError!bindings.Node {
    return resolveEditableSymbolWithParentAndKind(source, root, symbol, parent, null);
}

pub fn resolveEditableSymbolWithParentAndKind(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8, target_kind: ?[]const u8) ResolveError!bindings.Node {
    const count = countDeclarationNodesWithParentAndKind(source, root, symbol, parent, target_kind, false);
    if (count == 0) return error.SymbolNotFound;
    if (count > 1) return error.AmbiguousSymbol;
    return findDeclarationNodeWithParentAndKind(source, root, symbol, parent, target_kind, false) orelse error.SymbolNotFound;
}

pub fn resolveEditableSymbolOccurrenceWithParent(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8, occurrence: usize) ResolveError!bindings.Node {
    return resolveEditableSymbolOccurrenceWithParentAndKind(source, root, symbol, parent, occurrence, null);
}

pub fn resolveEditableSymbolOccurrenceWithParentAndKind(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8, occurrence: usize, target_kind: ?[]const u8) ResolveError!bindings.Node {
    var seen: usize = 0;
    return findDeclarationNodeOccurrenceWithParentAndKind(source, root, symbol, parent, occurrence, target_kind, false, &seen) orelse error.SymbolNotFound;
}

pub fn countEditableSymbolMatches(source: []const u8, root: bindings.Node, symbol: []const u8) usize {
    return countEditableSymbolMatchesWithKind(source, root, symbol, null);
}

pub fn countEditableSymbolMatchesWithKind(source: []const u8, root: bindings.Node, symbol: []const u8, target_kind: ?[]const u8) usize {
    return countDeclarationNodesWithKind(source, root, symbol, target_kind);
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
        else => null,
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
    return findDeclarationNodeWithKind(source, node, symbol, null);
}

fn declarationMatchesKind(node_kind: []const u8, target_kind: ?[]const u8) bool {
    if (target_kind) |kind| return grammar_config.targetKindMatches(kind, node_kind);
    return grammar_config.isDeclarationKind(node_kind);
}

fn findDeclarationNodeWithKind(source: []const u8, node: bindings.Node, symbol: []const u8, target_kind: ?[]const u8) ?bindings.Node {
    if (declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        return node;
    }

    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findDeclarationNodeWithKind(source, child, symbol, target_kind)) |found| return found;
        }
    }

    return null;
}

fn findDeclarationNodeOccurrence(source: []const u8, node: bindings.Node, symbol: []const u8, occurrence: usize, seen: *usize) ?bindings.Node {
    return findDeclarationNodeOccurrenceWithKind(source, node, symbol, occurrence, null, seen);
}

fn findDeclarationNodeOccurrenceWithKind(source: []const u8, node: bindings.Node, symbol: []const u8, occurrence: usize, target_kind: ?[]const u8, seen: *usize) ?bindings.Node {
    if (declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        if (seen.* == occurrence) return node;
        seen.* += 1;
    }

    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findDeclarationNodeOccurrenceWithKind(source, child, symbol, occurrence, target_kind, seen)) |found| return found;
        }
    }

    return null;
}

fn countDeclarationNodes(source: []const u8, node: bindings.Node, symbol: []const u8) usize {
    return countDeclarationNodesWithKind(source, node, symbol, null);
}

fn countDeclarationNodesWithKind(source: []const u8, node: bindings.Node, symbol: []const u8, target_kind: ?[]const u8) usize {
    var count: usize = 0;
    if (declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        count += 1;
    }

    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            count += countDeclarationNodesWithKind(source, child, symbol, target_kind);
            if (count > 1) return count;
        }
    }

    return count;
}

fn findDeclarationNodeWithParent(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, ancestor_matches: bool) ?bindings.Node {
    return findDeclarationNodeWithParentAndKind(source, node, symbol, parent, null, ancestor_matches);
}

fn findDeclarationNodeWithParentAndKind(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, target_kind: ?[]const u8, ancestor_matches: bool) ?bindings.Node {
    if (ancestor_matches and declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        return node;
    }

    const child_ancestor_matches = ancestor_matches or (grammar_config.isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, parent));
    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findDeclarationNodeWithParentAndKind(source, child, symbol, parent, target_kind, child_ancestor_matches)) |found| return found;
        }
    }

    return null;
}

fn findDeclarationNodeOccurrenceWithParent(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, occurrence: usize, ancestor_matches: bool, seen: *usize) ?bindings.Node {
    return findDeclarationNodeOccurrenceWithParentAndKind(source, node, symbol, parent, occurrence, null, ancestor_matches, seen);
}

fn findDeclarationNodeOccurrenceWithParentAndKind(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, occurrence: usize, target_kind: ?[]const u8, ancestor_matches: bool, seen: *usize) ?bindings.Node {
    if (ancestor_matches and declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        if (seen.* == occurrence) return node;
        seen.* += 1;
    }

    const child_ancestor_matches = ancestor_matches or (grammar_config.isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, parent));
    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findDeclarationNodeOccurrenceWithParentAndKind(source, child, symbol, parent, occurrence, target_kind, child_ancestor_matches, seen)) |found| return found;
        }
    }

    return null;
}

fn countDeclarationNodesWithParent(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, ancestor_matches: bool) usize {
    return countDeclarationNodesWithParentAndKind(source, node, symbol, parent, null, ancestor_matches);
}

fn countDeclarationNodesWithParentAndKind(source: []const u8, node: bindings.Node, symbol: []const u8, parent: []const u8, target_kind: ?[]const u8, ancestor_matches: bool) usize {
    var count: usize = 0;
    if (ancestor_matches and declarationMatchesKind(node.kind(), target_kind) and nodeHasSymbolName(source, node, symbol)) {
        count += 1;
    }

    const child_ancestor_matches = ancestor_matches or (grammar_config.isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, parent));
    const child_count = node.namedChildCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            count += countDeclarationNodesWithParentAndKind(source, child, symbol, parent, target_kind, child_ancestor_matches);
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

test "ast symbol resolver filters duplicate methods by parent declaration" {
    const source =
        \\const Alpha = {
        \\  run() { return "alpha"; }
        \\};
        \\const Beta = {
        \\  run() { return "beta"; }
        \\};
    ;

    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = try parseStrict(&parser, source);
    defer tree.deinit();

    try std.testing.expectError(error.AmbiguousSymbol, resolveEditableSymbol(source, tree.rootNode(), "run"));
    const beta_run = try resolveEditableSymbolWithParent(source, tree.rootNode(), "run", "Beta");
    const text = source[@intCast(beta_run.startByte())..@intCast(beta_run.endByte())];
    try std.testing.expect(std.mem.indexOf(u8, text, "beta") != null);
    try std.testing.expectError(error.SymbolNotFound, resolveEditableSymbolWithParent(source, tree.rootNode(), "run", "Missing"));
}

test "ast parent filter remains ambiguous within same parent until occurrence supplied" {
    const source =
        \\class Alpha {
        \\  run() { return 1; }
        \\  run() { return 2; }
        \\}
    ;

    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = try parseStrict(&parser, source);
    defer tree.deinit();

    try std.testing.expectError(error.AmbiguousSymbol, resolveEditableSymbolWithParent(source, tree.rootNode(), "run", "Alpha"));
    const second = try resolveEditableSymbolOccurrenceWithParent(source, tree.rootNode(), "run", "Alpha", 1);
    const text = source[@intCast(second.startByte())..@intCast(second.endByte())];
    try std.testing.expect(std.mem.indexOf(u8, text, "2") != null);
}
