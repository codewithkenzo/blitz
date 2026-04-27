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
