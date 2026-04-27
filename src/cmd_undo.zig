const std = @import("std");
const backup = @import("backup.zig");
const file_lock = @import("lock.zig");
const workspace = @import("workspace.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;

fn writeMessage(writer: *Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try writer.print(fmt, args);
    try writer.flush();
}

fn runWithCacheDir(
    allocator: Allocator,
    io: Io,
    cache_dir: []const u8,
    file_path: []const u8,
    stdout: *Io.Writer,
    stderr: *Io.Writer,
) !u8 {
    const real_path = Dir.cwd().realPathFileAlloc(io, file_path, allocator) catch |err| switch (err) {
        error.FileNotFound => {
            try writeMessage(stderr, "file not found: {s}\n", .{file_path});
            return 1;
        },
        else => |e| return e,
    };
    defer allocator.free(real_path);
    try workspace.enforce(real_path);

    if (!try backup.exists(cache_dir, real_path)) {
        try writeMessage(stderr, "No undo history for {s}. Nothing to revert.\n", .{file_path});
        return 1;
    }

    var lock_guard = try file_lock.acquire(allocator, io, real_path);
    defer lock_guard.release();

    const pre_restore_stat = try Dir.cwd().statFile(io, real_path, .{});

    const contents = backup.load(allocator, io, cache_dir, real_path) catch |err| switch (err) {
        error.NoBackup => {
            try writeMessage(stderr, "No undo history for {s}. Nothing to revert.\n", .{file_path});
            return 1;
        },
        else => |e| return e,
    };
    defer allocator.free(contents);

    try backup.atomicWrite(allocator, io, real_path, contents);

    try Dir.cwd().setTimestamps(io, real_path, .{
        .modify_timestamp = .{ .new = pre_restore_stat.mtime },
    });

    try backup.drop(cache_dir, real_path);

    try writeMessage(stdout, "Reverted {s} to previous state.\n", .{file_path});
    return 0;
}

pub fn run(
    allocator: Allocator,
    io: Io,
    file_path: []const u8,
    stdout: *Io.Writer,
    stderr: *Io.Writer,
) !u8 {
    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    return runWithCacheDir(allocator, io, cache_dir, file_path, stdout, stderr);
}

test "undo round-trips previous contents" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "v1" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    const original_stat = try tmp.dir.statFile(io, "target.txt", .{});
    try backup.store(allocator, io, cache_root, target_path, "v1");

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "v2" });
    try tmp.dir.setTimestamps(io, "target.txt", .{
        .modify_timestamp = .{ .new = original_stat.mtime },
    });

    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdout_writer = Io.Writer.fixed(&stdout_buf);
    var stderr_writer = Io.Writer.fixed(&stderr_buf);

    const rc = try runWithCacheDir(allocator, io, cache_root, target_path, &stdout_writer, &stderr_writer);
    try std.testing.expectEqual(@as(u8, 0), rc);

    const restored = try tmp.dir.readFileAlloc(io, target_path, allocator, .unlimited);
    defer allocator.free(restored);
    try std.testing.expectEqualSlices(u8, "v1", restored);
    const expected_stdout = try std.fmt.allocPrint(allocator, "Reverted {s} to previous state.\n", .{target_path});
    defer allocator.free(expected_stdout);
    try std.testing.expectEqualSlices(u8, expected_stdout, stdout_writer.buffered());
    try std.testing.expectEqualSlices(u8, "", stderr_writer.buffered());
    try std.testing.expect(!try backup.exists(cache_root, target_path));
}

test "undo missing backup prints no history" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "plain" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdout_writer = Io.Writer.fixed(&stdout_buf);
    var stderr_writer = Io.Writer.fixed(&stderr_buf);

    const rc = try runWithCacheDir(allocator, io, cache_root, target_path, &stdout_writer, &stderr_writer);
    try std.testing.expectEqual(@as(u8, 1), rc);
    const expected_stderr = try std.fmt.allocPrint(allocator, "No undo history for {s}. Nothing to revert.\n", .{target_path});
    defer allocator.free(expected_stderr);
    try std.testing.expectEqualSlices(u8, "", stdout_writer.buffered());
    try std.testing.expectEqualSlices(u8, expected_stderr, stderr_writer.buffered());
}

test "undo missing file prints file not found" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const missing_path = try std.fs.path.join(allocator, &.{ cache_root, "missing.txt" });
    defer allocator.free(missing_path);

    var stdout_buf: [256]u8 = undefined;
    var stderr_buf: [256]u8 = undefined;
    var stdout_writer = Io.Writer.fixed(&stdout_buf);
    var stderr_writer = Io.Writer.fixed(&stderr_buf);

    const rc = try runWithCacheDir(allocator, io, cache_root, missing_path, &stdout_writer, &stderr_writer);
    try std.testing.expectEqual(@as(u8, 1), rc);
    const expected_stderr = try std.fmt.allocPrint(allocator, "file not found: {s}\n", .{missing_path});
    defer allocator.free(expected_stderr);
    try std.testing.expectEqualSlices(u8, "", stdout_writer.buffered());
    try std.testing.expectEqualSlices(u8, expected_stderr, stderr_writer.buffered());
}
