//! SHA-keyed single-depth backup store for per-file undo.
//!
//! Module keeps one snapshot per file, keyed by canonical path + pre-edit
//! mtime. Backups live under `${XDG_CACHE_HOME:-~/.cache}/blitz/backup` and
//! are written atomically.

const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;

pub const BackupError = error{
    NoBackup,
    AtomicWriteFailed,
    KeyCollision,
    CacheDirUnavailable,
} || anyerror;

const Snapshot = struct {
    backup_name: []u8,

    fn deinit(self: *Snapshot, allocator: Allocator) void {
        allocator.free(self.backup_name);
        self.* = undefined;
    }
};

fn getEnvVarOwnedMaybe(allocator: Allocator, name: []const u8) !?[]u8 {
    // libc getenv (we link libc; std.posix.getenv was removed in Zig 0.16).
    if (name.len == 0 or name.len > 255) return null;
    var key_buf: [256]u8 = undefined;
    @memcpy(key_buf[0..name.len], name);
    key_buf[name.len] = 0;
    const key_z: [*:0]const u8 = @ptrCast(&key_buf);
    const value_ptr = std.c.getenv(key_z) orelse return null;
    const value = std.mem.span(value_ptr);
    if (value.len == 0) return null;
    return try allocator.dupe(u8, value);
}

pub fn defaultCacheDir(allocator: Allocator) ![]u8 {
    if (try getEnvVarOwnedMaybe(allocator, "XDG_CACHE_HOME")) |xdg| {
        if (xdg.len > 0) return xdg;
        allocator.free(xdg);
    }

    const home = (try getEnvVarOwnedMaybe(allocator, "HOME")) orelse {
        return error.CacheDirUnavailable;
    };
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".cache" });
}

fn backupRootPath(allocator: Allocator, cache_dir: []const u8) ![]u8 {
    if (cache_dir.len == 0) return error.CacheDirUnavailable;
    return std.fs.path.join(allocator, &.{ cache_dir, "blitz", "backup" });
}

fn openBackupDir(allocator: Allocator, io: Io, cache_dir: []const u8) !Dir {
    const root = try backupRootPath(allocator, cache_dir);
    defer allocator.free(root);
    return Dir.cwd().openDir(io, root, .{});
}

fn ensureBackupDir(allocator: Allocator, io: Io, cache_dir: []const u8) !Dir {
    const root = try backupRootPath(allocator, cache_dir);
    defer allocator.free(root);
    return Dir.cwd().createDirPathOpen(io, root, .{});
}

fn snapshotTarget(allocator: Allocator, io: Io, target_path: []const u8) !Snapshot {
    const real_path = try Dir.cwd().realPathFileAlloc(io, target_path, allocator);
    defer allocator.free(real_path);

    // Single-depth backup per file: key on realpath only. Including mtime
    // would break the post-edit lookup path because atomicWrite changes the
    // mtime, and undo needs to find the backup we just stored. Matches
    // fastedit's BackupStore semantics (latest pre-edit snapshot).
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(real_path);
    const digest = hasher.finalResult();
    const hex = std.fmt.bytesToHex(digest, .lower);

    const backup_name = try std.fmt.allocPrint(allocator, "{s}.bak", .{hex[0..]});
    return .{ .backup_name = backup_name };
}

fn writeAtomicFile(
    allocator: Allocator,
    io: Io,
    dir: Dir,
    path: []const u8,
    contents: []const u8,
    replace: bool,
) !void {
    const atomic = try dir.createFileAtomic(io, path, .{ .replace = replace });
    var atomic_file = atomic;
    defer atomic_file.deinit(io);

    const write_buf = try allocator.alloc(u8, 8192);
    defer allocator.free(write_buf);

    var writer = atomic_file.file.writerStreaming(io, write_buf);
    writer.interface.writeAll(contents) catch return error.AtomicWriteFailed;
    writer.flush() catch return error.AtomicWriteFailed;

    if (replace) {
        atomic_file.replace(io) catch return error.AtomicWriteFailed;
    } else {
        atomic_file.link(io) catch |err| switch (err) {
            error.PathAlreadyExists => return error.KeyCollision,
            else => return error.AtomicWriteFailed,
        };
    }
}

/// Reusable atomic-write helper for target files.
pub fn atomicWrite(allocator: Allocator, io: Io, path: []const u8, contents: []const u8) !void {
    try writeAtomicFile(allocator, io, Dir.cwd(), path, contents, true);
}

/// Writes snapshot to cache store keyed by realpath + pre-edit mtime.
pub fn store(
    allocator: Allocator,
    io: Io,
    cache_dir: []const u8,
    target_path: []const u8,
    pre_edit_contents: []const u8,
) BackupError!void {
    var snapshot = snapshotTarget(allocator, io, target_path) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
    defer snapshot.deinit(allocator);

    var backup_dir = try ensureBackupDir(allocator, io, cache_dir);
    defer backup_dir.close(io);

    // replace=true: each new edit overwrites the prior backup so we always
    // hold the latest pre-edit snapshot for this realpath. Single-depth
    // semantics from fastedit's BackupStore.
    try writeAtomicFile(allocator, io, backup_dir, snapshot.backup_name, pre_edit_contents, true);
}

/// Checks whether latest backup exists for current target mtime.
pub fn exists(cache_dir: []const u8, target_path: []const u8) !bool {
    return existsImpl(std.heap.page_allocator, std.Io.Threaded.global_single_threaded.io(), cache_dir, target_path);
}

fn existsImpl(allocator: Allocator, io: Io, cache_dir: []const u8, target_path: []const u8) !bool {
    var snapshot = snapshotTarget(allocator, io, target_path) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer snapshot.deinit(allocator);

    const backup_dir = openBackupDir(allocator, io, cache_dir) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer backup_dir.close(io);

    _ = backup_dir.statFile(io, snapshot.backup_name, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    return true;
}

/// Reads snapshot bytes. Caller owns returned memory.
pub fn load(
    allocator: Allocator,
    io: Io,
    cache_dir: []const u8,
    target_path: []const u8,
) BackupError![]u8 {
    var snapshot = snapshotTarget(allocator, io, target_path) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
    defer snapshot.deinit(allocator);

    const backup_dir = openBackupDir(allocator, io, cache_dir) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
    defer backup_dir.close(io);

    return backup_dir.readFileAlloc(io, snapshot.backup_name, allocator, .unlimited) catch |err| switch (err) {
        error.FileNotFound => error.NoBackup,
        else => |e| return e,
    };
}

/// Deletes current backup file for target.
pub fn drop(cache_dir: []const u8, target_path: []const u8) BackupError!void {
    try dropImpl(std.heap.page_allocator, std.Io.Threaded.global_single_threaded.io(), cache_dir, target_path);
}

fn dropImpl(allocator: Allocator, io: Io, cache_dir: []const u8, target_path: []const u8) BackupError!void {
    var snapshot = snapshotTarget(allocator, io, target_path) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
    defer snapshot.deinit(allocator);

    const backup_dir = openBackupDir(allocator, io, cache_dir) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
    defer backup_dir.close(io);

    backup_dir.deleteFile(io, snapshot.backup_name) catch |err| switch (err) {
        error.FileNotFound => return error.NoBackup,
        else => |e| return e,
    };
}

test "store + load round-trips snapshot" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "hello\nbackup\x00world" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    try store(allocator, io, cache_root, target_path, "hello\nbackup\x00world");
    const loaded = try load(allocator, io, cache_root, target_path);
    defer allocator.free(loaded);

    try std.testing.expectEqualSlices(u8, "hello\nbackup\x00world", loaded);
}

test "exists returns false when target not backed up" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "plain" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    try std.testing.expect(!try exists(cache_root, target_path));
}

test "exists survives mtime changes (single-depth undo round-trip)" {
    // With single-depth-per-path keying, a backup must remain reachable
    // after the target file's mtime changes. The post-edit undo path
    // depends on this: edit -> store(pre_edit) -> atomicWrite (changes
    // mtime) -> undo finds the backup.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "v1" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    const old_stat = try tmp.dir.statFile(io, "target.txt", .{});
    try store(allocator, io, cache_root, target_path, "v1");

    var file = try tmp.dir.openFile(io, "target.txt", .{ .mode = .read_write });
    defer file.close(io);
    try file.setTimestamps(io, .{ .modify_timestamp = .{ .new = std.Io.Timestamp.fromNanoseconds(old_stat.mtime.nanoseconds + 1) } });

    try std.testing.expect(try exists(cache_root, target_path));
}

test "drop removes backup file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{ .sub_path = "target.txt", .data = "delete-me" });

    const cache_root = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(cache_root);
    const target_path = try tmp.dir.realPathFileAlloc(io, "target.txt", allocator);
    defer allocator.free(target_path);

    try store(allocator, io, cache_root, target_path, "delete-me");
    try drop(cache_root, target_path);
    try std.testing.expectError(error.NoBackup, load(allocator, io, cache_root, target_path));
}
