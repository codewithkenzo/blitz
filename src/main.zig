//! blitz — AST-aware fast-edit CLI.
//!
//! Entry point using Zig 0.16's "Juicy Main" (std.process.Init), which
//! provides gpa, arena, io, environ, and args via init.minimal.

const std = @import("std");
const cli = @import("cli.zig");
const cmd_read = @import("cmd_read.zig");
const cmd_edit = @import("cmd_edit.zig");
const cmd_rename = @import("cmd_rename.zig");
const cmd_undo = @import("cmd_undo.zig");
const cmd_doctor = @import("cmd_doctor.zig");

pub const version = "0.1.0";

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, gpa);
    defer it.deinit();

    _ = it.skip();

    var stdout_buf: [4096]u8 = undefined;
    var stderr_buf: [4096]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writerStreaming(io, &stdout_buf);
    var stderr_fw = std.Io.File.stderr().writerStreaming(io, &stderr_buf);
    const stdout = &stdout_fw.interface;
    const stderr = &stderr_fw.interface;

    const exit_code: u8 = blk: {
        const cmd = it.next() orelse {
            try cli.printHelp(stdout);
            break :blk 0;
        };

        if (std.mem.eql(u8, cmd, "--version") or std.mem.eql(u8, cmd, "version")) {
            try stdout.print("blitz {s}\n", .{version});
            break :blk 0;
        }

        if (std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "help") or
            std.mem.eql(u8, cmd, "-h"))
        {
            try cli.printHelp(stdout);
            break :blk 0;
        }

        if (std.mem.eql(u8, cmd, "doctor")) {
            break :blk try cmd_doctor.run(gpa, io, stdout);
        }

        if (std.mem.eql(u8, cmd, "read")) {
            const file = it.next() orelse {
                try stderr.writeAll("blitz read: missing <file> argument\n");
                break :blk 1;
            };
            break :blk try cmd_read.run(gpa, io, file, stdout, stderr);
        }

        if (std.mem.eql(u8, cmd, "edit")) {
            break :blk try dispatchEdit(gpa, io, &it, stdout, stderr);
        }

        if (std.mem.eql(u8, cmd, "rename")) {
            break :blk try dispatchRename(gpa, io, &it, stdout, stderr);
        }

        if (std.mem.eql(u8, cmd, "undo")) {
            const file = it.next() orelse {
                try stderr.writeAll("blitz undo: missing <file> argument\n");
                break :blk 1;
            };
            break :blk try cmd_undo.run(gpa, io, file, stdout, stderr);
        }

        try stderr.print("blitz: unknown command '{s}'. See `blitz --help`.\n", .{cmd});
        break :blk 1;
    };

    try stdout.flush();
    try stderr.flush();
    if (exit_code != 0) std.process.exit(exit_code);
}

fn dispatchEdit(
    gpa: std.mem.Allocator,
    io: std.Io,
    it: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    const file = it.next() orelse {
        try stderr.writeAll("blitz edit: missing <file> argument\n");
        return 1;
    };

    var snippet_arg: ?[]const u8 = null;
    var after_arg: ?[]const u8 = null;
    var replace_arg: ?[]const u8 = null;

    while (it.next()) |flag| {
        if (std.mem.eql(u8, flag, "--snippet")) {
            const value = it.next() orelse {
                try stderr.writeAll("blitz edit: --snippet expects a value\n");
                return 1;
            };
            snippet_arg = value;
        } else if (std.mem.eql(u8, flag, "--after")) {
            after_arg = it.next() orelse {
                try stderr.writeAll("blitz edit: --after expects a symbol\n");
                return 1;
            };
        } else if (std.mem.eql(u8, flag, "--replace")) {
            replace_arg = it.next() orelse {
                try stderr.writeAll("blitz edit: --replace expects a symbol\n");
                return 1;
            };
        } else {
            try stderr.print("blitz edit: unknown flag '{s}'\n", .{flag});
            return 1;
        }
    }

    const snippet_value = snippet_arg orelse {
        try stderr.writeAll("blitz edit: --snippet is required\n");
        return 1;
    };

    if ((after_arg == null) == (replace_arg == null)) {
        try stderr.writeAll("blitz edit: exactly one of --after / --replace is required\n");
        return 1;
    }

    const snippet_bytes = if (std.mem.eql(u8, snippet_value, "-"))
        try readAllStdin(gpa, io)
    else
        try gpa.dupe(u8, snippet_value);
    defer gpa.free(snippet_bytes);

    if (after_arg) |sym| {
        return try cmd_edit.runAfter(gpa, io, file, sym, snippet_bytes, stdout, stderr);
    }
    return try cmd_edit.runReplace(gpa, io, file, replace_arg.?, snippet_bytes, stdout, stderr);
}

fn dispatchRename(
    gpa: std.mem.Allocator,
    io: std.Io,
    it: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    const file = it.next() orelse {
        try stderr.writeAll("blitz rename: missing <file> argument\n");
        return 1;
    };
    const old_name = it.next() orelse {
        try stderr.writeAll("blitz rename: missing <old_name> argument\n");
        return 1;
    };
    const new_name = it.next() orelse {
        try stderr.writeAll("blitz rename: missing <new_name> argument\n");
        return 1;
    };

    var dry_run = false;
    while (it.next()) |flag| {
        if (std.mem.eql(u8, flag, "--dry-run")) {
            dry_run = true;
        } else {
            try stderr.print("blitz rename: unknown flag '{s}'\n", .{flag});
            return 1;
        }
    }

    return try cmd_rename.run(gpa, io, file, old_name, new_name, dry_run, stdout, stderr);
}

fn readAllStdin(gpa: std.mem.Allocator, io: std.Io) ![]u8 {
    var buf: [4096]u8 = undefined;
    var stdin_fr = std.Io.File.stdin().readerStreaming(io, &buf);
    const reader = &stdin_fr.interface;

    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(gpa);

    while (true) {
        var chunk: [4096]u8 = undefined;
        const n = try reader.readSliceShort(&chunk);
        if (n == 0) break;
        try list.appendSlice(gpa, chunk[0..n]);
    }

    return list.toOwnedSlice(gpa);
}

test "version string is non-empty" {
    try std.testing.expect(version.len > 0);
}
