const std = @import("std");

pub const c = struct {
    pub const TSLanguage = opaque {};
    pub const TSParser = opaque {};
    pub const TSTree = opaque {};
    pub const TSQuery = opaque {};
    pub const TSQueryCursor = opaque {};

    pub const TSPoint = extern struct {
        row: u32,
        column: u32,
    };

    pub const TSRange = extern struct {
        start_point: TSPoint,
        end_point: TSPoint,
        start_byte: u32,
        end_byte: u32,
    };

    pub const TSInputEdit = extern struct {
        start_byte: u32,
        old_end_byte: u32,
        new_end_byte: u32,
        start_point: TSPoint,
        old_end_point: TSPoint,
        new_end_point: TSPoint,
    };

    pub const TSNode = extern struct {
        context: [4]u32,
        id: ?*const anyopaque,
        tree: ?*const TSTree,
    };

    pub const TSQueryError = enum(c_uint) {
        TSQueryErrorNone = 0,
        TSQueryErrorSyntax,
        TSQueryErrorNodeType,
        TSQueryErrorField,
        TSQueryErrorCapture,
        TSQueryErrorStructure,
        TSQueryErrorLanguage,
    };

    pub const TSQueryCapture = extern struct {
        node: TSNode,
        index: u32,
    };

    pub const TSQueryMatch = extern struct {
        id: u32,
        pattern_index: u16,
        capture_count: u16,
        captures: [*c]const TSQueryCapture,
    };

    pub extern fn ts_parser_new() *TSParser;
    pub extern fn ts_parser_delete(self: *TSParser) void;
    pub extern fn ts_parser_set_language(self: *TSParser, language: *const TSLanguage) bool;
    pub extern fn ts_parser_parse_string(
        self: *TSParser,
        old_tree: ?*const TSTree,
        string: [*]const u8,
        length: u32,
    ) ?*TSTree;
    pub extern fn ts_tree_delete(self: *TSTree) void;
    pub extern fn ts_tree_root_node(self: *const TSTree) TSNode;
    pub extern fn ts_tree_edit(self: *TSTree, edit: *const TSInputEdit) void;
    pub extern fn ts_node_type(self: TSNode) [*:0]const u8;
    pub extern fn ts_node_start_byte(self: TSNode) u32;
    pub extern fn ts_node_start_point(self: TSNode) TSPoint;
    pub extern fn ts_node_end_byte(self: TSNode) u32;
    pub extern fn ts_node_end_point(self: TSNode) TSPoint;
    pub extern fn ts_node_child(self: TSNode, child_index: u32) TSNode;
    pub extern fn ts_node_field_name_for_child(self: TSNode, child_index: u32) ?[*:0]const u8;
    pub extern fn ts_node_child_count(self: TSNode) u32;
    pub extern fn ts_node_named_child(self: TSNode, child_index: u32) TSNode;
    pub extern fn ts_node_named_child_count(self: TSNode) u32;
    pub extern fn ts_node_is_null(self: TSNode) bool;
    pub extern fn ts_node_has_error(self: TSNode) bool;
    pub extern fn ts_query_new(
        language: *const TSLanguage,
        source: [*]const u8,
        source_len: u32,
        error_offset: *u32,
        error_type: *TSQueryError,
    ) ?*TSQuery;
    pub extern fn ts_query_delete(self: *TSQuery) void;
    pub extern fn ts_query_capture_name_for_id(
        self: *const TSQuery,
        index: u32,
        length: *u32,
    ) [*:0]const u8;
    pub extern fn ts_query_cursor_new() *TSQueryCursor;
    pub extern fn ts_query_cursor_delete(self: *TSQueryCursor) void;
    pub extern fn ts_query_cursor_exec(self: *TSQueryCursor, query: *const TSQuery, node: TSNode) void;
    pub extern fn ts_query_cursor_set_byte_range(self: *TSQueryCursor, start_byte: u32, end_byte: u32) bool;
    pub extern fn ts_query_cursor_next_capture(
        self: *TSQueryCursor,
        match: *TSQueryMatch,
        capture_index: *u32,
    ) bool;

    pub extern fn tree_sitter_rust() *const TSLanguage;
    pub extern fn tree_sitter_typescript() *const TSLanguage;
    pub extern fn tree_sitter_tsx() *const TSLanguage;
    pub extern fn tree_sitter_python() *const TSLanguage;
    pub extern fn tree_sitter_go() *const TSLanguage;
};

pub const Language = enum {
    rust,
    typescript,
    tsx,
    python,
    go,

    pub fn raw(self: Language) *const c.TSLanguage {
        return switch (self) {
            .rust => c.tree_sitter_rust(),
            .typescript => c.tree_sitter_typescript(),
            .tsx => c.tree_sitter_tsx(),
            .python => c.tree_sitter_python(),
            .go => c.tree_sitter_go(),
        };
    }

    pub fn fromExtension(ext: []const u8) ?Language {
        if (std.ascii.eqlIgnoreCase(ext, ".rs")) return .rust;
        if (std.ascii.eqlIgnoreCase(ext, ".ts")) return .typescript;
        if (std.ascii.eqlIgnoreCase(ext, ".tsx")) return .tsx;
        if (std.ascii.eqlIgnoreCase(ext, ".py")) return .python;
        if (std.ascii.eqlIgnoreCase(ext, ".go")) return .go;
        return null;
    }
};

pub const Parser = struct {
    raw: *c.TSParser,

    pub fn init() Parser {
        return .{ .raw = c.ts_parser_new() };
    }

    pub fn deinit(self: *Parser) void {
        c.ts_parser_delete(self.raw);
    }

    pub fn setLanguage(self: *Parser, lang: Language) bool {
        return c.ts_parser_set_language(self.raw, lang.raw());
    }

    pub fn parseString(self: *Parser, source: []const u8) ?Tree {
        if (source.len > std.math.maxInt(u32)) return null;
        return if (c.ts_parser_parse_string(self.raw, null, source.ptr, @intCast(source.len))) |raw|
            .{ .raw = raw }
        else
            null;
    }
};

pub const Tree = struct {
    raw: *c.TSTree,

    pub fn deinit(self: *Tree) void {
        c.ts_tree_delete(self.raw);
    }

    pub fn rootNode(self: *const Tree) Node {
        return .{ .raw = c.ts_tree_root_node(self.raw) };
    }

    pub fn edit(self: *Tree, input_edit: c.TSInputEdit) void {
        c.ts_tree_edit(self.raw, &input_edit);
    }
};

pub const Node = struct {
    raw: c.TSNode,

    pub fn isNull(self: Node) bool {
        return c.ts_node_is_null(self.raw);
    }

    pub fn kind(self: Node) []const u8 {
        return std.mem.span(c.ts_node_type(self.raw));
    }

    pub fn hasError(self: Node) bool {
        return c.ts_node_has_error(self.raw);
    }

    pub fn startByte(self: Node) u32 {
        return c.ts_node_start_byte(self.raw);
    }

    pub fn endByte(self: Node) u32 {
        return c.ts_node_end_byte(self.raw);
    }

    pub fn startPoint(self: Node) c.TSPoint {
        return c.ts_node_start_point(self.raw);
    }

    pub fn endPoint(self: Node) c.TSPoint {
        return c.ts_node_end_point(self.raw);
    }

    pub fn childCount(self: Node) u32 {
        return c.ts_node_child_count(self.raw);
    }

    pub fn namedChildCount(self: Node) u32 {
        return c.ts_node_named_child_count(self.raw);
    }

    pub fn child(self: Node, i: u32) ?Node {
        const node = c.ts_node_child(self.raw, i);
        if (c.ts_node_is_null(node)) return null;
        return .{ .raw = node };
    }

    pub fn namedChild(self: Node, i: u32) ?Node {
        const node = c.ts_node_named_child(self.raw, i);
        if (c.ts_node_is_null(node)) return null;
        return .{ .raw = node };
    }

    pub fn fieldNameForChild(self: Node, i: u32) ?[]const u8 {
        const name = c.ts_node_field_name_for_child(self.raw, i) orelse return null;
        return std.mem.span(name);
    }
};

pub const QueryInitError = error{
    Syntax,
    NodeType,
    Field,
    Capture,
    Structure,
    Language,
};

fn queryInitErrorFromC(err: c.TSQueryError) QueryInitError {
    return switch (err) {
        .TSQueryErrorSyntax => error.Syntax,
        .TSQueryErrorNodeType => error.NodeType,
        .TSQueryErrorField => error.Field,
        .TSQueryErrorCapture => error.Capture,
        .TSQueryErrorStructure => error.Structure,
        .TSQueryErrorLanguage => error.Language,
        .TSQueryErrorNone => unreachable,
    };
}

pub const Query = struct {
    raw: *c.TSQuery,

    pub fn init(language: Language, source: []const u8) QueryInitError!Query {
        if (source.len > std.math.maxInt(u32)) return error.Structure;

        var error_offset: u32 = 0;
        var error_type: c.TSQueryError = .TSQueryErrorNone;
        const raw = c.ts_query_new(
            language.raw(),
            source.ptr,
            @intCast(source.len),
            &error_offset,
            &error_type,
        );

        if (raw) |query| return .{ .raw = query };
        return queryInitErrorFromC(error_type);
    }

    pub fn deinit(self: *Query) void {
        c.ts_query_delete(self.raw);
    }

    pub fn captureName(self: *const Query, index: u32) []const u8 {
        var length: u32 = 0;
        const name = c.ts_query_capture_name_for_id(self.raw, index, &length);
        return name[0..length];
    }
};

pub const CaptureMatch = struct {
    match: c.TSQueryMatch,
    capture_index: u32,
};

pub const QueryCursor = struct {
    raw: *c.TSQueryCursor,

    pub fn init() QueryCursor {
        return .{ .raw = c.ts_query_cursor_new() };
    }

    pub fn deinit(self: *QueryCursor) void {
        c.ts_query_cursor_delete(self.raw);
    }

    pub fn exec(self: *QueryCursor, query: *const Query, node: Node) void {
        c.ts_query_cursor_exec(self.raw, query.raw, node.raw);
    }

    pub fn setByteRange(self: *QueryCursor, start: u32, end: u32) void {
        std.debug.assert(c.ts_query_cursor_set_byte_range(self.raw, start, end));
    }

    pub fn nextCapture(self: *QueryCursor) ?CaptureMatch {
        var match: c.TSQueryMatch = undefined;
        var capture_index: u32 = 0;
        if (!c.ts_query_cursor_next_capture(self.raw, &match, &capture_index)) return null;
        return .{ .match = match, .capture_index = capture_index };
    }
};

test "Language.fromExtension matches supported extensions" {
    try std.testing.expectEqual(Language.rust, Language.fromExtension(".rs").?);
    try std.testing.expectEqual(Language.typescript, Language.fromExtension(".TS").?);
    try std.testing.expectEqual(Language.tsx, Language.fromExtension(".tsx").?);
    try std.testing.expectEqual(Language.python, Language.fromExtension(".py").?);
    try std.testing.expectEqual(Language.go, Language.fromExtension(".go").?);
    try std.testing.expect(Language.fromExtension(".zig") == null);
}

fn expectParsedNode(lang: Language, source: []const u8) !void {
    var parser = Parser.init();
    defer parser.deinit();

    try std.testing.expect(parser.setLanguage(lang));

    var tree = parser.parseString(source) orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(!root.isNull());
}

test "Parser parses each supported grammar" {
    try expectParsedNode(.rust, "x");
    try expectParsedNode(.typescript, "x");
    try expectParsedNode(.tsx, "<div />");
    try expectParsedNode(.python, "x = 1\n");
    try expectParsedNode(.go, "package main\nfunc main() {}\n");
}

test "TypeScript query finds identifier capture" {
    var parser = Parser.init();
    defer parser.deinit();

    try std.testing.expect(parser.setLanguage(.typescript));

    var tree = parser.parseString("const foo = 1;") orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    try std.testing.expect(!root.isNull());

    var query = try Query.init(.typescript, "(identifier) @id");
    defer query.deinit();

    var cursor = QueryCursor.init();
    defer cursor.deinit();

    cursor.exec(&query, root);

    var capture_count: u32 = 0;
    while (cursor.nextCapture()) |capture| {
        _ = capture;
        capture_count += 1;
    }

    try std.testing.expect(capture_count >= 1);
}
