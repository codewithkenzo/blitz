//! blitz — AST-aware fast-edit CLI.
//!
//! Entry point using Zig 0.16's "Juicy Main" (std.process.Init), which
//! provides gpa, arena, io, environ, and args via init.minimal.
//!
//! Ticket d1o-qphx lands tree-sitter static link + grammar vendoring.
//! Ticket d1o-kjdk lands real command implementations.

const std = @import("std");
const cli = @import("cli.zig");

pub const version = "0.0.1-scaffold";

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    // Cross-platform arg iterator (Windows/WASI require the allocating form).
    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();

    // argv[0] is program name; skip it.
    _ = it.skip();

    var stdout_buf: [4096]u8 = undefined;
    var stderr_buf: [4096]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    var stderr_fw = std.Io.File.stderr().writerStreaming(io, &stderr_buf);
    const stdout = &stdout_fw.interface;
    const stderr = &stderr_fw.interface;

    const cmd = it.next() orelse {
        try cli.printHelp(stdout);
        try stdout.flush();
        return;
    };

    if (std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "version")) {
        try stdout.print("blitz {s}\n", .{version});
        try stdout.flush();
        return;
    }

    if (std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "help") or
        std.mem.eql(u8, cmd, "-h"))
    {
        try cli.printHelp(stdout);
        try stdout.flush();
        return;
    }

    if (std.mem.eql(u8, cmd, "doctor")) {
        try cli.runDoctor(stdout);
        try stdout.flush();
        return;
    }

    // Unimplemented commands: scaffold stage.
    try stderr.print(
        "blitz: '{s}' is not implemented yet (scaffold stage).\n" ++
            "See `blitz --help`. Implementation is tracked in tickets d1o-qphx / d1o-kjdk / d1o-cewc.\n",
        .{cmd},
    );
    try stderr.flush();
    std.process.exit(1);
}

test "version string is non-empty" {
    try std.testing.expect(version.len > 0);
}
