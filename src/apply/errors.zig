const std = @import("std");

pub fn status(err: anyerror) []const u8 {
    return if (std.mem.eql(u8, @errorName(err), "NeedsHostMerge")) "needs_host_merge" else "rejected";
}

pub fn code(err: anyerror) []const u8 {
    const name = @errorName(err);

    if (std.mem.eql(u8, name, "InvalidJson")) return "INVALID_JSON";
    if (std.mem.eql(u8, name, "UnsupportedVersion")) return "UNSUPPORTED_SCHEMA_VERSION";
    if (std.mem.eql(u8, name, "UnsupportedOperation")) return "UNSUPPORTED_OPERATION";
    if (std.mem.eql(u8, name, "UnsupportedLanguage")) return "UNSUPPORTED_LANGUAGE";
    if (std.mem.eql(u8, name, "UnsupportedTargetRange")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "UnsupportedTargetKind")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "MissingSymbol")) return "MISSING_FIELD";
    if (std.mem.eql(u8, name, "MissingFile")) return "MISSING_FIELD";
    if (std.mem.eql(u8, name, "MissingField")) return "MISSING_FIELD";
    if (std.mem.eql(u8, name, "FieldTypeMismatch")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "InvalidOccurrence")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "InvalidPosition")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "PatternEmpty")) return "INVALID_FIELD";
    if (std.mem.eql(u8, name, "SymbolNotFound")) return "SYMBOL_NOT_FOUND";
    if (std.mem.eql(u8, name, "AmbiguousSymbol")) return "SYMBOL_AMBIGUOUS";
    if (std.mem.eql(u8, name, "SymbolAmbiguous")) return "SYMBOL_AMBIGUOUS";
    if (std.mem.eql(u8, name, "NoMatches")) return "NO_MATCH";
    if (std.mem.eql(u8, name, "AmbiguousMatches")) return "AMBIGUOUS_MATCH";
    if (std.mem.eql(u8, name, "OverlappingEdits")) return "OVERLAPPING_EDITS";
    if (std.mem.eql(u8, name, "HashMismatch")) return "HASH_MISMATCH";
    if (std.mem.eql(u8, name, "UnsupportedMultiEditOperation")) return "UNSUPPORTED_OPERATION";
    if (std.mem.eql(u8, name, "ParseFailedBefore")) return "PARSE_ERROR_BEFORE";
    if (std.mem.eql(u8, name, "ParseFailedAfter")) return "PARSE_ERROR_AFTER";
    if (std.mem.eql(u8, name, "BodyNotFound")) return "BODY_NOT_FOUND";
    if (std.mem.eql(u8, name, "ValidationFailed")) return "VALIDATION_FAILED";
    if (std.mem.eql(u8, name, "BackupFailed")) return "BACKUP_FAILED";
    if (std.mem.eql(u8, name, "IoError")) return "IO_ERROR";
    if (std.mem.eql(u8, name, "NeedsHostMerge")) return "NEEDS_HOST_MERGE";
    if (std.mem.eql(u8, name, "PathEscapesWorkspace")) return "OUTSIDE_WORKSPACE";
    if (std.mem.eql(u8, name, "FileNotFound")) return "FILE_NOT_FOUND";
    if (std.mem.eql(u8, name, "NoBackup")) return "BACKUP_FAILED";
    if (std.mem.eql(u8, name, "AtomicWriteFailed")) return "BACKUP_FAILED";
    if (std.mem.eql(u8, name, "KeyCollision")) return "BACKUP_FAILED";
    if (std.mem.eql(u8, name, "CacheDirUnavailable")) return "BACKUP_FAILED";
    if (std.mem.eql(u8, name, "LockContended")) return "IO_ERROR";
    if (std.mem.eql(u8, name, "LockInvalidPath")) return "IO_ERROR";
    if (std.mem.eql(u8, name, "OutOfMemory")) return "IO_ERROR";

    return "IO_ERROR";
}

pub fn reason(err: anyerror) []const u8 {
    const name = @errorName(err);

    if (std.mem.eql(u8, name, "InvalidJson")) return "invalid JSON request";
    if (std.mem.eql(u8, name, "UnsupportedVersion")) return "unsupported request version";
    if (std.mem.eql(u8, name, "UnsupportedOperation")) return "unsupported operation";
    if (std.mem.eql(u8, name, "UnsupportedLanguage")) return "unsupported language";
    if (std.mem.eql(u8, name, "UnsupportedTargetRange")) return "invalid target range";
    if (std.mem.eql(u8, name, "UnsupportedTargetKind")) return "unsupported target kind";
    if (std.mem.eql(u8, name, "MissingSymbol")) return "missing target symbol";
    if (std.mem.eql(u8, name, "MissingFile")) return "missing file";
    if (std.mem.eql(u8, name, "MissingField")) return "missing required field";
    if (std.mem.eql(u8, name, "FieldTypeMismatch")) return "invalid field type";
    if (std.mem.eql(u8, name, "InvalidOccurrence")) return "invalid occurrence value";
    if (std.mem.eql(u8, name, "InvalidPosition")) return "invalid position value";
    if (std.mem.eql(u8, name, "PatternEmpty")) return "pattern is empty";
    if (std.mem.eql(u8, name, "SymbolNotFound")) return "symbol not found";
    if (std.mem.eql(u8, name, "AmbiguousSymbol")) return "symbol ambiguous";
    if (std.mem.eql(u8, name, "SymbolAmbiguous")) return "symbol ambiguous";
    if (std.mem.eql(u8, name, "NoMatches")) return "no matching pattern";
    if (std.mem.eql(u8, name, "AmbiguousMatches")) return "ambiguous pattern match";
    if (std.mem.eql(u8, name, "OverlappingEdits")) return "overlapping edits";
    if (std.mem.eql(u8, name, "HashMismatch")) return "guard range text mismatch";
    if (std.mem.eql(u8, name, "UnsupportedMultiEditOperation")) return "unsupported multi-body operation";
    if (std.mem.eql(u8, name, "ParseFailedBefore")) return "source did not parse before edit";
    if (std.mem.eql(u8, name, "ParseFailedAfter")) return "edited source did not parse";
    if (std.mem.eql(u8, name, "BodyNotFound")) return "body not found";
    if (std.mem.eql(u8, name, "ValidationFailed")) return "validation failed";
    if (std.mem.eql(u8, name, "BackupFailed")) return "backup failed";
    if (std.mem.eql(u8, name, "IoError")) return "I/O error";
    if (std.mem.eql(u8, name, "NeedsHostMerge")) return "needs host merge";
    if (std.mem.eql(u8, name, "PathEscapesWorkspace")) return "path escapes workspace";
    if (std.mem.eql(u8, name, "FileNotFound")) return "file not found";
    if (std.mem.eql(u8, name, "NoBackup")) return "backup failed";
    if (std.mem.eql(u8, name, "AtomicWriteFailed")) return "backup failed";
    if (std.mem.eql(u8, name, "KeyCollision")) return "backup failed";
    if (std.mem.eql(u8, name, "CacheDirUnavailable")) return "backup failed";
    if (std.mem.eql(u8, name, "LockContended")) return "lock contended";
    if (std.mem.eql(u8, name, "LockInvalidPath")) return "invalid lock path";
    if (std.mem.eql(u8, name, "OutOfMemory")) return "out of memory";

    return "apply failed";
}

test "hash mismatch maps to stable code" {
    try std.testing.expectEqualStrings("HASH_MISMATCH", code(error.HashMismatch));
}
