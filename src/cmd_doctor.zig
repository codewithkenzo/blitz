const std = @import("std");
const backup = @import("backup.zig");
const bindings = @import("tree_sitter/bindings.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Dir = std.Io.Dir;

const GrammarProbe = struct {
    name: []const u8,
    lang: bindings.Language,
};

const supported_grammars = [_]GrammarProbe{
    .{ .name = "rust", .lang = .rust },
    .{ .name = "typescript", .lang = .typescript },
    .{ .name = "tsx", .lang = .tsx },
    .{ .name = "python", .lang = .python },
    .{ .name = "go", .lang = .go },
};

fn probeGrammar(lang: bindings.Language) bool {
    var parser = bindings.Parser.init();
    defer parser.deinit();

    if (!parser.setLanguage(lang)) return false;

    var tree = parser.parseString("x") orelse return false;
    defer tree.deinit();

    return true;
}

fn writeGrammarLine(w: *Writer) !bool {
    try w.writeAll("  tree-sitter: linked\n");
    try w.writeAll("  grammars:    ");

    var all_ok = true;
    for (supported_grammars, 0..) |probe, idx| {
        const ok = probeGrammar(probe.lang);
        all_ok = all_ok and ok;

        if (idx != 0) try w.writeAll(", ");
        try w.print("{s} {s}", .{ probe.name, if (ok) "ok" else "FAIL" });
    }

    try w.writeAll("\n");
    return all_ok;
}

fn countBackups(allocator: Allocator, io: Io, cache_dir: []const u8) !?usize {
    const backup_root = std.fs.path.join(allocator, &.{ cache_dir, "blitz", "backup" }) catch return null;
    defer allocator.free(backup_root);

    var dir = Dir.cwd().openDir(io, backup_root, .{ .iterate = true }) catch return null;
    defer dir.close(io);

    var iter = dir.iterate();
    var count: usize = 0;
    while (iter.next(io) catch return null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".bak")) {
            count += 1;
        }
    }

    return count;
}

fn writeCacheLine(allocator: Allocator, io: Io, w: *Writer) !void {
    const cache_dir = backup.defaultCacheDir(allocator) catch {
        try w.writeAll("  cache:       not initialized (no edits yet)\n");
        return;
    };
    defer allocator.free(cache_dir);

    const backup_count = countBackups(allocator, io, cache_dir) catch null;
    if (backup_count) |count| {
        try w.print("  cache:       OK ({d} backups in {s}/blitz/backup)\n", .{ count, cache_dir });
        return;
    }

    try w.writeAll("  cache:       not initialized (no edits yet)\n");
}

pub fn run(
    allocator: Allocator,
    io: Io,
    stdout: *Writer,
) !u8 {
    try stdout.writeAll(
        \\blitz doctor
        \\  version:     0.1.0-alpha.3
        \\  stage:       v0.1
        \\
    );

    const grammars_ok = try writeGrammarLine(stdout);
    try writeCacheLine(allocator, io, stdout);

    try stdout.writeAll(
        \\  extensions:  .rs .ts .tsx .py .go
        \\  commands:    read, edit, batch-edit, rename, undo, doctor, apply
        \\
    );

    return if (grammars_ok) 0 else 1;
}

test "doctor exits 0 when all five grammars parse" {
    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    const code = try run(std.testing.allocator, std.testing.io, &out.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
}

test "doctor output contains version and grammars blocks" {
    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    _ = try run(std.testing.allocator, std.testing.io, &out.writer);
    const text = out.written();

    try std.testing.expect(std.mem.indexOf(u8, text, "version:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "grammars:") != null);
}

test "doctor cache line uses one of expected forms" {
    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    const cache_dir = try backup.defaultCacheDir(std.testing.allocator);
    defer std.testing.allocator.free(cache_dir);
    try std.testing.expect(cache_dir.len > 0);

    _ = try run(std.testing.allocator, std.testing.io, &out.writer);
    const text = out.written();

    const not_initialized = std.mem.indexOf(u8, text, "  cache:       not initialized (no edits yet)\n") != null;
    const ok_form = std.mem.indexOf(u8, text, "  cache:       OK (") != null;
    try std.testing.expect(not_initialized or ok_form);
}
