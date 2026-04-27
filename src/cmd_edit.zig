const std = @import("std");

const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");
const edit_support = @import("edit_support.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;

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
    mode: edit_support.EditMode,
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

    const new_contents = edit_support.applyToSource(
        allocator,
        lang,
        original_contents,
        symbol,
        snippet,
        mode,
    ) catch |err| switch (err) {
        error.SymbolNotFound => {
            try stderr.print("symbol '{s}' not found in {s}\n", .{ symbol, file_path });
            return 1;
        },
        error.AnchorNotFound => {
            try stderr.writeAll("marker splice failed: anchor not found\n");
            return 1;
        },
        error.MarkerGrammarInvalid => {
            try stderr.writeAll("marker splice failed: invalid marker grammar\n");
            return 1;
        },
        error.AmbiguousAnchor => {
            try stderr.writeAll("marker splice failed: ambiguous anchors\n");
            return 1;
        },
        error.ParseFailed => {
            try stderr.print("edited file does not parse for {s}\n", .{file_path});
            return 1;
        },
        else => return err,
    };
    defer allocator.free(new_contents);

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    try backup.store(allocator, io, cache_dir, real_path, original_contents);
    try backup.atomicWrite(allocator, io, real_path, new_contents);

    const end = Io.Clock.awake.now(io);
    const latency_ms = start.durationTo(end).toMilliseconds();
    try stdout.print("Applied edit to {s}. latency: {d}ms, 0 tok/s, 0 tokens\n", .{ file_path, latency_ms });
    return 0;
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

test "runReplace chooses declaration when call-site appears first" {
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
    const expected =
        \\const x = greet();
        \\function greet() { return 1; }
    ;
    try std.testing.expectEqualSlices(u8, expected, contents);
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

test "runReplace shorthand marker is accepted" {
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
        \\  // ...
        \\  return prefix + name.toUpperCase();
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
        \\  const prefix = "hi ";
        \\  return prefix + name.toUpperCase();
        \\}
    ;
    try std.testing.expectEqualSlices(u8, expected, contents);
}

test "runReplace invalid merged file fails without mutation" {
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
        \\  // ... existing code ...
        \\  return prefix + ;
        \\}
    ,
        &stdout_buf.writer,
        &stderr_buf.writer,
    );
    try std.testing.expectEqual(@as(u8, 1), status);
    try std.testing.expect(std.mem.indexOf(u8, stderr_buf.written(), "does not parse") != null);

    const contents = try tmp.dir.readFileAlloc(io, "fixture.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8, original, contents);
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
