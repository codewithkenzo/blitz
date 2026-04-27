//! CLI helpers for blitz: help text + doctor report.
//!
//! Accepts a generic `*std.Io.Writer` so tests can use `Writer.Allocating`
//! without touching stdout.

const std = @import("std");
const Writer = std.Io.Writer;

pub fn printHelp(w: *Writer) Writer.Error!void {
    try w.writeAll(
        \\blitz — AST-aware fast-edit CLI
        \\
        \\USAGE:
        \\    blitz <command> [args]
        \\
        \\COMMANDS:
        \\    read <file>                                 Show AST structure summary
        \\    edit <file> --snippet - --after|--replace <symbol>
        \\                                                Apply symbol-anchored edit
        \\    batch-edit <file> --edits -                 Multi-hunk edit from JSON stdin
        \\    rename <file> <old> <new> [--dry-run]       AST-verified rename in one file
        \\    undo <file>                                 Revert last backup
        \\    apply --edit - [--json]                     Structured JSON edit IR
        \\    doctor                                      Report version + supported grammars
        \\    --version                                   Print version
        \\    --help                                      Print this help
        \\
        \\EXAMPLES:
        \\    blitz read src/app.ts
        \\    blitz edit src/app.ts --replace handleRequest --snippet -
        \\    blitz rename src/app.ts oldName newName
        \\    blitz undo src/app.ts
        \\
        \\See https://github.com/codewithkenzo/blitz for status.
        \\
    );
}

pub fn runDoctor(w: *Writer) Writer.Error!void {
    try w.writeAll(
        \\blitz doctor
        \\  version:     0.1.0-alpha.0
        \\  stage:       v0.1 alpha
        \\  tree-sitter: linked
        \\  commands:    read, edit, batch-edit, rename, undo, apply, doctor
        \\
    );
}

test "printHelp writes non-empty" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try printHelp(&aw.writer);
    try std.testing.expect(aw.written().len > 0);
}

test "runDoctor writes non-empty" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try runDoctor(&aw.writer);
    try std.testing.expect(aw.written().len > 0);
}
