const std = @import("std");

const ApplyError = error{
    InvalidJson,
    UnsupportedVersion,
    UnsupportedOperation,
    UnsupportedLanguage,
    UnsupportedTargetRange,
    MissingSymbol,
    MissingFile,
    MissingField,
    FieldTypeMismatch,
};

pub const ApplyTarget = struct {
    symbol: []const u8,
    kind: ?[]const u8 = null,
    range: ?[]const u8 = null,
    occurrence: ?usize = null,
};

pub const ApplyOptions = struct {
    dryRun: ?bool = null,
    route: ?[]const u8 = null,
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

pub const PhaseMetricsResult = struct {
    read: u64,
    parserInit: u64,
    parseBefore: u64,
    targetResolve: u64,
    plan: u64,
    parseAfter: u64,
    write: u64,
    total: u64,
};

pub const MetricsResult = struct {
    fileBytesBefore: usize,
    fileBytesAfter: usize,
    requestBytes: usize,
    changedBytesBefore: usize,
    changedBytesAfter: usize,
    wallMs: u64,
    phaseMs: PhaseMetricsResult,
};

pub const RouteExpected = struct {
    outputTokens: usize,
    toolArgTokens: usize,
    costUsd: f64,
    wallMs: u64,
};

pub const RouteThreshold = struct {
    minCostSavingsPct: f32,
    minWallSavingsPct: f32,
    maxRisk: f32,
};

pub const RouteRisk = struct {
    correctnessRisk: f32,
    unsupportedFormatRisk: f32,
    retryRisk: f32,
};

pub const defaultRouteExpected = RouteExpected{
    .outputTokens = 0,
    .toolArgTokens = 0,
    .costUsd = 0,
    .wallMs = 0,
};

pub const defaultRouteThreshold = RouteThreshold{
    .minCostSavingsPct = 5,
    .minWallSavingsPct = 10,
    .maxRisk = 0.15,
};

pub const RouteDecision = struct {
    route: []const u8,
    fallbackRoute: []const u8,
    confidence: f32,
    reasonCode: []const u8,
    expected: RouteExpected = defaultRouteExpected,
    threshold: RouteThreshold = defaultRouteThreshold,
    risk: RouteRisk,
};

pub const ApplyResult = struct {
    status: []const u8,
    command: []const u8 = "apply",
    operation: []const u8,
    route: []const u8,
    routeReasonCode: []const u8,
    routeDecision: RouteDecision,
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

pub const ApplyFailureResult = struct {
    status: []const u8,
    code: []const u8,
    command: []const u8 = "apply",
    operation: []const u8,
    route: []const u8,
    routeReasonCode: []const u8,
    routeDecision: RouteDecision,
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
    return ApplyError.UnsupportedOperation;
}

pub fn parseTargetRange(raw: ?[]const u8) !TargetRange {
    if (raw == null) return .body;
    const value = raw.?;
    if (std.mem.eql(u8, value, "body")) return .body;
    if (std.mem.eql(u8, value, "node")) return .node;
    return ApplyError.UnsupportedTargetRange;
}

pub fn parseRequest(root: std.json.Value) !ApplyRequest {
    const obj = try expectObject(root);
    if (obj.get("v") != null or obj.get("f") != null or obj.get("ops") != null) return parseCompactRequest(obj);
    var version: ?u8 = null;
    var file: ?[]const u8 = null;
    var operation: ?[]const u8 = null;
    var target: ?ApplyTarget = null;
    var edit: ?std.json.Value = null;
    var options: ?ApplyOptions = null;

    var it = obj.iterator();
    while (it.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "version")) {
            version = try parseVersionField(entry.value_ptr.*);
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "file")) {
            file = switch (entry.value_ptr.*) {
                .string => |value| value,
                else => return ApplyError.FieldTypeMismatch,
            };
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "operation")) {
            operation = switch (entry.value_ptr.*) {
                .string => |value| value,
                else => return ApplyError.FieldTypeMismatch,
            };
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "target")) {
            target = try parseTargetField(entry.value_ptr.*);
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "edit")) {
            edit = entry.value_ptr.*;
            continue;
        }
        if (std.mem.eql(u8, entry.key_ptr.*, "options")) {
            options = try parseOptionsField(entry.value_ptr.*);
            continue;
        }
        return ApplyError.FieldTypeMismatch;
    }

    if (version == null) return ApplyError.MissingField;
    if (version.? != 1) return ApplyError.UnsupportedVersion;
    if (file == null or operation == null or edit == null) return ApplyError.MissingField;

    return .{ .version = version.?, .file = file.?, .operation = operation.?, .target = target, .edit = edit.?, .options = options };
}

fn parseCompactRequest(obj: std.json.ObjectMap) !ApplyRequest {
    const version = if (obj.get("v")) |value| try parseVersionField(value) else return ApplyError.MissingField;
    if (version != 1) return ApplyError.UnsupportedVersion;
    const file = switch (obj.get("f") orelse return ApplyError.MissingField) {
        .string => |value| value,
        else => return ApplyError.FieldTypeMismatch,
    };
    const ops_value = obj.get("ops") orelse return ApplyError.MissingField;
    const ops = switch (ops_value) {
        .array => |arr| arr,
        else => return ApplyError.FieldTypeMismatch,
    };
    if (ops.items.len != 1) return ApplyError.UnsupportedOperation;
    return parseCompactOp(file, ops.items[0]);
}

fn parseCompactOp(file: []const u8, value: std.json.Value) !ApplyRequest {
    return switch (value) {
        .object => |op_obj| parseCompactObjectOp(file, op_obj),
        .array => |items| parseCompactTupleOp(file, items),
        else => ApplyError.FieldTypeMismatch,
    };
}

fn parseCompactObjectOp(file: []const u8, op_obj: std.json.ObjectMap) !ApplyRequest {
    const op_raw = try requireString(op_obj, "op");
    const operation = try normalizeCompactOperation(op_raw);
    const target_value = op_obj.get("t") orelse return ApplyError.MissingField;
    const target = try parseCompactTarget(target_value);
    const snippet = try requireString(op_obj, "s");
    return .{ .version = 1, .file = file, .operation = operation, .target = target, .edit = .{ .string = snippet }, .options = null };
}

fn parseCompactTupleOp(file: []const u8, items: std.json.Array) !ApplyRequest {
    if (items.items.len < 4) return ApplyError.MissingField;
    const op_raw = switch (items.items[0]) { .string => |v| v, else => return ApplyError.FieldTypeMismatch };
    const kind = switch (items.items[1]) { .string => |v| v, else => return ApplyError.FieldTypeMismatch };
    const name = switch (items.items[2]) { .string => |v| v, else => return ApplyError.FieldTypeMismatch };
    const snippet = switch (items.items[3]) { .string => |v| v, else => return ApplyError.FieldTypeMismatch };
    const occ: ?usize = if (items.items.len > 4) switch (items.items[4]) {
        .integer => |v| if (v < 0) return ApplyError.FieldTypeMismatch else @as(usize, @intCast(v)),
        else => return ApplyError.FieldTypeMismatch,
    } else null;
    const operation = try normalizeCompactOperation(op_raw);
    const target = ApplyTarget{ .symbol = name, .kind = kind, .occurrence = occ };
    return .{ .version = 1, .file = file, .operation = operation, .target = target, .edit = .{ .string = snippet }, .options = null };
}

fn normalizeCompactOperation(raw: []const u8) ![]const u8 {
    if (std.mem.eql(u8, raw, "rb") or std.mem.eql(u8, raw, "replace_body") or std.mem.eql(u8, raw, "set_body")) return "set_body";
    if (std.mem.eql(u8, raw, "ia") or std.mem.eql(u8, raw, "insert_after_symbol")) return "insert_after_symbol";
    if (std.mem.eql(u8, raw, "mn") or std.mem.eql(u8, raw, "merge_body_chunk")) return "merge_body_chunk";
    return ApplyError.UnsupportedOperation;
}

fn parseCompactTarget(value: std.json.Value) !ApplyTarget {
    const obj = try expectObject(value);
    if (obj.get("p") != null) return ApplyError.UnsupportedOperation;
    const kind = try requireOptionalString(obj, "k");
    const symbol = try requireString(obj, "n");
    const range = try requireOptionalString(obj, "range");
    const occurrence = try requireOptionalUsize(obj, "occ");
    return .{ .symbol = symbol, .kind = kind, .range = range, .occurrence = occurrence };
}

fn parseVersionField(value: std.json.Value) !u8 {
    return switch (value) {
        .integer => |v| if (v < 0 or v > std.math.maxInt(u8)) return ApplyError.FieldTypeMismatch else @as(u8, @intCast(v)),
        else => return ApplyError.FieldTypeMismatch,
    };
}

fn parseTargetField(value: std.json.Value) !ApplyTarget {
    const obj = try expectObject(value);
    return .{ .symbol = try requireString(obj, "symbol"), .kind = try requireOptionalString(obj, "kind"), .range = try requireOptionalString(obj, "range"), .occurrence = try requireOptionalUsize(obj, "occurrence") };
}

fn parseOptionsField(value: std.json.Value) !ApplyOptions {
    const obj = try expectObject(value);
    return .{ .dryRun = try requireOptionalBool(obj, "dryRun"), .route = try requireOptionalRoute(obj, "route"), .requireParseClean = try requireOptionalBool(obj, "requireParseClean"), .requireSingleMatch = try requireOptionalBool(obj, "requireSingleMatch"), .diffContext = try requireOptionalUsize(obj, "diffContext") };
}

fn requireOptionalRoute(object: std.json.ObjectMap, field: []const u8) !?[]const u8 {
    const value = try requireOptionalString(object, field) orelse return null;
    if (std.mem.eql(u8, value, "auto") or
        std.mem.eql(u8, value, "force-blitz") or
        std.mem.eql(u8, value, "force-core") or
        std.mem.eql(u8, value, "explain")) return value;
    return ApplyError.FieldTypeMismatch;
}

fn requireOptionalUsize(object: std.json.ObjectMap, field: []const u8) !?usize {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .integer => |v| if (v < 0) return ApplyError.FieldTypeMismatch else @as(usize, @intCast(v)),
        else => return ApplyError.FieldTypeMismatch,
    };
}

pub fn requireUsize(object: std.json.ObjectMap, field: []const u8) !usize {
    const value = object.get(field) orelse return ApplyError.MissingField;
    return switch (value) {
        .integer => |v| if (v < 0) return ApplyError.FieldTypeMismatch else @as(usize, @intCast(v)),
        else => return ApplyError.FieldTypeMismatch,
    };
}

pub fn requireOptionalString(object: std.json.ObjectMap, field: []const u8) !?[]const u8 {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .string => |str| str,
        else => return ApplyError.FieldTypeMismatch,
    };
}

pub fn requireOptionalBool(object: std.json.ObjectMap, field: []const u8) !?bool {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .bool => |v| v,
        else => return ApplyError.FieldTypeMismatch,
    };
}

pub fn requireArray(object: std.json.ObjectMap, field: []const u8) !std.json.Array {
    const value = object.get(field) orelse return ApplyError.MissingField;
    return switch (value) {
        .array => |arr| arr,
        else => return ApplyError.FieldTypeMismatch,
    };
}

pub fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |obj| obj,
        else => return ApplyError.FieldTypeMismatch,
    };
}
pub fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const value = object.get(field) orelse return ApplyError.MissingField;
    return switch (value) {
        .string => |str| str,
        else => return ApplyError.FieldTypeMismatch,
    };
}
