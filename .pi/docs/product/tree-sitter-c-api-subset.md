# Tree-sitter C-API subset for blitz

Scope: minimum C surface for `src/tree_sitter/bindings.zig`.
No `@cImport`; Zig 0.16 externs only.

## 1) Exact C signatures to extern-declare

```c
TSParser *ts_parser_new(void); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L217-L217
void ts_parser_delete(TSParser *self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L222-L222
bool ts_parser_set_language(TSParser *self, const TSLanguage *language); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L239-L239
TSTree *ts_parser_parse_string(TSParser *self, const TSTree *old_tree, const char *string, uint32_t length); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L343-L348
void ts_tree_delete(TSTree *self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L412-L412
TSNode ts_tree_root_node(const TSTree *self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L417-L417
void ts_tree_edit(TSTree *self, const TSInputEdit *edit); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L451-L451
const char *ts_node_type(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L492-L492
uint32_t ts_node_start_byte(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L520-L520
TSPoint ts_node_start_point(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L525-L525
uint32_t ts_node_end_byte(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L530-L530
TSPoint ts_node_end_point(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L535-L535
TSNode ts_node_child(TSNode self, uint32_t child_index); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L614-L614
const char *ts_node_field_name_for_child(TSNode self, uint32_t child_index); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L620-L620
uint32_t ts_node_child_count(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L631-L631
TSNode ts_node_named_child(TSNode self, uint32_t child_index); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L638-L638
uint32_t ts_node_named_child_count(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L645-L645
bool ts_node_is_null(TSNode self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L550-L550
TSQuery *ts_query_new(const TSLanguage *language, const char *source, uint32_t source_len, uint32_t *error_offset, TSQueryError *error_type); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L907-L913
void ts_query_delete(TSQuery *self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L918-L918
const char *ts_query_capture_name_for_id(const TSQuery *self, uint32_t index, uint32_t *length); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L991-L995
TSQueryCursor *ts_query_cursor_new(void); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L1052-L1052
void ts_query_cursor_delete(TSQueryCursor *self); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L1057-L1057
void ts_query_cursor_exec(TSQueryCursor *self, const TSQuery *query, TSNode node); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L1062-L1062
bool ts_query_cursor_set_byte_range(TSQueryCursor *self, uint32_t start_byte, uint32_t end_byte); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L1104-L1104
bool ts_query_cursor_next_capture(TSQueryCursor *self, TSQueryMatch *match, uint32_t *capture_index); // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L1160-L1164
```

## 2) Exact structs / opaque handles needed

```zig
pub const TSLanguage = opaque {}; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L44-L44
pub const TSParser = opaque {}; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L45-L45
pub const TSTree = opaque {}; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L46-L46
pub const TSQuery = opaque {}; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L47-L47
pub const TSQueryCursor = opaque {}; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L48-L48
pub const TSPoint = extern struct { row: u32, column: u32 }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L77-L80
pub const TSRange = extern struct { start_point: TSPoint, end_point: TSPoint, start_byte: u32, end_byte: u32 }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L82-L87
pub const TSInputEdit = extern struct { start_byte: u32, old_end_byte: u32, new_end_byte: u32, start_point: TSPoint, old_end_point: TSPoint, new_end_point: TSPoint }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L124-L131
pub const TSNode = extern struct { context: [4]u32, id: ?*const anyopaque, tree: ?*const TSTree }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L133-L137
pub const TSQueryError = enum(c_uint) { TSQueryErrorNone = 0, TSQueryErrorSyntax, TSQueryErrorNodeType, TSQueryErrorField, TSQueryErrorCapture, TSQueryErrorStructure, TSQueryErrorLanguage }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L176-L184
pub const TSQueryCapture = extern struct { node: TSNode, index: u32 }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L145-L148
pub const TSQueryMatch = extern struct { id: u32, pattern_index: u16, capture_count: u16, captures: [*c]const TSQueryCapture }; // https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h#L158-L163
```

## 3) Ownership + free rules

- `TSParser`: own after `ts_parser_new()`. Free once with `ts_parser_delete()`; one delete per parser. Source: `api.h#L217-L222`.
- `TSTree`: own after parse. Free once with `ts_tree_delete()`. Source: `api.h#L410-L412` + parse return at `api.h#L317-L348`.
- `TSQuery`: own after `ts_query_new()` success. Free once with `ts_query_delete()`. Source: `api.h#L907-L918`.
- `TSQueryCursor`: own after `ts_query_cursor_new()`. Free once with `ts_query_cursor_delete()`. Source: `api.h#L1052-L1057`.
- `ts_tree_edit()` mutates tree in place; no free, no new tree. Apply edit, then reparse with old tree passed back into parser. Source: `api.h#L442-L451` and `api.h#L317-L348`.
- `TSNode`, `TSPoint`, `TSRange`, `TSInputEdit`: value structs; no destroy call.

## 4) Zig 0.16 extern-module skeleton

```zig
const std = @import("std");

pub const TSLanguage = opaque {};
pub const TSParser = opaque {};
pub const TSTree = opaque {};
pub const TSQuery = opaque {};
pub const TSQueryCursor = opaque {};

pub const TSPoint = extern struct { row: u32, column: u32 };
pub const TSRange = extern struct { start_point: TSPoint, end_point: TSPoint, start_byte: u32, end_byte: u32 };
pub const TSInputEdit = extern struct { start_byte: u32, old_end_byte: u32, new_end_byte: u32, start_point: TSPoint, old_end_point: TSPoint, new_end_point: TSPoint };
pub const TSNode = extern struct { context: [4]u32, id: ?*const anyopaque, tree: ?*const TSTree };
pub const TSQueryError = enum(c_uint) { TSQueryErrorNone = 0, TSQueryErrorSyntax, TSQueryErrorNodeType, TSQueryErrorField, TSQueryErrorCapture, TSQueryErrorStructure, TSQueryErrorLanguage };
pub const TSQueryCapture = extern struct { node: TSNode, index: u32 };
pub const TSQueryMatch = extern struct { id: u32, pattern_index: u16, capture_count: u16, captures: [*c]const TSQueryCapture };

pub extern fn ts_parser_new() *TSParser;
pub extern fn ts_parser_delete(self: *TSParser) void;
pub extern fn ts_parser_set_language(self: *TSParser, language: *const TSLanguage) bool;
pub extern fn ts_parser_parse_string(self: *TSParser, old_tree: ?*const TSTree, string: [*]const u8, length: u32) ?*TSTree;
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
pub extern fn ts_query_new(language: *const TSLanguage, source: [*]const u8, source_len: u32, error_offset: *u32, error_type: *TSQueryError) ?*TSQuery;
pub extern fn ts_query_delete(self: *TSQuery) void;
pub extern fn ts_query_capture_name_for_id(self: *const TSQuery, index: u32, length: *u32) [*:0]const u8;
pub extern fn ts_query_cursor_new() *TSQueryCursor;
pub extern fn ts_query_cursor_delete(self: *TSQueryCursor) void;
pub extern fn ts_query_cursor_exec(self: *TSQueryCursor, query: *const TSQuery, node: TSNode) void;
pub extern fn ts_query_cursor_set_byte_range(self: *TSQueryCursor, start_byte: u32, end_byte: u32) bool;
pub extern fn ts_query_cursor_next_capture(self: *TSQueryCursor, match: *TSQueryMatch, capture_index: *u32) bool;

pub const Parser = struct {
    raw: *TSParser,
    pub fn init() !Parser { /* wrap null-check + error mapping */ }
    pub fn deinit(self: *Parser) void { ts_parser_delete(self.raw); }
    pub fn setLanguage(self: *Parser, lang: *const TSLanguage) !void { /* bool -> error */ }
    pub fn parseString(self: *Parser, source: []const u8, old_tree: ?*const TSTree) !*TSTree { /* null -> error */ }
};

pub const Tree = struct {
    raw: *TSTree,
    pub fn deinit(self: *Tree) void { ts_tree_delete(self.raw); }
    pub fn rootNode(self: *const Tree) Node { return .{ .raw = ts_tree_root_node(self.raw) }; }
    pub fn edit(self: *Tree, edit: TSInputEdit) void { ts_tree_edit(self.raw, &edit); }
};

pub const Node = struct {
    raw: TSNode,
    pub fn kind(self: Node) []const u8 { return std.mem.span(ts_node_type(self.raw)); }
    pub fn childCount(self: Node) u32 { return ts_node_child_count(self.raw); }
    pub fn child(self: Node, i: u32) ?Node { const n = ts_node_child(self.raw, i); return if (ts_node_is_null(n)) null else .{ .raw = n }; }
    pub fn namedChild(self: Node, i: u32) ?Node { const n = ts_node_named_child(self.raw, i); return if (ts_node_is_null(n)) null else .{ .raw = n }; }
};
```

Safe wrappers: `Parser.init/setLanguage/parseString`, `Tree.rootNode/edit/deinit`, `Node.kind/childCount/child/namedChild`, `Query` init/deinit, `Cursor` init/deinit/exec/setByteRange/nextCapture.
Raw only: extern fn declarations + `TSNode` value struct.

Build integration sketch:

```zig
const ts = b.createModule(.{ .root_source_file = b.path("src/tree_sitter/bindings.zig") });
ts.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
// link C core via static lib / addCSourceFiles on build artifact, not @cImport.
```

## 5) Gotchas

- `TSNode` is a value type, not pointer. Copy by value is fine; never `delete` it. Source: `api.h#L133-L137`.
- `ts_node_is_null()` gates empty results. `ts_node_child()`, `ts_node_named_child()`, `ts_node_parent()`, siblings can return null nodes. Source: `api.h#L546-L550`.
- `ts_query_cursor_set_byte_range()` filters by intersecting range, not full containment. A match can still include nodes outside range. Source: `api.h#L1090-L1104`.
- `ts_parser_set_language()` can return `false` on ABI mismatch. Check before parse. Source: `api.h#L231-L239`.
- Incremental flow is `ts_tree_edit()` old tree -> parse again with that edited tree as `old_tree`. Source: `api.h#L442-L451` + `api.h#L317-L348`.
- `ts_query_new()` can fail; use `error_offset` + `error_type` to report syntax / language errors. Source: `api.h#L901-L913`.
```
