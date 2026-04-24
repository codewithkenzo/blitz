//! Per-canonical-path advisory lock (fcntl-based on Unix, LockFile on Windows).
//!
//! Multi-file tools sort canonical paths and acquire in sorted order to avoid deadlocks.
//! Ticket: d1o-cewc. Placeholder module.

const std = @import("std");

pub const LockError = error{
    LockContended,
    LockInvalidPath,
};

test "lock module placeholder" {
    _ = LockError;
}
