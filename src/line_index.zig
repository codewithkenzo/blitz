const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");

/// Line-start table for converting byte offsets to Tree-sitter points.
///
/// Rows advance on LF bytes. CRLF is therefore handled by treating the LF as
/// the line break; byte offsets inside the CRLF pair still use byte columns on
/// the previous row. Columns are byte offsets from the line start, matching how
/// this project feeds UTF-8 buffers to Tree-sitter.
///
/// `pointAt` uses binary search over line starts, so lookup is O(log n).
pub const LineIndex = struct {
    allocator: std.mem.Allocator,
    source_len: usize,
    line_starts: []usize,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) !LineIndex {
        var starts: std.ArrayList(usize) = .empty;
        errdefer starts.deinit(allocator);

        try starts.append(allocator, 0);
        for (source, 0..) |byte, i| {
            if (byte == '\n') try starts.append(allocator, i + 1);
        }

        return .{
            .allocator = allocator,
            .source_len = source.len,
            .line_starts = try starts.toOwnedSlice(allocator),
        };
    }

    pub fn deinit(self: *LineIndex) void {
        self.allocator.free(self.line_starts);
        self.* = undefined;
    }

    pub fn lineStartOffsets(self: LineIndex) []const usize {
        return self.line_starts;
    }

    pub fn eofPoint(self: LineIndex) !bindings.c.TSPoint {
        return self.pointAt(self.source_len);
    }

    pub fn pointAt(self: LineIndex, byte_offset: usize) !bindings.c.TSPoint {
        if (byte_offset > self.source_len) return error.OffsetOutOfBounds;

        const row_index = self.rowForOffset(byte_offset);
        const line_start = self.line_starts[row_index];
        return .{
            .row = try toU32(row_index),
            .column = try toU32(byte_offset - line_start),
        };
    }

    fn rowForOffset(self: LineIndex, byte_offset: usize) usize {
        var lo: usize = 0;
        var hi: usize = self.line_starts.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.line_starts[mid] <= byte_offset) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo - 1;
    }
};

fn toU32(value: usize) !u32 {
    if (value > std.math.maxInt(u32)) return error.PointOutOfRange;
    return @intCast(value);
}

test "LineIndex handles empty file" {
    var index = try LineIndex.init(std.testing.allocator, "");
    defer index.deinit();

    try std.testing.expectEqualSlices(usize, &.{0}, index.lineStartOffsets());
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 0 }, try index.pointAt(0));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 0 }, try index.eofPoint());
}

test "LineIndex handles single line" {
    const src = "hello";
    var index = try LineIndex.init(std.testing.allocator, src);
    defer index.deinit();

    try std.testing.expectEqualSlices(usize, &.{0}, index.lineStartOffsets());
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 0 }, try index.pointAt(0));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 2 }, try index.pointAt(2));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 5 }, try index.eofPoint());
}

test "LineIndex handles multi-line LF" {
    const src = "a\nbc\ndef";
    var index = try LineIndex.init(std.testing.allocator, src);
    defer index.deinit();

    try std.testing.expectEqualSlices(usize, &.{ 0, 2, 5 }, index.lineStartOffsets());
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 1 }, try index.pointAt(1));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 1 }, try index.pointAt(3));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 2, .column = 3 }, try index.eofPoint());
}

test "LineIndex handles CRLF with byte columns" {
    const src = "a\r\nb";
    var index = try LineIndex.init(std.testing.allocator, src);
    defer index.deinit();

    try std.testing.expectEqualSlices(usize, &.{ 0, 3 }, index.lineStartOffsets());
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 1 }, try index.pointAt(1));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 2 }, try index.pointAt(2));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, try index.pointAt(3));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 1 }, try index.eofPoint());
}

test "LineIndex handles byte at newline boundary" {
    const src = "ab\ncd";
    var index = try LineIndex.init(std.testing.allocator, src);
    defer index.deinit();

    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 2 }, try index.pointAt(2));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, try index.pointAt(3));
}

test "LineIndex handles EOF after trailing newline" {
    const src = "ab\n";
    var index = try LineIndex.init(std.testing.allocator, src);
    defer index.deinit();

    try std.testing.expectEqualSlices(usize, &.{ 0, 3 }, index.lineStartOffsets());
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, try index.eofPoint());
}
