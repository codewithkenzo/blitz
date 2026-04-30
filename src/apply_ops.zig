const std = @import("std");
const apply_payload = @import("apply_payload.zig");

const ApplyOperation = apply_payload.ApplyOperation;
const TargetRange = apply_payload.TargetRange;
const MatchSelector = apply_payload.MatchSelector;
const MatchSpan = apply_payload.MatchSpan;
const EditSpan = apply_payload.EditSpan;
const ApplyError = apply_payload.ApplyError;

pub fn parseOperation(raw: []const u8) !ApplyOperation {
    if (std.mem.eql(u8, raw, "replace_body_span")) return .replace_body_span;
    if (std.mem.eql(u8, raw, "insert_body_span")) return .insert_body_span;
    if (std.mem.eql(u8, raw, "wrap_body")) return .wrap_body;
    if (std.mem.eql(u8, raw, "multi_body")) return .multi_body;
    if (std.mem.eql(u8, raw, "compose_body")) return .compose_body;
    if (std.mem.eql(u8, raw, "insert_after_symbol")) return .insert_after_symbol;
    if (std.mem.eql(u8, raw, "set_body")) return .set_body;
    if (std.mem.eql(u8, raw, "patch") or std.mem.eql(u8, raw, "compact_patch")) return .patch;
    return ApplyError.UnsupportedOperation;
}

pub fn parseTargetRange(raw: ?[]const u8) !TargetRange {
    if (raw == null) return .body;
    const value = raw.?;
    if (std.mem.eql(u8, value, "body")) return .body;
    if (std.mem.eql(u8, value, "node")) return .node;
    return ApplyError.UnsupportedTargetRange;
}

pub fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    switch (value) {
        .object => |obj| return obj,
        else => return ApplyError.FieldTypeMismatch,
    }
}

pub fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const node = object.get(field) orelse return ApplyError.MissingField;
    switch (node) {
        .string => |value| return value,
        else => return ApplyError.FieldTypeMismatch,
    }
}

pub fn requireArray(object: std.json.ObjectMap, field: []const u8) !std.json.Array {
    const value = object.get(field) orelse return ApplyError.MissingField;
    switch (value) {
        .array => |arr| return arr,
        else => return ApplyError.FieldTypeMismatch,
    }
}

pub fn requireOptionalString(object: std.json.ObjectMap, field: []const u8) !?[]const u8 {
    const value = object.get(field) orelse return null;
    switch (value) {
        .string => |str| return str,
        else => return ApplyError.FieldTypeMismatch,
    }
}

pub fn requireOptionalBool(object: std.json.ObjectMap, field: []const u8) !?bool {
    const value = object.get(field) orelse return null;
    switch (value) {
        .bool => |value_bool| return value_bool,
        else => return ApplyError.FieldTypeMismatch,
    }
}

pub fn parseMatchSelector(raw: ?std.json.Value) MatchSelector {
    const candidate = raw orelse return .{ .kind = .default_single };
    return switch (candidate) {
        .string => |value| {
            if (std.mem.eql(u8, value, "first")) return .{ .kind = .first };
            if (std.mem.eql(u8, value, "last")) return .{ .kind = .last };
            if (std.mem.eql(u8, value, "only")) return .{ .kind = .only };
            return .{ .kind = .default_single };
        },
        .integer => |value| if (value > 0) .{ .kind = .index, .index = @intCast(value) } else .{ .kind = .default_single },
        .float => |value| blk: {
            if (value <= 0.0 or @round(value) != value) return .{ .kind = .default_single };
            break :blk .{ .kind = .index, .index = @intFromFloat(value) };
        },
        else => .{ .kind = .default_single },
    };
}

pub fn selectMatch(haystack: []const u8, needle: []const u8, selector: MatchSelector, require_single_match: bool) !MatchSpan {
    if (needle.len == 0) return ApplyError.PatternEmpty;

    var first: ?EditSpan = null;
    var selected: ?EditSpan = null;
    var total: usize = 0;
    var cursor: usize = 0;

    while (std.mem.indexOfPos(u8, haystack, cursor, needle)) |start| {
        const span = EditSpan{ .start = start, .end = start + needle.len };
        if (first == null) first = span;
        total += 1;
        if (selector.kind == .first and selected == null) selected = span;
        if (selector.kind == .index and selector.index == total) selected = span;
        cursor = start + 1;
    }

    const chosen = switch (selector.kind) {
        .default_single => blk: {
            if (require_single_match and total != 1) return if (total == 0) ApplyError.NoMatches else ApplyError.AmbiguousMatches;
            if (first == null) return ApplyError.NoMatches;
            break :blk first.?;
        },
        .first => first orelse return ApplyError.NoMatches,
        .last => blk: {
            if (total == 0) return ApplyError.NoMatches;
            var last: ?EditSpan = null;
            cursor = 0;
            while (std.mem.indexOfPos(u8, haystack, cursor, needle)) |start| {
                last = EditSpan{ .start = start, .end = start + needle.len };
                cursor = start + 1;
            }
            break :blk last orelse return ApplyError.NoMatches;
        },
        .only => blk: {
            if (total != 1) return ApplyError.AmbiguousMatches;
            break :blk first orelse return ApplyError.NoMatches;
        },
        .index => selected orelse return ApplyError.NoMatches,
    };

    return MatchSpan{
        .start = chosen.start,
        .end = chosen.end,
        .single_match = total == 1,
        .total = total,
    };
}

pub fn selectSpanFromCandidates(candidates: []const EditSpan, selector: MatchSelector, require_single_match: bool) !MatchSpan {
    if (candidates.len == 0) return ApplyError.NoMatches;

    const chosen = switch (selector.kind) {
        .default_single => blk: {
            if (require_single_match and candidates.len != 1) return if (candidates.len == 0) ApplyError.NoMatches else ApplyError.AmbiguousMatches;
            break :blk candidates[0];
        },
        .first => candidates[0],
        .last => candidates[candidates.len - 1],
        .only => blk: {
            if (candidates.len != 1) return ApplyError.AmbiguousMatches;
            break :blk candidates[0];
        },
        .index => blk: {
            if (selector.index == 0 or selector.index > candidates.len) return ApplyError.NoMatches;
            break :blk candidates[selector.index - 1];
        },
    };

    return MatchSpan{
        .start = chosen.start,
        .end = chosen.end,
        .single_match = candidates.len == 1,
        .total = candidates.len,
    };
}

test "apply ops parse operation aliases" {
    try std.testing.expectEqual(ApplyOperation.patch, try parseOperation("patch"));
    try std.testing.expectEqual(ApplyOperation.patch, try parseOperation("compact_patch"));
    try std.testing.expectError(ApplyError.UnsupportedOperation, parseOperation("unknown"));
}

test "apply ops selector matching" {
    const selector = parseMatchSelector(std.json.Value{ .string = "last" });
    const match = try selectMatch("one two one", "one", selector, false);
    try std.testing.expectEqual(@as(usize, 8), match.start);
    try std.testing.expectEqual(@as(usize, 11), match.end);
    try std.testing.expectEqual(@as(usize, 2), match.total);
}
