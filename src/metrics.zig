const std = @import("std");

pub const EDIT_TOOL_OVERHEAD_BYTES: usize = 32;

pub const REALISTIC_CONTEXT_LINES: usize = 3;

pub const EditMetrics = struct {
    command: []const u8 = "edit",
    status: []const u8 = "applied",
    mode: []const u8,
    lane: []const u8,
    language: []const u8,
    file: []const u8,
    symbol: []const u8,
    file_bytes_before: usize,
    file_bytes_after: usize,
    symbol_bytes_before: usize,
    symbol_bytes_after: usize,
    snippet_bytes: usize,
    blitz_payload_bytes: usize,
    core_full_symbol_payload_bytes: usize,
    core_realistic_anchor_payload_bytes: usize,
    core_minimal_anchor_payload_bytes: usize,
    estimated_payload_saved_bytes_vs_full_symbol: usize,
    estimated_payload_saved_pct_vs_full_symbol: f64,
    estimated_payload_saved_bytes_vs_realistic_anchor: i64,
    estimated_payload_saved_pct_vs_realistic_anchor: f64,
    estimated_tokens_saved_bytes_div4_vs_realistic_anchor: i64,
    estimated_payload_saved_bytes_vs_minimal_anchor: i64,
    estimated_payload_saved_pct_vs_minimal_anchor: f64,
    estimated_tokens_saved_bytes_div4_vs_minimal_anchor: i64,
    realistic_context_lines: usize,
    used_markers: bool,
    wall_ms: u64,

    pub fn writeJson(self: EditMetrics, out: *std.Io.Writer) !void {
        try out.writeAll("{");
        try jsonField(out, "status", self.status, true);
        try jsonField(out, "command", self.command, false);
        try jsonField(out, "mode", self.mode, false);
        try jsonField(out, "lane", self.lane, false);
        try jsonField(out, "language", self.language, false);
        try jsonField(out, "file", self.file, false);
        try jsonField(out, "symbol", self.symbol, false);
        try intField(out, "fileBytesBefore", self.file_bytes_before);
        try intField(out, "fileBytesAfter", self.file_bytes_after);
        try intField(out, "symbolBytesBefore", self.symbol_bytes_before);
        try intField(out, "symbolBytesAfter", self.symbol_bytes_after);
        try intField(out, "snippetBytes", self.snippet_bytes);
        try intField(out, "blitzPayloadBytes", self.blitz_payload_bytes);
        try intField(out, "coreFullSymbolPayloadBytes", self.core_full_symbol_payload_bytes);
        try intField(out, "coreRealisticAnchorPayloadBytes", self.core_realistic_anchor_payload_bytes);
        try intField(out, "coreMinimalAnchorPayloadBytes", self.core_minimal_anchor_payload_bytes);
        try intField(out, "estimatedPayloadSavedBytesVsFullSymbol", self.estimated_payload_saved_bytes_vs_full_symbol);
        try out.print(",\"estimatedPayloadSavedPctVsFullSymbol\":{d:.2}", .{self.estimated_payload_saved_pct_vs_full_symbol});
        try out.print(",\"estimatedPayloadSavedBytesVsRealisticAnchor\":{d}", .{self.estimated_payload_saved_bytes_vs_realistic_anchor});
        try out.print(",\"estimatedPayloadSavedPctVsRealisticAnchor\":{d:.2}", .{self.estimated_payload_saved_pct_vs_realistic_anchor});
        try out.print(",\"estimatedTokensSavedBytesDiv4VsRealisticAnchor\":{d}", .{self.estimated_tokens_saved_bytes_div4_vs_realistic_anchor});
        try out.print(",\"estimatedPayloadSavedBytesVsMinimalAnchor\":{d}", .{self.estimated_payload_saved_bytes_vs_minimal_anchor});
        try out.print(",\"estimatedPayloadSavedPctVsMinimalAnchor\":{d:.2}", .{self.estimated_payload_saved_pct_vs_minimal_anchor});
        try out.print(",\"estimatedTokensSavedBytesDiv4VsMinimalAnchor\":{d}", .{self.estimated_tokens_saved_bytes_div4_vs_minimal_anchor});
        try intField(out, "realisticContextLines", self.realistic_context_lines);
        try out.print(",\"usedMarkers\":{}", .{self.used_markers});
        try intField(out, "wallMs", self.wall_ms);
        try out.writeAll("}\n");
    }
};

pub const PayloadEstimate = struct {
    blitz_payload_bytes: usize,
    core_full_symbol_payload_bytes: usize,
    core_realistic_anchor_payload_bytes: usize,
    core_minimal_anchor_payload_bytes: usize,
    saved_bytes_vs_full_symbol: usize,
    saved_pct_vs_full_symbol: f64,
    saved_bytes_vs_realistic_anchor: i64,
    saved_pct_vs_realistic_anchor: f64,
    tokens_saved_div4_vs_realistic_anchor: i64,
    saved_bytes_vs_minimal_anchor: i64,
    saved_pct_vs_minimal_anchor: f64,
    tokens_saved_div4_vs_minimal_anchor: i64,
};

pub fn computePayloadEstimate(
    symbol_bytes_before: usize,
    symbol_bytes_after: usize,
    snippet_bytes: usize,
    symbol_name_bytes: usize,
    minimal_old_anchor_bytes: usize,
    minimal_new_anchor_bytes: usize,
    realistic_old_anchor_bytes: usize,
    realistic_new_anchor_bytes: usize,
) PayloadEstimate {
    const blitz_payload = snippet_bytes + symbol_name_bytes + EDIT_TOOL_OVERHEAD_BYTES;
    const core_full = symbol_bytes_before + symbol_bytes_after;
    const core_min = minimal_old_anchor_bytes + minimal_new_anchor_bytes;
    const core_realistic = realistic_old_anchor_bytes + realistic_new_anchor_bytes;

    const saved_full = if (core_full > blitz_payload) core_full - blitz_payload else 0;
    const pct_full = if (core_full == 0) 0 else 100.0 * (1.0 - (@as(f64, @floatFromInt(blitz_payload)) / @as(f64, @floatFromInt(core_full))));

    const blitz_i: i64 = @intCast(blitz_payload);
    const core_min_i: i64 = @intCast(core_min);
    const saved_min: i64 = core_min_i - blitz_i;
    const pct_min = if (core_min == 0) 0 else 100.0 * (1.0 - (@as(f64, @floatFromInt(blitz_payload)) / @as(f64, @floatFromInt(core_min))));

    const core_real_i: i64 = @intCast(core_realistic);
    const saved_real: i64 = core_real_i - blitz_i;
    const pct_real = if (core_realistic == 0) 0 else 100.0 * (1.0 - (@as(f64, @floatFromInt(blitz_payload)) / @as(f64, @floatFromInt(core_realistic))));
    const tokens_real: i64 = @divTrunc(saved_real, 4);
    const tokens_min: i64 = @divTrunc(saved_min, 4);

    return .{
        .blitz_payload_bytes = blitz_payload,
        .core_full_symbol_payload_bytes = core_full,
        .core_realistic_anchor_payload_bytes = core_realistic,
        .core_minimal_anchor_payload_bytes = core_min,
        .saved_bytes_vs_full_symbol = saved_full,
        .saved_pct_vs_full_symbol = pct_full,
        .saved_bytes_vs_realistic_anchor = saved_real,
        .saved_pct_vs_realistic_anchor = pct_real,
        .tokens_saved_div4_vs_realistic_anchor = tokens_real,
        .saved_bytes_vs_minimal_anchor = saved_min,
        .saved_pct_vs_minimal_anchor = pct_min,
        .tokens_saved_div4_vs_minimal_anchor = tokens_min,
    };
}

pub const RealisticAnchor = struct {
    old_bytes: usize,
    new_bytes: usize,
    context_lines: usize,
};

pub fn computeRealisticAnchor(before: []const u8, after: []const u8, context_lines: usize) RealisticAnchor {
    var prefix: usize = 0;
    const min_len = @min(before.len, after.len);
    while (prefix < min_len and before[prefix] == after[prefix]) : (prefix += 1) {}
    var before_end = before.len;
    var after_end = after.len;
    while (before_end > prefix and after_end > prefix and before[before_end - 1] == after[after_end - 1]) {
        before_end -= 1;
        after_end -= 1;
    }

    const old_start_line = lineStartAtOrBefore(before, prefix);
    const old_end_line = lineEndAtOrAfter(before, before_end);
    const new_start_line = lineStartAtOrBefore(after, prefix);
    const new_end_line = lineEndAtOrAfter(after, after_end);

    const old_start = expandUpLines(before, old_start_line, context_lines);
    const old_end = expandDownLines(before, old_end_line, context_lines);
    const new_start = expandUpLines(after, new_start_line, context_lines);
    const new_end = expandDownLines(after, new_end_line, context_lines);

    return .{
        .old_bytes = old_end - old_start,
        .new_bytes = new_end - new_start,
        .context_lines = context_lines,
    };
}

fn lineStartAtOrBefore(buf: []const u8, byte: usize) usize {
    var i = @min(byte, buf.len);
    while (i > 0 and buf[i - 1] != '\n') : (i -= 1) {}
    return i;
}

fn lineEndAtOrAfter(buf: []const u8, byte: usize) usize {
    var i = @min(byte, buf.len);
    while (i < buf.len and buf[i] != '\n') : (i += 1) {}
    if (i < buf.len) i += 1;
    return i;
}

fn expandUpLines(buf: []const u8, start: usize, lines: usize) usize {
    var i = start;
    var n: usize = 0;
    while (n < lines and i > 0) {
        i -= 1;
        if (i > 0) i = lineStartAtOrBefore(buf, i);
        n += 1;
    }
    return i;
}

fn expandDownLines(buf: []const u8, end: usize, lines: usize) usize {
    var i = end;
    var n: usize = 0;
    while (n < lines and i < buf.len) {
        i = lineEndAtOrAfter(buf, i + 1);
        n += 1;
    }
    return i;
}

pub const MinimalAnchor = struct {
    old_bytes: usize,
    new_bytes: usize,
};

pub fn computeMinimalAnchor(before: []const u8, after: []const u8) MinimalAnchor {
    var prefix: usize = 0;
    const min_len = @min(before.len, after.len);
    while (prefix < min_len and before[prefix] == after[prefix]) : (prefix += 1) {}
    var before_end = before.len;
    var after_end = after.len;
    while (before_end > prefix and after_end > prefix and before[before_end - 1] == after[after_end - 1]) {
        before_end -= 1;
        after_end -= 1;
    }
    return .{
        .old_bytes = before_end - prefix,
        .new_bytes = after_end - prefix,
    };
}

fn jsonField(out: *std.Io.Writer, name: []const u8, value: []const u8, first: bool) !void {
    if (!first) try out.writeByte(',');
    try out.print("\"{s}\":", .{name});
    try writeJsonString(out, value);
}

fn intField(out: *std.Io.Writer, name: []const u8, value: usize) !void {
    try out.print(",\"{s}\":{d}", .{ name, value });
}

fn writeJsonString(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('"');
    for (value) |ch| switch (ch) {
        '"' => try out.writeAll("\\\""),
        '\\' => try out.writeAll("\\\\"),
        '\n' => try out.writeAll("\\n"),
        '\r' => try out.writeAll("\\r"),
        '\t' => try out.writeAll("\\t"),
        else => if (ch < 0x20) try out.print("\\u{x:0>4}", .{ch}) else try out.writeByte(ch),
    };
    try out.writeByte('"');
}

test "computeMinimalAnchor returns changed window byte counts" {
    const before = "function f() {\n  return total;\n}\n";
    const after = "function f() {\n  return total + 1;\n}\n";
    const a = computeMinimalAnchor(before, after);
    try std.testing.expectEqual(@as(usize, 0), a.old_bytes);
    try std.testing.expectEqual(@as(usize, 4), a.new_bytes);
}

test "computeMinimalAnchor counts replacement of mid-line slice" {
    const before = "let x = 1;\n";
    const after = "let x = 2;\n";
    const a = computeMinimalAnchor(before, after);
    try std.testing.expectEqual(@as(usize, 1), a.old_bytes);
    try std.testing.expectEqual(@as(usize, 1), a.new_bytes);
}

test "computePayloadEstimate exposes three baselines" {
    const p = computePayloadEstimate(1000, 1004, 91, 11, 1, 5, 200, 220);
    try std.testing.expectEqual(@as(usize, 134), p.blitz_payload_bytes);
    try std.testing.expectEqual(@as(usize, 2004), p.core_full_symbol_payload_bytes);
    try std.testing.expectEqual(@as(usize, 420), p.core_realistic_anchor_payload_bytes);
    try std.testing.expectEqual(@as(usize, 6), p.core_minimal_anchor_payload_bytes);
    try std.testing.expect(p.saved_pct_vs_realistic_anchor > 0);
    try std.testing.expect(p.saved_pct_vs_minimal_anchor < 0);
}

test "computeRealisticAnchor expands changed window with N context lines" {
    const before = "a\nb\nlet x = 1;\nc\nd\n";
    const after = "a\nb\nlet x = 2;\nc\nd\n";
    const ra = computeRealisticAnchor(before, after, 3);
    try std.testing.expectEqual(@as(usize, 3), ra.context_lines);
    try std.testing.expect(ra.old_bytes >= 14);
    try std.testing.expectEqual(ra.old_bytes, ra.new_bytes);
}
