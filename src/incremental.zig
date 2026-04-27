const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");

pub const EditPoints = struct {
    start: bindings.c.TSPoint,
    old_end: bindings.c.TSPoint,
    new_end: bindings.c.TSPoint,
};

pub fn makeInputEdit(
    source_before: []const u8,
    replacement: []const u8,
    start_byte: usize,
    old_end_byte: usize,
) !bindings.c.TSInputEdit {
    if (start_byte > old_end_byte or old_end_byte > source_before.len) return error.InvalidEditRange;
    const start_point = pointAt(source_before, start_byte);
    const old_end_point = pointAt(source_before, old_end_byte);
    const new_end_byte = start_byte + replacement.len;
    const new_end_point = pointAfterReplacement(start_point, replacement);
    return makeInputEditFromPoints(start_byte, old_end_byte, new_end_byte, start_point, old_end_point, new_end_point);
}

pub fn makeInputEditBetween(source_before: []const u8, source_after: []const u8) !bindings.c.TSInputEdit {
    var prefix: usize = 0;
    const min_len = @min(source_before.len, source_after.len);
    while (prefix < min_len and source_before[prefix] == source_after[prefix]) : (prefix += 1) {}

    var before_suffix: usize = source_before.len;
    var after_suffix: usize = source_after.len;
    while (before_suffix > prefix and after_suffix > prefix and
        source_before[before_suffix - 1] == source_after[after_suffix - 1])
    {
        before_suffix -= 1;
        after_suffix -= 1;
    }

    const start_point = pointAt(source_before, prefix);
    const old_end_point = pointAt(source_before, before_suffix);
    const new_replacement = source_after[prefix..after_suffix];
    const new_end_point = pointAfterReplacement(start_point, new_replacement);
    return makeInputEditFromPoints(prefix, before_suffix, after_suffix, start_point, old_end_point, new_end_point);
}

fn makeInputEditFromPoints(
    start_byte: usize,
    old_end_byte: usize,
    new_end_byte: usize,
    start_point: bindings.c.TSPoint,
    old_end_point: bindings.c.TSPoint,
    new_end_point: bindings.c.TSPoint,
) !bindings.c.TSInputEdit {
    return .{
        .start_byte = try toU32(start_byte),
        .old_end_byte = try toU32(old_end_byte),
        .new_end_byte = try toU32(new_end_byte),
        .start_point = start_point,
        .old_end_point = old_end_point,
        .new_end_point = new_end_point,
    };
}

pub fn pointAt(source: []const u8, byte_offset: usize) bindings.c.TSPoint {
    const capped = @min(byte_offset, source.len);
    var row: u32 = 0;
    var line_start: usize = 0;
    var i: usize = 0;
    while (i < capped) : (i += 1) {
        if (source[i] == '\n') {
            row += 1;
            line_start = i + 1;
        }
    }
    return .{ .row = row, .column = @intCast(capped - line_start) };
}

pub fn pointAfterReplacement(start: bindings.c.TSPoint, replacement: []const u8) bindings.c.TSPoint {
    var row = start.row;
    var column = start.column;
    for (replacement) |ch| {
        if (ch == '\n') {
            row += 1;
            column = 0;
        } else {
            column += 1;
        }
    }
    return .{ .row = row, .column = column };
}

fn toU32(value: usize) !u32 {
    if (value > std.math.maxInt(u32)) return error.EditRangeTooLarge;
    return @intCast(value);
}

test "pointAt uses byte columns and rows" {
    const src = "a\n  bc\nxyz";
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 0 }, pointAt(src, 0));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, pointAt(src, 2));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 4 }, pointAt(src, 6));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 2, .column = 3 }, pointAt(src, src.len));
}

test "pointAt counts UTF-8 columns as bytes" {
    const src = "éx\n";
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 2 }, pointAt(src, 2));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 0, .column = 3 }, pointAt(src, 3));
}

test "pointAt handles CRLF by incrementing row on LF" {
    const src = "a\r\nb";
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, pointAt(src, 3));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 1 }, pointAt(src, 4));
}

test "pointAfterReplacement computes multi-line end point" {
    const start = bindings.c.TSPoint{ .row = 4, .column = 2 };
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 4, .column = 5 }, pointAfterReplacement(start, "abc"));
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 5, .column = 1 }, pointAfterReplacement(start, "ab\nc"));
}

test "makeInputEditBetween narrows common prefix and suffix" {
    const before = "function f() {\n  return total;\n}\n";
    const after = "function f() {\n  return total + 1;\n}\n";
    const edit = try makeInputEditBetween(before, after);
    const prefix = std.mem.indexOf(u8, before, ";") orelse return error.MissingPrefix;
    try std.testing.expect(edit.start_byte <= prefix);
    try std.testing.expect(edit.old_end_byte < before.len);
    try std.testing.expect(edit.new_end_byte < after.len);
    try std.testing.expect(edit.old_end_byte - edit.start_byte < before.len);
}

test "makeInputEdit builds byte and point ranges" {
    const src = "aaa\nbbb\nccc";
    const edit = try makeInputEdit(src, "x\ny", 4, 7);
    try std.testing.expectEqual(@as(u32, 4), edit.start_byte);
    try std.testing.expectEqual(@as(u32, 7), edit.old_end_byte);
    try std.testing.expectEqual(@as(u32, 7), edit.new_end_byte);
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 0 }, edit.start_point);
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 1, .column = 3 }, edit.old_end_point);
    try std.testing.expectEqual(bindings.c.TSPoint{ .row = 2, .column = 1 }, edit.new_end_point);
}
