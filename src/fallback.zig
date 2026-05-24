//! Layer D — host-LLM scope payload emitter.
//!
//! When layers A, B, C all fail, emit a compact JSON single-line payload to stdout
//! with exit 0 so the host agent can apply the edit via its own tool using minimal
//! context. Payload shape documented in docs/blitz.md §7.3.
//!
//! Ticket: d1o-kjdk (shape frozen) + d1o-cewc (integrated into edit pipeline).

const std = @import("std");

/// Canonical host-merge payload for marker fallback.
pub const ScopePayload = struct {
    status: []const u8 = "needs_host_merge",
    file: []const u8,
    symbol: []const u8,
    kind: []const u8,
    byteStart: usize,
    byteEnd: usize,
    ancestorKind: ?[]const u8 = null,
    ancestorName: ?[]const u8 = null,
    siblingBefore: ?[]const u8 = null,
    siblingAfter: ?[]const u8 = null,
    excerpt: []const u8,
};

pub fn emitNeedsHostMerge(
    stdout: anytype,
    file: []const u8,
    symbol: []const u8,
    kind: []const u8,
    byte_start: usize,
    byte_end: usize,
    excerpt: []const u8,
) !void {
    const payload = ScopePayload{
        .file = file,
        .symbol = symbol,
        .kind = kind,
        .byteStart = byte_start,
        .byteEnd = byte_end,
        .excerpt = excerpt,
    };
    try stdout.print("{f}\n", .{std.json.fmt(payload, .{})});
}

test "fallback payload field count" {
    const p = ScopePayload{
        .file = "x",
        .symbol = "y",
        .kind = "function",
        .byteStart = 0,
        .byteEnd = 1,
        .excerpt = "",
    };
    _ = p;
}
