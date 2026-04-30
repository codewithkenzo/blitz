const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");
const apply_payload = @import("apply_payload.zig");

const Allocator = std.mem.Allocator;
const ApplyResult = apply_payload.ApplyResult;
const OpResult = apply_payload.OpResult;

pub fn statusLabel(dry_run: bool, changed: bool) []const u8 {
    return if (dry_run) "preview" else if (changed) "applied" else "no_changes";
}

pub fn diffSummary(allocator: Allocator, op_result: OpResult, changed: bool) ![]u8 {
    return if (changed)
        try std.fmt.allocPrint(allocator, "+{d} -{d}", .{ op_result.changed_after, op_result.changed_before })
    else
        try allocator.dupe(u8, "no changes");
}

pub fn languageName(lang: bindings.Language) []const u8 {
    return switch (lang) {
        .rust => "rust",
        .typescript => "typescript",
        .tsx => "tsx",
        .python => "python",
        .go => "go",
    };
}

pub fn buildResult(
    status: []const u8,
    operation: []const u8,
    file: []const u8,
    symbol: []const u8,
    lang: bindings.Language,
    dry_run: bool,
    changed: bool,
    parse_after: bool,
    op_result: OpResult,
    original_len: usize,
    request_len: usize,
    wall_ms: u64,
    diff_summary: []const u8,
    diff_requested: bool,
) ApplyResult {
    return ApplyResult{
        .status = status,
        .operation = operation,
        .file = file,
        .symbol = symbol,
        .language = languageName(lang),
        .dryRun = dry_run,
        .changed = changed,
        .validation = .{ .parseBeforeClean = true, .parseAfterClean = parse_after, .singleMatch = op_result.single_match },
        .ranges = op_result.range,
        .metrics = .{
            .fileBytesBefore = original_len,
            .fileBytesAfter = op_result.contents.len,
            .requestBytes = request_len,
            .changedBytesBefore = op_result.changed_before,
            .changedBytesAfter = op_result.changed_after,
            .wallMs = @intCast(wall_ms),
        },
        .diffSummary = diff_summary,
        .diff = if (diff_requested and changed) diff_summary else null,
    };
}

test "apply metrics labels" {
    try std.testing.expectEqualStrings("preview", statusLabel(true, false));
    try std.testing.expectEqualStrings("applied", statusLabel(false, true));
    try std.testing.expectEqualStrings("no_changes", statusLabel(false, false));
}
