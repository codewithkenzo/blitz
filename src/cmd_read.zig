const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");

const Writer = std.Io.Writer;

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    stdout: *Writer,
    stderr: *Writer,
) !u8 {
    _ = stderr;

    const ext = std.fs.path.extension(file_path);
    const lang = bindings.Language.fromExtension(ext) orelse {
        try stdout.print("{s} (unsupported language)\n", .{file_path});
        try stdout.flush();
        return 0;
    };

    const contents = try readFileAlloc(allocator, io, file_path);
    defer allocator.free(contents);

    const line_count = countLines(contents);
    if (line_count <= 100) {
        try stdout.print(
            "{s} ({d} lines — small file, showing full content)\n\n{s}",
            .{ file_path, line_count, contents },
        );
        try stdout.flush();
        return 0;
    }

    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return error.ParserLanguageRejected;

    var tree = parser.parseString(contents) orelse return error.ParseFailed;
    defer tree.deinit();

    try stdout.print("{s} ({s}, {d} lines)\n", .{ file_path, @tagName(lang), line_count });
    try writeStructureSummary(stdout, tree.rootNode(), contents);
    try stdout.flush();
    return 0;
}

fn readFileAlloc(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8) ![]u8 {
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.openFile(io, file_path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    const capacity = std.math.cast(usize, stat.size) orelse return error.FileTooBig;
    const buffer = try allocator.alloc(u8, capacity);
    errdefer allocator.free(buffer);

    const n = try file.readPositionalAll(io, buffer, 0);
    return buffer[0..n];
}

fn countLines(source: []const u8) usize {
    if (source.len == 0) return 0;

    var lines: usize = 1;
    for (source) |byte| {
        if (byte == '\n') lines += 1;
    }
    if (source[source.len - 1] == '\n') lines -= 1;
    return lines;
}

fn writeStructureSummary(stdout: *Writer, root: bindings.Node, source: []const u8) !void {
    var i: u32 = 0;
    const child_count = root.namedChildCount();
    while (i < child_count) : (i += 1) {
        const child = root.namedChild(i) orelse continue;
        const kind = child.kind();
        if (!isSummaryKind(kind)) continue;
        try writeSummaryLine(stdout, child, source);
    }
}

fn isSummaryKind(kind: []const u8) bool {
    inline for (.{
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
        "import_statement",
        "import_declaration",
        "import_from_statement",
    }) |expected| {
        if (std.mem.eql(u8, kind, expected)) return true;
    }
    return false;
}

fn writeSummaryLine(stdout: *Writer, node: bindings.Node, source: []const u8) !void {
    const start_row: usize = @as(usize, node.startPoint().row) + 1;
    const end_row: usize = @as(usize, node.endPoint().row) + 1;

    if (extractName(node, source)) |name| {
        try stdout.print("L{d}-{d}  {s}  {s}\n", .{ start_row, end_row, node.kind(), name });
    } else {
        try stdout.print("L{d}-{d}  {s}\n", .{ start_row, end_row, node.kind() });
    }
}

fn extractName(node: bindings.Node, source: []const u8) ?[]const u8 {
    const child_count = node.childCount();

    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.fieldNameForChild(i)) |field_name| {
            if (std.mem.eql(u8, field_name, "name")) {
                if (node.child(i)) |child| {
                    if (!child.isNull()) {
                        const start = @as(usize, child.startByte());
                        const end = @as(usize, child.endByte());
                        if (start <= end and end <= source.len) return source[start..end];
                    }
                }
            }
        }
    }

    i = 0;
    while (i < child_count) : (i += 1) {
        const child = node.child(i) orelse continue;
        const kind = child.kind();
        if (!isIdentifierLike(kind)) continue;

        const start = @as(usize, child.startByte());
        const end = @as(usize, child.endByte());
        if (start <= end and end <= source.len) return source[start..end];
    }

    return null;
}

fn isIdentifierLike(kind: []const u8) bool {
    return std.mem.indexOf(u8, kind, "identifier") != null;
}

test "tiny TypeScript file uses small file branch and verbatim content" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file_name = "tiny.ts";
    const file_contents = "const a = 1;\nconst b = 2;\nconst c = 3;";
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = file_name, .data = file_contents });
    const abs_path = try tmp.dir.realPathFileAlloc(std.testing.io, file_name, std.testing.allocator);
    defer std.testing.allocator.free(abs_path);

    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var err: Writer.Allocating = .init(std.testing.allocator);
    defer err.deinit();

    const code = try run(std.testing.allocator, std.testing.io, abs_path, &out.writer, &err.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expectEqualStrings("", err.written());
    const output = out.written();
    try std.testing.expect(std.mem.startsWith(u8, output, abs_path));
    try std.testing.expect(std.mem.indexOf(u8, output, "small file, showing full content") != null);
    try std.testing.expect(std.mem.endsWith(u8, output, file_contents));
}

test "larger TypeScript file uses structure path and emits function summary" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file_name = "large.ts";
    const chunk = "let x = 1;\n";
    const tail = "function foo() {}";
    const large_len = chunk.len * 100 + tail.len;
    const large = try std.testing.allocator.alloc(u8, large_len);
    defer std.testing.allocator.free(large);

    var offset: usize = 0;
    for (0..100) |_| {
        @memcpy(large[offset .. offset + chunk.len], chunk);
        offset += chunk.len;
    }
    @memcpy(large[offset .. offset + tail.len], tail);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = file_name, .data = large });
    const abs_path = try tmp.dir.realPathFileAlloc(std.testing.io, file_name, std.testing.allocator);
    defer std.testing.allocator.free(abs_path);

    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var err: Writer.Allocating = .init(std.testing.allocator);
    defer err.deinit();

    const code = try run(std.testing.allocator, std.testing.io, abs_path, &out.writer, &err.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expectEqualStrings("", err.written());

    const output = out.written();
    try std.testing.expect(std.mem.startsWith(u8, output, abs_path));
    try std.testing.expect(std.mem.indexOf(u8, output, "(typescript, 101 lines)\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "L101-101  function_declaration  foo") != null);
}

test "unknown extension prints unsupported language line" {
    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    var err: Writer.Allocating = .init(std.testing.allocator);
    defer err.deinit();

    const code = try run(std.testing.allocator, std.testing.io, "sample.txt", &out.writer, &err.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expectEqualStrings("", err.written());
    try std.testing.expectEqualStrings("sample.txt (unsupported language)\n", out.written());
}
