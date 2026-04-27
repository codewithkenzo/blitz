const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");
const edit_support = @import("edit_support.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = Io.Dir;

const EditSpec = struct {
    snippet: []const u8,
    after: ?[]const u8 = null,
    replace: ?[]const u8 = null,
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

        const mode: edit_support.EditMode = if (has_after) .after else .replace;
        const next = edit_support.applyToSource(
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
                    try stderr.print("edit[{d}]: edited file does not parse for {s}\n", .{ edit_index, file_path });
                },
                error.SymbolNotFound => {
                    try stderr.print("edit[{d}]: symbol '{s}' not found in {s}\n", .{ edit_index, symbol, file_path });
                },
                error.AnchorNotFound => {
                    try stderr.print("edit[{d}]: marker splice failed: anchor not found\n", .{edit_index});
                },
                error.MarkerGrammarInvalid => {
                    try stderr.print("edit[{d}]: marker splice failed: invalid marker grammar\n", .{edit_index});
                },
                error.AmbiguousAnchor => {
                    try stderr.print("edit[{d}]: marker splice failed: ambiguous anchors\n", .{edit_index});
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

test "batch edit supports marker splice for replace edits" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original =
        \\function greet(name: string): string {
        \\  const prefix = "hi ";
        \\  return prefix + name;
        \\}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    const edits_json =
        "[{\"snippet\":\"function greet(name: string): string {\\n  // ... existing code ...\\n  return prefix + name.toUpperCase();\\n}\",\"replace\":\"greet\"}]";

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try run(allocator, io, abs_path, edits_json, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 0), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    const expected =
        \\function greet(name: string): string {
        \\  const prefix = "hi ";
        \\  return prefix + name.toUpperCase();
        \\}
    ;
    try std.testing.expectEqualSlices(u8, expected, contents);
}

test "batch edit chooses declaration when call-site appears first" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const original =
        \\const x = greet();
        \\function greet() {}
    ;
    try tmp.dir.writeFile(io, .{ .sub_path = "fixture.ts", .data = original });
    const abs_path = try tmp.dir.realPathFileAlloc(io, "fixture.ts", allocator);
    defer allocator.free(abs_path);

    const edits_json =
        "[{\"snippet\":\"function greet() { return 1; }\",\"replace\":\"greet\"}]";

    var stdout_buf: Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();

    const status = try run(allocator, io, abs_path, edits_json, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 0), status);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    const expected =
        \\const x = greet();
        \\function greet() { return 1; }
    ;
    try std.testing.expectEqualSlices(u8, expected, contents);
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
