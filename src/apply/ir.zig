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

pub const ApplyFailureResult = struct {
    status: []const u8,
    code: []const u8,
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

pub fn parseOperation(raw: []const u8) !ApplyOperation {
    if (std.mem.eql(u8, raw, "replace_body_span")) return .replace_body_span;
    if (std.mem.eql(u8, raw, "insert_body_span")) return .insert_body_span;
    if (std.mem.eql(u8, raw, "wrap_body")) return .wrap_body;
    if (std.mem.eql(u8, raw, "multi_body")) return .multi_body;
    if (std.mem.eql(u8, raw, "compose_body")) return .compose_body;
    if (std.mem.eql(u8, raw, "insert_after_symbol")) return .insert_after_symbol;
    if (std.mem.eql(u8, raw, "set_body")) return .set_body;
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

fn parseVersionField(value: std.json.Value) !u8 {
    return switch (value) {
        .integer => |v| if (v < 0 or v > std.math.maxInt(u8)) return ApplyError.FieldTypeMismatch else @as(u8, @intCast(v)),
        else => return ApplyError.FieldTypeMismatch,
    };
}

fn parseTargetField(value: std.json.Value) !ApplyTarget {
    const obj = try expectObject(value);
    return .{ .symbol = try requireString(obj, "symbol"), .kind = try requireOptionalString(obj, "kind"), .range = try requireOptionalString(obj, "range") };
}

fn parseOptionsField(value: std.json.Value) !ApplyOptions {
    const obj = try expectObject(value);
    return .{ .dryRun = try requireOptionalBool(obj, "dryRun"), .requireParseClean = try requireOptionalBool(obj, "requireParseClean"), .requireSingleMatch = try requireOptionalBool(obj, "requireSingleMatch"), .diffContext = try requireOptionalUsize(obj, "diffContext") };
}

fn requireOptionalUsize(object: std.json.ObjectMap, field: []const u8) !?usize {
    const value = object.get(field) orelse return null;
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

fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |obj| obj,
        else => return ApplyError.FieldTypeMismatch,
    };
}
fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    return (object.get(field) orelse return ApplyError.MissingField).string;
}
