//! Symbol resolution over edit targets.

const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");

pub const ResolveError = error{
    SymbolNotFound,
    AmbiguousSymbol,
};

const declaration_kinds = [_][]const u8{
    "function_declaration",
    "function_definition",
    "function_item",
    "method_declaration",
    "method_definition",
    "class_declaration",
    "class_definition",
    "impl_item",
    "struct_item",
    "enum_item",
    "interface_declaration",
    "type_alias_declaration",
    "variable_declarator",
};

pub fn findEditableSymbolNode(source: []const u8, root: bindings.Node, symbol: []const u8) ?bindings.Node {
    return findDeclarationNode(source, root, symbol);
}

fn findDeclarationNode(source: []const u8, node: bindings.Node, symbol: []const u8) ?bindings.Node {
    if (isDeclarationKind(node.kind()) and nodeHasSymbolName(source, node, symbol)) {
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

fn isDeclarationKind(kind: []const u8) bool {
    inline for (declaration_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

fn nodeHasSymbolName(source: []const u8, node: bindings.Node, symbol: []const u8) bool {
    const child_count = node.childCount();
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.fieldNameForChild(child_i)) |field_name| {
            if (!std.mem.eql(u8, field_name, "name")) continue;
            if (node.child(child_i)) |child| {
                const text = source[@intCast(child.startByte())..@intCast(child.endByte())];
                return std.mem.eql(u8, text, symbol);
            }
        }
    }
    return false;
}

test "symbol resolver prefers declaration over call-site identifier" {
    const source =
        \\const x = greet();
        \\function greet() {}
    ;

    var parser = bindings.Parser.init();
    defer parser.deinit();
    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = parser.parseString(source) orelse return error.ParseFailed;
    defer tree.deinit();

    const node = findEditableSymbolNode(source, tree.rootNode(), "greet") orelse return error.SymbolNotFound;
    const text = source[@intCast(node.startByte())..@intCast(node.endByte())];
    try std.testing.expectEqualStrings("function greet() {}", text);
}
