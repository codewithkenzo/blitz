//! Layer D — host-LLM scope payload emitter.
//!
//! When layers A, B, C all fail, emit a compact JSON single-line payload to stdout
//! with exit 0 so the host agent can apply the edit via its own tool using minimal
//! context. Payload shape documented in docs/blitz.md §7.3.
//!
//! Ticket: d1o-kjdk (shape frozen) + d1o-cewc (integrated into edit pipeline).

const std = @import("std");

/// Wire JSON keys are camelCase per spec §7.3 (host agents read these over stdout).
/// Zig struct fields stay snake_case to follow Zig style; the serializer maps them.
pub const ScopePayload = struct {
    status: []const u8 = "needs_host_merge",
    file: []const u8,
    symbol: []const u8,
    kind: []const u8,
    byte_start: usize, // serialized as "byteStart"
    byte_end: usize, // serialized as "byteEnd"
    ancestor_kind: ?[]const u8 = null, // serialized as "ancestorKind"
    ancestor_name: ?[]const u8 = null, // serialized as "ancestorName"
    sibling_before: ?[]const u8 = null, // serialized as "siblingBefore"
    sibling_after: ?[]const u8 = null, // serialized as "siblingAfter"
    excerpt: []const u8,
};

/// Canonical JSON-key names per spec §7.3. Must match what `@codewithkenzo/pi-blitz`
/// classifies as `{ status: "needs_host_merge" }` and what the host agent reads.
pub const wire_keys = .{
    .status = "status",
    .file = "file",
    .symbol = "symbol",
    .kind = "kind",
    .byte_start = "byteStart",
    .byte_end = "byteEnd",
    .ancestor_kind = "ancestorKind",
    .ancestor_name = "ancestorName",
    .sibling_before = "siblingBefore",
    .sibling_after = "siblingAfter",
    .excerpt = "excerpt",
};

test "fallback payload field count" {
    const p = ScopePayload{
        .file = "x",
        .symbol = "y",
        .kind = "function",
        .byte_start = 0,
        .byte_end = 1,
        .excerpt = "",
    };
    _ = p;
}

test "wire keys are camelCase for host consumption" {
    try std.testing.expectEqualStrings("byteStart", wire_keys.byte_start);
    try std.testing.expectEqualStrings("ancestorKind", wire_keys.ancestor_kind);
    try std.testing.expectEqualStrings("siblingAfter", wire_keys.sibling_after);
}
