const std = @import("std");

pub const EDIT_TOOL_OVERHEAD_BYTES: usize = 32;

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
    core_equivalent_payload_bytes: usize,
    estimated_payload_saved_bytes: usize,
    estimated_payload_saved_pct: f64,
    estimated_tokens_saved_bytes_div4: usize,
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
        try intField(out, "coreEquivalentPayloadBytes", self.core_equivalent_payload_bytes);
        try intField(out, "estimatedPayloadSavedBytes", self.estimated_payload_saved_bytes);
        try out.print(",\"estimatedPayloadSavedPct\":{d:.2}", .{self.estimated_payload_saved_pct});
        try intField(out, "estimatedTokensSavedBytesDiv4", self.estimated_tokens_saved_bytes_div4);
        try out.print(",\"usedMarkers\":{}", .{self.used_markers});
        try intField(out, "wallMs", self.wall_ms);
        try out.writeAll("}\n");
    }
};

pub fn computePayload(
    symbol_bytes_before: usize,
    symbol_bytes_after: usize,
    snippet_bytes: usize,
    symbol_name_bytes: usize,
) struct {
    blitz_payload_bytes: usize,
    core_equivalent_payload_bytes: usize,
    estimated_payload_saved_bytes: usize,
    estimated_payload_saved_pct: f64,
    estimated_tokens_saved_bytes_div4: usize,
} {
    const blitz_payload = snippet_bytes + symbol_name_bytes + EDIT_TOOL_OVERHEAD_BYTES;
    const core_payload = symbol_bytes_before + symbol_bytes_after;
    const saved = if (core_payload > blitz_payload) core_payload - blitz_payload else 0;
    const pct = if (core_payload == 0) 0 else 100.0 * (1.0 - (@as(f64, @floatFromInt(blitz_payload)) / @as(f64, @floatFromInt(core_payload))));
    return .{
        .blitz_payload_bytes = blitz_payload,
        .core_equivalent_payload_bytes = core_payload,
        .estimated_payload_saved_bytes = saved,
        .estimated_payload_saved_pct = pct,
        .estimated_tokens_saved_bytes_div4 = (saved + 3) / 4,
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

test "computePayload estimates saved bytes" {
    const p = computePayload(1000, 1004, 91, 11);
    try std.testing.expectEqual(@as(usize, 134), p.blitz_payload_bytes);
    try std.testing.expectEqual(@as(usize, 2004), p.core_equivalent_payload_bytes);
    try std.testing.expectEqual(@as(usize, 1870), p.estimated_payload_saved_bytes);
    try std.testing.expectEqual(@as(usize, 468), p.estimated_tokens_saved_bytes_div4);
}
