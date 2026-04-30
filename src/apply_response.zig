const std = @import("std");
const apply_payload = @import("apply_payload.zig");

const Writer = std.Io.Writer;
const ApplyRequest = apply_payload.ApplyRequest;
const ApplyResult = apply_payload.ApplyResult;
const ApplyError = apply_payload.ApplyError;

pub fn errorReason(err: anyerror) []const u8 {
    return switch (err) {
        ApplyError.InvalidJson => "invalid JSON request",
        ApplyError.UnsupportedVersion => "unsupported request version",
        ApplyError.UnsupportedOperation => "unsupported operation",
        ApplyError.UnsupportedLanguage => "unsupported language",
        ApplyError.UnsupportedTargetRange => "unsupported target range",
        ApplyError.MissingSymbol => "missing target symbol",
        ApplyError.MissingFile => "missing file",
        ApplyError.MissingField => "missing required edit field",
        ApplyError.FieldTypeMismatch => "invalid edit field type",
        ApplyError.InvalidOccurrence => "invalid occurrence value",
        ApplyError.InvalidPosition => "invalid position value",
        ApplyError.PatternEmpty => "pattern is empty",
        ApplyError.SymbolNotFound => "symbol not found",
        ApplyError.NoMatches => "no matching pattern",
        ApplyError.AmbiguousMatches => "ambiguous pattern match",
        ApplyError.OverlappingEdits => "overlapping edits",
        ApplyError.UnsupportedMultiEditOperation => "unsupported multi-body operation (compose_body TODO)",
        ApplyError.ParseFailedBefore => "source did not parse before edit",
        ApplyError.ParseFailedAfter => "edited source did not parse",
        else => "apply failed",
    };
}

pub fn emitSuccess(
    result: ApplyResult,
    json_output: bool,
    changed: bool,
    dry_run: bool,
    user_file: []const u8,
    status: []const u8,
    stdout: *Writer,
) !u8 {
    if (!json_output) {
        if (changed and !dry_run) try stdout.print("Applied {s}: {s}\n", .{ user_file, status }) else try stdout.print("No changes for {s}: {s}\n", .{ user_file, status });
        return 0;
    }

    try stdout.print("{f}\n", .{std.json.fmt(result, .{})});
    return 0;
}

pub fn emitFailure(
    err: anyerror,
    request: ?ApplyRequest,
    request_bytes: []const u8,
    json_output: bool,
    stdout: *Writer,
    stderr: *Writer,
    parse_before: bool,
    parse_after: bool,
    request_bytes_len: usize,
) !u8 {
    const reason = errorReason(err);

    if (!json_output) {
        try stderr.print("blitz apply: {s}\n", .{reason});
        return 1;
    }

    const operation = if (request) |r| r.operation else "";
    const file = if (request) |r| r.file else "";
    const symbol = if (request) |r| if (r.target) |target| target.symbol else "" else "";
    const probe = ApplyResult{
        .status = "rejected",
        .operation = operation,
        .file = file,
        .symbol = symbol,
        .language = "",
        .dryRun = false,
        .changed = false,
        .validation = .{ .parseBeforeClean = parse_before, .parseAfterClean = parse_after, .singleMatch = false, .rejectedReason = reason },
        .ranges = .{ .targetStart = 0, .targetEnd = 0, .editStart = 0, .editEnd = 0 },
        .metrics = .{ .fileBytesBefore = request_bytes_len, .fileBytesAfter = 0, .requestBytes = request_bytes.len, .changedBytesBefore = 0, .changedBytesAfter = 0, .wallMs = 0 },
        .diffSummary = reason,
    };
    try stdout.print("{f}\n", .{std.json.fmt(probe, .{})});
    return 1;
}

test "apply error reason mapping" {
    try std.testing.expectEqualStrings("invalid JSON request", errorReason(ApplyError.InvalidJson));
    try std.testing.expectEqualStrings("unsupported operation", errorReason(ApplyError.UnsupportedOperation));
    try std.testing.expectEqualStrings("edited source did not parse", errorReason(ApplyError.ParseFailedAfter));
}
