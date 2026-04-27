const std = @import("std");

const ast = @import("ast.zig");
const backup = @import("backup.zig");
const cli = @import("cli.zig");
const cmd_batch = @import("cmd_batch.zig");
const cmd_doctor = @import("cmd_doctor.zig");
const cmd_edit = @import("cmd_edit.zig");
const cmd_apply = @import("cmd_apply.zig");
const cmd_read = @import("cmd_read.zig");
const cmd_rename = @import("cmd_rename.zig");
const cmd_undo = @import("cmd_undo.zig");
const edit_support = @import("edit_support.zig");
const fallback = @import("fallback.zig");
const incremental = @import("incremental.zig");
const lock = @import("lock.zig");
const main = @import("main.zig");
const metrics = @import("metrics.zig");
const splice = @import("splice.zig");
const symbols = @import("symbols.zig");
const workspace = @import("workspace.zig");
const bindings = @import("tree_sitter/bindings.zig");

test "import module tests" {
    _ = ast;
    _ = backup;
    _ = cli;
    _ = cmd_batch;
    _ = cmd_doctor;
    _ = cmd_edit;
    _ = cmd_apply;
    _ = cmd_read;
    _ = cmd_rename;
    _ = cmd_undo;
    _ = edit_support;
    _ = fallback;
    _ = incremental;
    _ = lock;
    _ = main;
    _ = metrics;
    _ = splice;
    _ = symbols;
    _ = workspace;
    _ = bindings;
    try std.testing.expect(true);
}
