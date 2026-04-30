const std = @import("std");

pub const Error = error{PathEscapesWorkspace};

var root: ?[]const u8 = null;

pub fn setRoot(workspace_root: ?[]const u8) void {
    root = workspace_root;
}

pub fn enforce(real_path: []const u8) Error!void {
    const workspace = root orelse return;
    if (workspace.len == 0) return;
    if (!isInside(real_path, workspace)) return error.PathEscapesWorkspace;
}

fn isInside(path: []const u8, workspace_root: []const u8) bool {
    if (std.mem.eql(u8, path, workspace_root)) return true;
    if (workspace_root.len == 0) return false;
    if (!std.mem.startsWith(u8, path, workspace_root)) return false;
    if (workspace_root[workspace_root.len - 1] == std.fs.path.sep) return true;
    return path.len > workspace_root.len and path[workspace_root.len] == std.fs.path.sep;
}

test "workspace boundary accepts child" {
    try std.testing.expect(isInside("/tmp/project/src/a.ts", "/tmp/project"));
}

test "workspace boundary rejects sibling prefix" {
    try std.testing.expect(!isInside("/tmp/project-evil/a.ts", "/tmp/project"));
}

test "workspace.enforce allows realpath inside root" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const root_path = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(root_path);
    setRoot(root_path);
    defer setRoot(null);

    const inside = "inside.ts";
    try tmp.dir.writeFile(io, .{ .sub_path = inside, .data = "const keep = 1;\n" });
    const inside_real = try tmp.dir.realPathFileAlloc(io, inside, allocator);
    defer allocator.free(inside_real);

    try enforce(inside_real);
}

test "workspace.enforce rejects absolute path outside root" {
    var tmp_root = std.testing.tmpDir(.{});
    defer tmp_root.cleanup();
    var tmp_outside = std.testing.tmpDir(.{});
    defer tmp_outside.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const root_path = try tmp_root.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(root_path);
    setRoot(root_path);
    defer setRoot(null);

    try tmp_outside.dir.writeFile(io, .{ .sub_path = "outside.ts", .data = "const drift = 1;\n" });
    const outside_real = try tmp_outside.dir.realPathFileAlloc(io, "outside.ts", allocator);
    defer allocator.free(outside_real);

    try std.testing.expectError(Error.PathEscapesWorkspace, enforce(outside_real));
}

test "workspace.enforce rejects symlink escape" {
    const os = @import("builtin");
    if (os.os.tag == .windows) return;

    var tmp_root = std.testing.tmpDir(.{});
    defer tmp_root.cleanup();
    var tmp_outside = std.testing.tmpDir(.{});
    defer tmp_outside.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const root_path = try tmp_root.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(root_path);
    setRoot(root_path);
    defer setRoot(null);

    const target = "outside.ts";
    try tmp_outside.dir.writeFile(io, .{ .sub_path = target, .data = "const x = 1;\n" });
    const outside_target = try tmp_outside.dir.realPathFileAlloc(io, target, allocator);
    defer allocator.free(outside_target);

    try tmp_root.dir.symLink(io, outside_target, "leak", .{});
    const leak_real = try tmp_root.dir.realPathFileAlloc(io, "leak", allocator);
    defer allocator.free(leak_real);

    try std.testing.expect(!std.mem.startsWith(u8, leak_real, root_path));
    try std.testing.expectError(Error.PathEscapesWorkspace, enforce(leak_real));
}
