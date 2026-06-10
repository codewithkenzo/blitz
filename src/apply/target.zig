const std = @import("std");

const ast = @import("../ast.zig");
const apply_ir = @import("ir.zig");
const bindings = @import("../tree_sitter/bindings.zig");

pub const ByteRange = ast.ByteRange;
pub const ResolveError = ast.ResolveError;
pub const TargetRange = enum { body, node };
pub const MatchKind = enum { default_single, first, last, only, index };
pub const MatchSelector = struct {
    kind: MatchKind,
    index: usize = 0,
};
pub const EditSpan = struct {
    start: usize,
    end: usize,
};
pub const MatchSpan = struct {
    start: usize,
    end: usize,
    single_match: bool,
    total: usize,
};
pub const KeepSliceResult = struct {
    span: EditSpan,
    single_match: bool,
};

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

pub fn resolveEditableSymbol(source: []const u8, root: bindings.Node, symbol: []const u8) ResolveError!bindings.Node {
    return ast.resolveEditableSymbol(source, root, symbol);
}

pub fn resolveEditableSymbolOccurrence(source: []const u8, root: bindings.Node, symbol: []const u8, occurrence: usize) ResolveError!bindings.Node {
    return ast.resolveEditableSymbolOccurrence(source, root, symbol, occurrence);
}

pub fn resolveEditableSymbolWithParent(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8) ResolveError!bindings.Node {
    return ast.resolveEditableSymbolWithParent(source, root, symbol, parent);
}

pub fn resolveEditableSymbolOccurrenceWithParent(source: []const u8, root: bindings.Node, symbol: []const u8, parent: []const u8, occurrence: usize) ResolveError!bindings.Node {
    return ast.resolveEditableSymbolOccurrenceWithParent(source, root, symbol, parent, occurrence);
}

pub fn countEditableSymbolMatches(source: []const u8, root: bindings.Node, symbol: []const u8) usize {
    return ast.countEditableSymbolMatches(source, root, symbol);
}

pub fn findBodyNode(target: bindings.Node) ?bindings.Node {
    return ast.findBodyNode(target);
}

pub fn bodyRangeFor(language: bindings.Language, source: []const u8, target: bindings.Node) ?ByteRange {
    return ast.bodyRangeFor(language, source, target);
}

pub fn replacementRangeFor(language: bindings.Language, source: []const u8, target: bindings.Node) ByteRange {
    return ast.replacementRangeFor(language, source, target);
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
            if (total != 1) return error.AmbiguousMatches;
            break :blk first orelse return error.NoMatches;
        },
        .index => selected orelse return error.NoMatches,
    };

    return .{
        .start = chosen.start,
        .end = chosen.end,
        .single_match = total == 1,
        .total = total,
    };
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

    return .{
        .start = chosen.start,
        .end = chosen.end,
        .single_match = candidates.len == 1,
        .total = candidates.len,
    };
}

pub fn parseKeepSpan(body: []const u8, keep_obj: std.json.ObjectMap, require_single_match: bool) !KeepSliceResult {
    var it = keep_obj.iterator();
    while (it.next()) |entry| {
        if (!std.mem.eql(u8, entry.key_ptr.*, "beforeKeep") and
            !std.mem.eql(u8, entry.key_ptr.*, "afterKeep") and
            !std.mem.eql(u8, entry.key_ptr.*, "includeBefore") and
            !std.mem.eql(u8, entry.key_ptr.*, "includeAfter") and
            !std.mem.eql(u8, entry.key_ptr.*, "occurrence")) return error.FieldTypeMismatch;
    }

    const before_keep = try apply_ir.requireOptionalString(keep_obj, "beforeKeep");
    const after_keep = try apply_ir.requireOptionalString(keep_obj, "afterKeep");
    if (before_keep == null and after_keep == null) return error.FieldTypeMismatch;

    const include_before = if (try apply_ir.requireOptionalBool(keep_obj, "includeBefore")) |value| value else false;
    const include_after = if (try apply_ir.requireOptionalBool(keep_obj, "includeAfter")) |value| value else false;
    const selector = parseMatchSelector(keep_obj.get("occurrence"));
    const require_single = if (selector.kind == .default_single) require_single_match else false;

    const before_match = if (before_keep) |needle| try selectMatch(body, needle, selector, require_single) else null;
    const after_match = if (after_keep) |needle| try selectMatch(body, needle, selector, require_single) else null;

    const start: usize = if (before_match) |match| if (include_before) match.start else match.end else 0;
    const end: usize = if (after_match) |match| if (include_after) match.end else match.start else body.len;

    if (start > end) return error.InvalidPosition;

    return .{
        .span = .{ .start = start, .end = end },
        .single_match = (before_match == null or before_match.?.single_match) and (after_match == null or after_match.?.single_match),
    };
}
