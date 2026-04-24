//! SHA256-keyed per-file backup store + atomic write.
//!
//! Key = sha256(realpath + "\0" + pre_edit_mtime_ns).
//! Location = ${XDG_CACHE_HOME:-~/.cache}/blitz/backup/<hex-key>.bak
//!
//! Single-depth undo per path. Ticket: d1o-cewc. Placeholder module.

const std = @import("std");

pub const BackupError = error{
    NoBackup,
    AtomicWriteFailed,
    KeyCollision,
};

test "backup module placeholder" {
    _ = BackupError;
}
