const std = @import("std");
const bindings = @import("../tree_sitter/bindings.zig");
const ir = @import("ir.zig");

pub const ApplyOperation = enum {
    replace_unique,
    insert_after_anchor,
    insert_before_anchor,
    replace_between,
    append_section,
    ensure_line,
    delete_range,
    replace_body_span,
    insert_body_span,
    wrap_body,
    multi_body,
    compose_body,
    merge_body_chunk,
    insert_after_symbol,
    set_body,
    set_key,
    patch,
};

pub const TargetRange = enum { body, node };

pub const MatchKind = enum { default_single, first, last, only, index };

pub const MatchSelector = struct {
    kind: MatchKind,
    index: usize = 0,
};

pub const EditSpan = struct { start: usize, end: usize };

pub const MatchSpan = struct {
    start: usize,
    end: usize,
    single_match: bool,
    total: usize,
};

pub const OpResult = struct {
    contents: []u8,
    range: ir.RangesResult,
    single_match: bool,
    changed_before: usize,
    changed_after: usize,
};

pub const MultiEdit = struct {
    start: usize,
    end: usize,
    replacement: []const u8,
    replacement_owned: bool,
    range: ir.RangesResult,
    single_match: bool,
    changed_before: usize,
    changed_after: usize,
};

pub const ComposeResult = struct {
    contents: []u8,
    single_match: bool,
};

pub const KeepSliceResult = struct {
    span: EditSpan,
    single_match: bool,
};

pub fn parseOperation(raw: []const u8) !ApplyOperation {
    if (std.mem.eql(u8, raw, "replace_unique")) return .replace_unique;
    if (std.mem.eql(u8, raw, "insert_after_anchor")) return .insert_after_anchor;
    if (std.mem.eql(u8, raw, "insert_before_anchor")) return .insert_before_anchor;
    if (std.mem.eql(u8, raw, "replace_between")) return .replace_between;
    if (std.mem.eql(u8, raw, "append_section")) return .append_section;
    if (std.mem.eql(u8, raw, "ensure_line")) return .ensure_line;
    if (std.mem.eql(u8, raw, "delete_range")) return .delete_range;
    if (std.mem.eql(u8, raw, "replace_body_span")) return .replace_body_span;
    if (std.mem.eql(u8, raw, "insert_body_span")) return .insert_body_span;
    if (std.mem.eql(u8, raw, "wrap_body")) return .wrap_body;
    if (std.mem.eql(u8, raw, "multi_body")) return .multi_body;
    if (std.mem.eql(u8, raw, "compose_body")) return .compose_body;
    if (std.mem.eql(u8, raw, "merge_body_chunk")) return .merge_body_chunk;
    if (std.mem.eql(u8, raw, "insert_after_symbol")) return .insert_after_symbol;
    if (std.mem.eql(u8, raw, "set_body")) return .set_body;
    if (std.mem.eql(u8, raw, "set_key")) return .set_key;
    if (std.mem.eql(u8, raw, "patch") or std.mem.eql(u8, raw, "compact_patch")) return .patch;
    return error.UnsupportedOperation;
}

pub fn parseTargetRange(raw: ?[]const u8) !TargetRange {
    if (raw == null) return .body;
    const value = raw.?;
    if (std.mem.eql(u8, value, "body")) return .body;
    if (std.mem.eql(u8, value, "node")) return .node;
    return error.UnsupportedTargetRange;
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
    if (needle.len == 0) return error.PatternEmpty;
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
            if (require_single_match and total != 1) return if (total == 0) error.NoMatches else error.AmbiguousMatches;
            if (first == null) return error.NoMatches;
            break :blk first.?;
        },
        .first => first orelse return error.NoMatches,
        .last => blk: {
            if (total == 0) return error.NoMatches;
            var last: ?EditSpan = null;
            cursor = 0;
            while (std.mem.indexOfPos(u8, haystack, cursor, needle)) |start| {
                last = EditSpan{ .start = start, .end = start + needle.len };
                cursor = start + 1;
            }
            break :blk last orelse return error.NoMatches;
        },
        .only => blk: {
            if (total == 0) return error.NoMatches;
            if (total != 1) return error.AmbiguousMatches;
            break :blk first.?;
        },
        .index => selected orelse return error.NoMatches,
    };
    return .{ .start = chosen.start, .end = chosen.end, .single_match = total == 1, .total = total };
}

pub fn selectSpanFromCandidates(candidates: []const EditSpan, selector: MatchSelector, require_single_match: bool) !MatchSpan {
    if (candidates.len == 0) return error.NoMatches;
    const chosen = switch (selector.kind) {
        .default_single => blk: {
            if (require_single_match and candidates.len != 1) return if (candidates.len == 0) error.NoMatches else error.AmbiguousMatches;
            break :blk candidates[0];
        },
        .first => candidates[0],
        .last => candidates[candidates.len - 1],
        .only => blk: {
            if (candidates.len != 1) return error.AmbiguousMatches;
            break :blk candidates[0];
        },
        .index => blk: {
            if (selector.index == 0 or selector.index > candidates.len) return error.NoMatches;
            break :blk candidates[selector.index - 1];
        },
    };
    return .{ .start = chosen.start, .end = chosen.end, .single_match = candidates.len == 1, .total = candidates.len };
}

pub fn requireTupleString(items: std.json.Array, index: usize) ![]const u8 {
    if (index >= items.items.len) return error.MissingField;
    return switch (items.items[index]) {
        .string => |value| value,
        else => error.FieldTypeMismatch,
    };
}

pub fn tupleOptionalValue(items: std.json.Array, index: usize) ?std.json.Value {
    if (index >= items.items.len) return null;
    return items.items[index];
}

pub fn tupleOptionalIndent(items: std.json.Array, index: usize, default_value: usize) !usize {
    const value = tupleOptionalValue(items, index) orelse return default_value;
    return switch (value) {
        .integer => |v| if (v < 0) return error.InvalidOccurrence else @as(usize, @intCast(v)),
        .float => |v| blk: {
            const rounded = @round(v);
            if (v < 0 or rounded != v) return error.InvalidOccurrence;
            break :blk @as(usize, @intFromFloat(rounded));
        },
        else => error.FieldTypeMismatch,
    };
}
