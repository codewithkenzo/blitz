const std = @import("std");

const apply_ir = @import("ir.zig");
const apply_ops = @import("operations.zig");

pub fn spliceText(allocator: std.mem.Allocator, source: []const u8, start: usize, end: usize, replacement: []const u8) ![]u8 {
    if (start > end or end > source.len) return error.InvalidPosition;
    const out_len = source.len - (end - start) + replacement.len;
    const out = try allocator.alloc(u8, out_len);
    @memcpy(out[0..start], source[0..start]);
    @memcpy(out[start .. start + replacement.len], replacement);
    @memcpy(out[start + replacement.len ..], source[end..]);
    return out;
}

pub fn applyResolvedEdits(allocator: std.mem.Allocator, original: []const u8, edits: []apply_ops.MultiEdit) ![]u8 {
    if (edits.len == 0) return error.PatternEmpty;

    sortMultiEditsDescending(edits);

    if (hasOverlappingEdits(edits)) return error.OverlappingEdits;

    var current = try allocator.dupe(u8, original);
    errdefer allocator.free(current);

    for (edits) |edit| {
        const next = try spliceText(allocator, current, edit.start, edit.end, edit.replacement);
        allocator.free(current);
        current = next;
    }

    return current;
}

pub fn combinedRangeFromEdits(edits: []apply_ops.MultiEdit) apply_ir.RangesResult {
    if (edits.len == 0) return .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 };

    var target_start = edits[0].range.targetStart;
    var target_end = edits[0].range.targetEnd;
    var body_start: ?usize = edits[0].range.bodyStart;
    var body_end: ?usize = edits[0].range.bodyEnd;
    var edit_start = edits[0].range.editStart;
    var edit_end = edits[0].range.editEnd;

    for (edits[1..]) |edit| {
        if (edit.range.targetStart < target_start) target_start = edit.range.targetStart;
        if (edit.range.targetEnd > target_end) target_end = edit.range.targetEnd;
        if (edit.range.bodyStart) |value| {
            if (body_start == null or value < body_start.?) body_start = value;
        }
        if (edit.range.bodyEnd) |value| {
            if (body_end == null or value > body_end.?) body_end = value;
        }
        if (edit.range.editStart < edit_start) edit_start = edit.range.editStart;
        if (edit.range.editEnd > edit_end) edit_end = edit.range.editEnd;
    }

    return .{
        .targetStart = target_start,
        .targetEnd = target_end,
        .bodyStart = body_start,
        .bodyEnd = body_end,
        .editStart = edit_start,
        .editEnd = edit_end,
    };
}

pub fn allSingleMatch(edits: []apply_ops.MultiEdit) bool {
    for (edits) |edit| if (!edit.single_match) return false;
    return true;
}

pub fn totalChangedBefore(edits: []apply_ops.MultiEdit) usize {
    var total: usize = 0;
    for (edits) |edit| total += edit.changed_before;
    return total;
}

pub fn totalChangedAfter(edits: []apply_ops.MultiEdit) usize {
    var total: usize = 0;
    for (edits) |edit| total += edit.changed_after;
    return total;
}

fn sortMultiEditsDescending(edits: []apply_ops.MultiEdit) void {
    var i: usize = 1;
    while (i < edits.len) : (i += 1) {
        var j = i;
        while (j > 0) {
            if (edits[j].start <= edits[j - 1].start) break;
            std.mem.swap(apply_ops.MultiEdit, &edits[j], &edits[j - 1]);
            j -= 1;
        }
    }
}

fn hasOverlappingEdits(edits: []apply_ops.MultiEdit) bool {
    if (edits.len < 2) return false;

    for (edits[0 .. edits.len - 1], edits[1..]) |left, right| {
        if (left.end > right.start and right.end > left.start) return true;
    }

    return false;
}
