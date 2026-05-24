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

pub fn normalizeWallMs(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const needle = "\"wall_ms\":";
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], needle)) {
            try out.appendSlice(allocator, "\"wall_ms\":0");
            i += needle.len;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            continue;
        }
        try out.append(allocator, input[i]);
        i += 1;
    }

    return out.toOwnedSlice(allocator);
}

pub fn expectApplySnapshot(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_name: []const u8,
    original: []const u8,
    request_template: []const u8,
    expected_json: []const u8,
    run_fn: anytype,
) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = file_name, .data = original });
    const path = try tmp.dir.realPathFileAlloc(io, file_name, allocator);
    defer allocator.free(path);

    const actual = try runApplyTest(allocator, io, request_template, path, run_fn);
    defer allocator.free(actual);
    const normalized = try normalizeWallMs(allocator, actual);
    defer allocator.free(normalized);
    try std.testing.expectEqualSlices(u8, expected_json, normalized);
}
