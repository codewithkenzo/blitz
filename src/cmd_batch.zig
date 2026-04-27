const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = Io.Dir;

const EditMode = enum {
    replace,
    after,
};

const EditSpec = struct {
    snippet: []const u8,
    after: ?[]const u8 = null,
    replace: ?[]const u8 = null,
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

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    edits_json: []const u8,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    const start = Io.Clock.awake.now(io);

    const parsed = std.json.parseFromSlice([]EditSpec, allocator, edits_json, .{}) catch |err| {
        try stderr.print("invalid edits JSON: {s}\n", .{@errorName(err)});
        return 1;
    };
    defer parsed.deinit();

    const edits = parsed.value;
    if (edits.len == 0) {
        try stderr.print("no edits provided", .{});
        return 1;
    }

    const ext = std.fs.path.extension(file_path);
    const lang = bindings.Language.fromExtension(ext) orelse {
        try stderr.print("unsupported language for {s}\n", .{file_path});
        return 1;
    };

    const real_path = try Dir.cwd().realPathFileAlloc(io, file_path, allocator);
    defer allocator.free(real_path);

    const original_contents = try Dir.cwd().readFileAlloc(io, real_path, allocator, .unlimited);
    defer allocator.free(original_contents);

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    backup.store(allocator, io, cache_dir, real_path, original_contents) catch |err| {
        try stderr.print("failed to create backup: {s}\n", .{@errorName(err)});
        return 1;
    };

    var working_contents = try allocator.dupe(u8, original_contents);
    defer allocator.free(working_contents);

    for (edits, 0..) |edit, edit_index| {
        const has_after = edit.after != null;
        const has_replace = edit.replace != null;

        if ((has_after and has_replace) or (!has_after and !has_replace)) {
            dropBackup(cache_dir, real_path);
            try stderr.print("edit[{d}]: exactly one of 'after' or 'replace' must be set\n", .{edit_index});
            return 1;
        }

        const symbol = edit.after orelse edit.replace.?;
        if (edit.snippet.len == 0) {
            dropBackup(cache_dir, real_path);
            try stderr.print("edit[{d}]: snippet must be non-empty\n", .{edit_index});
            return 1;
        }

        const mode: EditMode = if (has_after) .after else .replace;
        const next = applyEdit(
            allocator,
            lang,
            working_contents,
            symbol,
            edit.snippet,
            mode,
        ) catch |err| {
            dropBackup(cache_dir, real_path);
            switch (err) {
                error.ParseFailed => {
                    try stderr.print("edit[{d}]: failed to parse {s}\n", .{ edit_index, file_path });
                },
                error.SymbolNotFound => {
                    try stderr.print("edit[{d}]: symbol '{s}' not found in {s}\n", .{ edit_index, symbol, file_path });
                },
                else => {
                    try stderr.print("edit[{d}]: {s}\n", .{ edit_index, @errorName(err) });
                },
            }
            return 1;
        };

        allocator.free(working_contents);
        working_contents = next;
    }

    backup.atomicWrite(allocator, io, real_path, working_contents) catch |err| {
        dropBackup(cache_dir, real_path);
        try stderr.print("failed to write file: {s}\n", .{@errorName(err)});
        return 1;
    };

    const end = Io.Clock.awake.now(io);
    const latency_ms = start.durationTo(end).toMilliseconds();
    try stdout.print("Applied {d} edits to {s}. latency: {d}ms, 0 tok/s, 0 tokens\n", .{ edits.len, file_path, latency_ms });
    return 0;
}

fn applyEdit(
    allocator: Allocator,
    lang: bindings.Language,
    source: []const u8,
    symbol: []const u8,
    snippet: []const u8,
    mode: EditMode,
) ![]u8 {
    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return error.UnsupportedLanguage;
    var tree = parser.parseString(source) orelse return error.ParseFailed;
    defer tree.deinit();

    const root = tree.rootNode();
    const target = findSymbolNode(source, root, symbol) orelse return error.SymbolNotFound;

    const start_byte: usize = @intCast(target.startByte());
    const end_byte: usize = @intCast(target.endByte());

    const replacement = switch (mode) {
        .replace => snippet,
        .after => try normalizeAfterSnippet(allocator, snippet),
    };
    defer if (mode == .after) allocator.free(replacement);

    const new_len = source.len - (end_byte - start_byte) + replacement.len;
    const next_contents = try allocator.alloc(u8, new_len);

    @memcpy(next_contents[0..start_byte], source[0..start_byte]);
    @memcpy(next_contents[start_byte .. start_byte + replacement.len], replacement);
    @memcpy(next_contents[start_byte + replacement.len ..], source[end_byte..]);
    return next_contents;
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
    var child_i: u32 = 0;
    while (child_i < child_count) : (child_i += 1) {
        if (node.fieldNameForChild(child_i)) |field_name| {
            if (std.mem.eql(u8, field_name, "name")) {
                if (node.child(child_i)) |child| {
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
    var child_i: u32 = 0;
    while (child_i < named_count) : (child_i += 1) {
        if (node.namedChild(child_i)) |child| {
            if (findSymbolNode(source, child, symbol)) |found| return found;
        }
    }

    return null;
}

fn dropBackup(cache_dir: []const u8, real_path: []const u8) void {
    backup.drop(cache_dir, real_path) catch {};
}

test "batch edit replaces multiple symbols and keeps backup" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original = "function greet() {}\n\nfunction ask() {}\n\nfunction bye() {}";
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    const edits_json =
        "[{\"snippet\":\"function greet() { return 1; }\",\"replace\":\"greet\"}," ++
        " {\"snippet\":\"function ask() { return 2; }\",\"replace\":\"ask\"}," ++
        " {\"snippet\":\"function bye() { return 3; }\",\"replace\":\"bye\"}]";

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try run(allocator, io, abs_path, edits_json, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 0), status);

    const expected = "function greet() { return 1; }\n\nfunction ask() { return 2; }\n\nfunction bye() { return 3; }";
    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, expected, contents);

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);
    try std.testing.expect(try backup.exists(cache_dir, abs_path));

    const snapshot = try backup.load(allocator, io, cache_dir, abs_path);
    defer allocator.free(snapshot);
    try std.testing.expectEqualSlices(u8, original, snapshot);
    try backup.drop(cache_dir, abs_path);

    try std.testing.expectEqualStrings("", stderr_buf.written());
    try std.testing.expect(std.mem.indexOf(u8, stdout_buf.written(), "Applied 3 edits to") != null);
}

test "batch edit mixed valid and invalid mode fails and leaves file unchanged" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original = "function greet() {}\n";
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    const edits_json =
        "[{\"snippet\":\"function greet() { return 1; }\",\"replace\":\"greet\"}," ++
        " {\"snippet\":\"function nope() {}\",\"after\":\"missing\",\"replace\":\"bad\"}]";

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);
    if (try backup.exists(cache_dir, abs_path)) {
        try backup.drop(cache_dir, abs_path);
    }

    const status = try run(allocator, io, abs_path, edits_json, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, original, contents);
    try std.testing.expect(!try backup.exists(cache_dir, abs_path));

    try std.testing.expect(std.mem.indexOf(u8, stderr_buf.written(), "edit[1]: exactly one of 'after' or 'replace' must be set") != null);
    try std.testing.expectEqualStrings("", stdout_buf.written());
}

test "batch edit with empty edits array returns error" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original = "function greet() {}";
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try run(allocator, io, abs_path, "[]", &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expectEqualStrings("no edits provided", stderr_buf.written());
    try std.testing.expectEqualStrings("", stdout_buf.written());
}

test "batch edit mid-batch symbol miss fails with index and does not mutate file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original = "function greet() {}\n\nfunction bye() {}";
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    const edits_json =
        "[{\"snippet\":\"function greet() { return 1; }\",\"replace\":\"greet\"}," ++
        " {\"snippet\":\"function missing() {}\",\"replace\":\"missing\"}]";

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try run(allocator, io, abs_path, edits_json, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, original, contents);

    try std.testing.expect(std.mem.indexOf(u8, stderr_buf.written(), "edit[1]: symbol 'missing' not found") != null);
    try std.testing.expectEqualStrings("", stdout_buf.written());

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);
    try std.testing.expect(!try backup.exists(cache_dir, abs_path));
}
