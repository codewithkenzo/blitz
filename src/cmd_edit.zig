const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");
const splice = @import("splice.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;

const EditMode = enum {
    replace,
    after,
};

const supported_kinds = [_][]const u8{
    "function_declaration",
    "function_definition",
    "function_item",
    "method_declaration",
    "class_declaration",
    "class_definition",
    "impl_item",
    "struct_item",
    "enum_item",
    "interface_declaration",
    "type_alias_declaration",
    "variable_declarator",
    "lexical_declaration",
    "identifier",
};

const typescript_comment_styles = [_][]const u8{ "//", "/*" };
const python_comment_styles = [_][]const u8{"#"};

fn commentStylesFor(language: bindings.Language) []const []const u8 {
    return switch (language) {
        .typescript, .tsx => &typescript_comment_styles,
        .rust, .go => &typescript_comment_styles,
        .python => &python_comment_styles,
    };
}

pub fn runReplace(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    symbol: []const u8,
    snippet: []const u8,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    return runEdit(allocator, io, file_path, symbol, snippet, stdout, stderr, .replace);
}

pub fn runAfter(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    symbol: []const u8,
    snippet: []const u8,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    return runEdit(allocator, io, file_path, symbol, snippet, stdout, stderr, .after);
}

fn runEdit(
    allocator: Allocator,
    io: Io,
    file_path: []const u8,
    symbol: []const u8,
    snippet: []const u8,
    stdout: *Writer,
    stderr: *Writer,
    mode: EditMode,
) !u8 {
    const start = Io.Clock.awake.now(io);

    const ext = std.fs.path.extension(file_path);
    const lang = bindings.Language.fromExtension(ext) orelse {
        try stderr.print("unsupported language for {s}\n", .{file_path});
        return 1;
    };

    const real_path = try std.Io.Dir.cwd().realPathFileAlloc(io, file_path, allocator);
    defer allocator.free(real_path);

    const original_contents = try std.Io.Dir.cwd().readFileAlloc(io, real_path, allocator, .unlimited);
    defer allocator.free(original_contents);

    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return error.UnsupportedLanguage;
    var tree = parser.parseString(original_contents) orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    const target = findSymbolNode(original_contents, root, symbol) orelse {
        try stderr.print("symbol '{s}' not found in {s}\n", .{ symbol, file_path });
        return 1;
    };

    const start_byte: usize = @intCast(target.startByte());
    const end_byte: usize = @intCast(target.endByte());

    var replacement: []const u8 = snippet;
    var owned_replacement: ?[]const u8 = null;
    defer if (owned_replacement) |owned| allocator.free(owned);

    if (mode == .replace) {
        const original_body = nodeText(original_contents, target);
        const splice_result = splice.maybeSplice(
            allocator,
            original_body,
            snippet,
            commentStylesFor(lang),
        ) catch |err| switch (err) {
            error.AnchorNotFound => {
                try stderr.print("marker splice failed: anchor not found\n", .{});
                return 1;
            },
            error.MarkerGrammarInvalid => {
                try stderr.print("marker splice failed: invalid marker grammar\n", .{});
                return 1;
            },
            else => return err,
        };

        if (splice_result) |result| {
            replacement = result.merged;
            owned_replacement = result.merged;
        }
    } else {
        replacement = try normalizeAfterSnippet(allocator, snippet);
        owned_replacement = replacement;
    }

    const new_len = original_contents.len - (end_byte - start_byte) + replacement.len;
    const new_contents = try allocator.alloc(u8, new_len);
    defer allocator.free(new_contents);

    @memcpy(new_contents[0..start_byte], original_contents[0..start_byte]);
    @memcpy(new_contents[start_byte .. start_byte + replacement.len], replacement);
    @memcpy(new_contents[start_byte + replacement.len ..], original_contents[end_byte..]);

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    try backup.store(allocator, io, cache_dir, real_path, original_contents);
    try backup.atomicWrite(allocator, io, real_path, new_contents);

    const end = Io.Clock.awake.now(io);
    const latency_ms = start.durationTo(end).toMilliseconds();
    try stdout.print("Applied edit to {s}. latency: {d}ms, 0 tok/s, 0 tokens\n", .{ file_path, latency_ms });
    return 0;
}

fn normalizeAfterSnippet(allocator: Allocator, snippet: []const u8) ![]u8 {
    const trimmed = std.mem.trimEnd(u8, snippet, " \t\r\n\x0b\x0c");
    const out = try allocator.alloc(u8, trimmed.len + 1);
    @memcpy(out[0..trimmed.len], trimmed);
    out[trimmed.len] = '\n';
    return out;
}

fn isSupportedKind(kind: []const u8) bool {
    inline for (supported_kinds) |candidate| {
        if (std.mem.eql(u8, kind, candidate)) return true;
    }
    return false;
}

fn nodeText(source: []const u8, node: bindings.Node) []const u8 {
    return source[@intCast(node.startByte())..@intCast(node.endByte())];
}

fn nodeMatchesSymbol(source: []const u8, node: bindings.Node, symbol: []const u8) bool {
    if (std.mem.eql(u8, node.kind(), "identifier")) {
        return std.mem.eql(u8, nodeText(source, node), symbol);
    }

    const child_count = node.childCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.fieldNameForChild(i)) |field_name| {
            if (std.mem.eql(u8, field_name, "name")) {
                if (node.child(i)) |child| {
                    if (std.mem.eql(u8, nodeText(source, child), symbol)) return true;
                }
            }
        }
    }

    return false;
}

fn findSymbolNode(source: []const u8, node: bindings.Node, symbol: []const u8) ?bindings.Node {
    if (isSupportedKind(node.kind()) and nodeMatchesSymbol(source, node, symbol)) {
        return node;
    }

    const named_count = node.namedChildCount();
    var i: u32 = 0;
    while (i < named_count) : (i += 1) {
        if (node.namedChild(i)) |child| {
            if (findSymbolNode(source, child, symbol)) |found| return found;
        }
    }

    return null;
}

// Tests

test "runReplace on TypeScript fixture" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = "function greet() {}" });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try runReplace(
        allocator,
        io,
        abs_path,
        "greet",
        "function greet() { return 1; }",
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 0), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, "function greet() { return 1; }", contents);
}

test "runAfter on TypeScript fixture" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = "function greet() {}" });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try runAfter(
        allocator,
        io,
        abs_path,
        "greet",
        "\nfunction wave() { return 2; }",
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 0), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, "function greet() {}\nfunction wave() { return 2; }\n", contents);
}

test "runReplace with unknown symbol" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = "function greet() {}" });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try runReplace(
        allocator,
        io,
        abs_path,
        "missing",
        "function nope() {}",
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stderr_buf.written(), "not found") != null);
}

test "runReplace stores backup snapshot" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = "function greet() {}" });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    const status = try runReplace(
        allocator,
        io,
        abs_path,
        "greet",
        "function greet() { return 1; }",
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 0), status);
    try std.testing.expect(try backup.exists(cache_dir, abs_path));

    try backup.drop(cache_dir, abs_path);
}

test "runReplace with marker preserves untouched body" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const fixture =
        \\function greet(name: string): string {
        \\  const prefix = "hi ";
        \\  const body = name.trim();
        \\  const suffix = "!";
        \\  return prefix + body + suffix;
        \\}
    ;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = fixture });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try runReplace(
        allocator,
        io,
        abs_path,
        "greet",
        \\function greet(name: string): string {
        \\  const prefix = "hey ";
        \\  const body = name.trim();
        \\  // ... existing code ...
        \\  return prefix + body + suffix;
        \\}
    ,
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 0), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    const expected =
        \\function greet(name: string): string {
        \\  const prefix = "hey ";
        \\  const body = name.trim();
        \\  const suffix = "!";
        \\  return prefix + body + suffix;
        \\}
    ;
    try std.testing.expectEqualSlices(u8, expected, contents);
}

test "runReplace marker with missing anchor fails without mutation" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original =
        \\function greet(name: string): string {
        \\  const prefix = "hi ";
        \\  const suffix = "!";
        \\  return prefix + suffix;
        \\}
    ;

    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try runReplace(
        allocator,
        io,
        abs_path,
        "greet",
        \\function nope(name: string): string {
        \\  const inserted = "hey ";
        \\  // ... existing code ...
        \\  return "failed";
        \\}
    ,
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stderr_buf.written(), "marker splice failed") != null);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, original, contents);
}
