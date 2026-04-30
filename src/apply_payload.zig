const std = @import("std");

pub const MAX_SOURCE_BYTES = 32 * 1024 * 1024;

pub const ApplyOperation = enum {
    replace_body_span,
    insert_body_span,
    wrap_body,
    multi_body,
    compose_body,
    insert_after_symbol,
    set_body,
    patch,
};

pub const TargetRange = enum { body, node };

pub const MatchKind = enum { default_single, first, last, only, index };

pub const MatchSelector = struct {
    kind: MatchKind,
    index: usize = 0,
};

pub const ApplyTarget = struct {
    /// Kept for single-target structured edits.
    symbol: []const u8,
    kind: ?[]const u8 = null,
    range: ?[]const u8 = null,
};

pub const ApplyOptions = struct {
    dryRun: ?bool = null,
    requireParseClean: ?bool = null,
    requireSingleMatch: ?bool = null,
    diffContext: ?usize = null,
};

pub const ApplyRequest = struct {
    version: u8,
    file: []const u8,
    operation: []const u8,
    target: ?ApplyTarget = null,
    edit: std.json.Value,
    options: ?ApplyOptions = null,
};

pub const ValidationResult = struct {
    parseBeforeClean: bool,
    parseAfterClean: bool,
    singleMatch: bool,
    rejectedReason: ?[]const u8 = null,
};

pub const RangesResult = struct {
    targetStart: usize,
    targetEnd: usize,
    bodyStart: ?usize = null,
    bodyEnd: ?usize = null,
    editStart: usize,
    editEnd: usize,
};

pub const MetricsResult = struct {
    fileBytesBefore: usize,
    fileBytesAfter: usize,
    requestBytes: usize,
    changedBytesBefore: usize,
    changedBytesAfter: usize,
    wallMs: u64,
};

pub const ApplyResult = struct {
    status: []const u8,
    command: []const u8 = "apply",
    operation: []const u8,
    file: []const u8,
    symbol: []const u8,
    language: []const u8,
    dryRun: bool,
    changed: bool,
    validation: ValidationResult,
    ranges: RangesResult,
    metrics: MetricsResult,
    diffSummary: []const u8,
    diff: ?[]const u8 = null,
};

pub const MatchSpan = struct {
    start: usize,
    end: usize,
    single_match: bool,
    total: usize,
};

pub const OpResult = struct {
    contents: []u8,
    range: RangesResult,
    single_match: bool,
    changed_before: usize,
    changed_after: usize,
};

pub const MultiEdit = struct {
    start: usize,
    end: usize,
    replacement: []const u8,
    replacement_owned: bool,
    range: RangesResult,
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

pub const EditSpan = struct { start: usize, end: usize };

pub const ApplyError = error{
    InvalidJson,
    UnsupportedVersion,
    UnsupportedOperation,
    UnsupportedLanguage,
    UnsupportedTargetRange,
    MissingSymbol,
    MissingFile,
    MissingField,
    FieldTypeMismatch,
    InvalidOccurrence,
    InvalidPosition,
    PatternEmpty,
    SymbolNotFound,
    NoMatches,
    AmbiguousMatches,
    OverlappingEdits,
    UnsupportedMultiEditOperation,
    ParseFailedBefore,
    ParseFailedAfter,
};

test "apply payload type defaults" {
    const options = ApplyOptions{};
    try std.testing.expectEqual(@as(?bool, null), options.dryRun);
    try std.testing.expectEqual(@as(?usize, null), options.diffContext);

    const selector = MatchSelector{ .kind = .default_single };
    try std.testing.expectEqual(@as(usize, 0), selector.index);
}
