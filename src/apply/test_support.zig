const std = @import("std");

pub fn runApplyTest(allocator: std.mem.Allocator, io: std.Io, request_template: []const u8, file_path: []const u8, run_fn: anytype) ![]u8 {
    const request = try std.mem.replaceOwned(u8, allocator, request_template, "{FILE}", file_path);
    defer allocator.free(request);
    var stdout_buf: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run_fn(allocator, io, request, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 0), status);
    return allocator.dupe(u8, stdout_buf.written());
}

pub fn runApplyTestExpectFailure(allocator: std.mem.Allocator, io: std.Io, request_template: []const u8, file_path: []const u8, run_fn: anytype) ![]u8 {
    const request = try std.mem.replaceOwned(u8, allocator, request_template, "{FILE}", file_path);
    defer allocator.free(request);
    var stdout_buf: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_buf.deinit();
    var stderr_buf: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_buf.deinit();
    const status = try run_fn(allocator, io, request, false, false, true, &stdout_buf.writer, &stderr_buf.writer);
    try std.testing.expectEqual(@as(u8, 1), status);
    return allocator.dupe(u8, stdout_buf.written());
}
