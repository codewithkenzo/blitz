//! Per-canonical-path process lock.
//!
//! The lock is implemented as an atomic directory create under
//! `${XDG_CACHE_HOME:-~/.cache}/blitz/locks/<sha256(realpath)>.lock`.
//! It protects cross-process write paths and the single-depth backup slot.

const std = @import("std");
const backup = @import("backup.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;

pub const LockError = error{
    LockContended,
    LockInvalidPath,
} || anyerror;

pub const FileLock = struct {
    allocator: Allocator,
    io: Io,
    path: []u8,

    pub fn release(self: *FileLock) void {
        Dir.cwd().deleteDir(self.io, self.path) catch {};
        self.allocator.free(self.path);
        self.* = undefined;
    }
};

fn lockRootPath(allocator: Allocator, cache_dir: []const u8) ![]u8 {
    return std.fs.path.join(allocator, &.{ cache_dir, "blitz", "locks" });
}

fn lockName(allocator: Allocator, real_path: []const u8) ![]u8 {
    if (real_path.len == 0) return error.LockInvalidPath;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(real_path);
    const digest = hasher.finalResult();
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "{s}.lock", .{hex[0..]});
}

pub fn acquire(allocator: Allocator, io: Io, real_path: []const u8) LockError!FileLock {
    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    const root = try lockRootPath(allocator, cache_dir);
    defer allocator.free(root);
    try Dir.cwd().createDirPath(io, root);

    const name = try lockName(allocator, real_path);
    defer allocator.free(name);

    const path = try std.fs.path.join(allocator, &.{ root, name });
    errdefer allocator.free(path);

    var attempts: usize = 0;
    while (attempts < 600) : (attempts += 1) {
        Dir.cwd().createDir(io, path, .default_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {
                try Io.sleep(io, Io.Duration.fromMilliseconds(50), Io.Clock.awake);
                continue;
            },
            else => |e| return e,
        };
        return .{ .allocator = allocator, .io = io, .path = path };
    }
    return error.LockContended;
}

test "lock name is stable" {
    const allocator = std.testing.allocator;
    const a = try lockName(allocator, "/tmp/example.ts");
    defer allocator.free(a);
    const b = try lockName(allocator, "/tmp/example.ts");
    defer allocator.free(b);
    try std.testing.expectEqualStrings(a, b);
}
