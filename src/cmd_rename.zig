const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");
const backup = @import("backup.zig");
const file_lock = @import("lock.zig");
const workspace = @import("workspace.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const MAX_SOURCE_BYTES = 32 * 1024 * 1024;

const RenameTarget = struct {
    start: usize,
    end: usize,
};

fn isExcludedParent(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "string_literal") or
        std.mem.eql(u8, kind, "string") or
        std.mem.eql(u8, kind, "comment") or
        std.mem.eql(u8, kind, "template_string") or
        std.mem.eql(u8, kind, "line_comment") or
        std.mem.eql(u8, kind, "block_comment") or
        std.mem.eql(u8, kind, "string_fragment") or
        std.mem.eql(u8, kind, "escape_sequence");
}

fn isRenameKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "identifier") or std.mem.eql(u8, kind, "type_identifier");
}

fn isIdentifierStart(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or c == '_' or c == '$';
}

fn isIdentifierContinue(c: u8) bool {
    return isIdentifierStart(c) or (c >= '0' and c <= '9');
}

fn isValidIdentifier(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!isIdentifierStart(name[0])) return false;
    for (name[1..]) |c| {
        if (!isIdentifierContinue(c)) return false;
    }
    return true;
}

fn lineNumberForByte(contents: []const u8, byte: usize) usize {
    const limit = @min(byte, contents.len);
    var line: usize = 1;
    var i: usize = 0;
    while (i < limit) : (i += 1) {
        if (contents[i] == '\n') line += 1;
    }
    return line;
}

fn sortTargetsDescending(targets: []RenameTarget) void {
    var i: usize = 1;
    while (i < targets.len) : (i += 1) {
        var j = i;
        while (j > 0 and targets[j - 1].start < targets[j].start) : (j -= 1) {
            std.mem.swap(RenameTarget, &targets[j - 1], &targets[j]);
        }
    }
}

fn buildRenamedContents(
    allocator: Allocator,
    original: []const u8,
    targets: []const RenameTarget,
    old_name: []const u8,
    new_name: []const u8,
) ![]u8 {
    var final_len = original.len;
    if (new_name.len >= old_name.len) {
        final_len += targets.len * (new_name.len - old_name.len);
    } else {
        final_len -= targets.len * (old_name.len - new_name.len);
    }

    var out = try allocator.alloc(u8, final_len);
    var dst: usize = final_len;
    var src: usize = original.len;

    for (targets) |target| {
        const suffix = original[target.end..src];
        dst -= suffix.len;
        @memcpy(out[dst .. dst + suffix.len], suffix);

        dst -= new_name.len;
        @memcpy(out[dst .. dst + new_name.len], new_name);

        src = target.start;
    }

    const prefix = original[0..src];
    dst -= prefix.len;
    @memcpy(out[dst .. dst + prefix.len], prefix);

    std.debug.assert(dst == 0);
    return out;
}

fn emitDiffTail(
    allocator: Allocator,
    stdout: *std.Io.Writer,
    basename: []const u8,
    original: []const u8,
    targets: []const RenameTarget,
    old_name: []const u8,
    new_name: []const u8,
) !void {
    try stdout.print("--- a/{s}\n+++ b/{s}\n", .{ basename, basename });

    for (targets) |target| {
        const line = lineNumberForByte(original, target.start);
        const hunk = try std.fmt.allocPrint(
            allocator,
            "@@ -{d},1 +{d},1 @@\n-{s}\n+{s}\n",
            .{ line, line, old_name, new_name },
        );
        defer allocator.free(hunk);
        try stdout.writeAll(hunk);
    }
}

fn restoreMtime(io: Io, path: []const u8, mtime: Io.Timestamp) !void {
    var file = try Dir.cwd().openFile(io, path, .{ .mode = .read_write });
    defer file.close(io);
    try file.setTimestamps(io, .{ .modify_timestamp = .{ .new = mtime } });
}

pub fn run(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_path: []const u8,
    old_name: []const u8,
    new_name: []const u8,
    dry_run: bool,
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,
) !u8 {
    const ext = std.fs.path.extension(file_path);
    const lang = bindings.Language.fromExtension(ext) orelse {
        try stderr.print("unsupported language for {s}", .{file_path});
        return 1;
    };

    const real_path = try Dir.cwd().realPathFileAlloc(io, file_path, allocator);
    defer allocator.free(real_path);
    try workspace.enforce(real_path);

    if (!isValidIdentifier(new_name)) {
        try stderr.print("Error: invalid new identifier '{s}'\n", .{new_name});
        return 1;
    }

    const stat = try Dir.cwd().statFile(io, real_path, .{});
    const original_mtime = stat.mtime;

    const original = try Dir.cwd().readFileAlloc(io, real_path, allocator, .limited(MAX_SOURCE_BYTES));
    defer allocator.free(original);

    var parser = bindings.Parser.init();
    defer parser.deinit();
    if (!parser.setLanguage(lang)) {
        try stderr.print("Error: failed to initialize parser for {s}\n", .{file_path});
        return 1;
    }

    var tree = parser.parseString(original) orelse {
        try stderr.print("Error: failed to parse {s}\n", .{file_path});
        return 1;
    };
    defer tree.deinit();

    const root = tree.rootNode();

    var worklist: std.ArrayList(bindings.Node) = .empty;
    defer worklist.deinit(allocator);
    var parent_kinds: std.ArrayList(?[]const u8) = .empty;
    defer parent_kinds.deinit(allocator);
    try worklist.append(allocator, root);
    try parent_kinds.append(allocator, null);

    var targets: std.ArrayList(RenameTarget) = .empty;
    defer targets.deinit(allocator);

    while (worklist.items.len > 0) {
        const node = worklist.pop() orelse break;
        const parent_kind = parent_kinds.pop() orelse null;

        const kind = node.kind();
        if ((isRenameKind(kind)) and !isExcludedParent(parent_kind orelse "")) {
            const start = @as(usize, @intCast(node.startByte()));
            const end = @as(usize, @intCast(node.endByte()));
            if (end >= start and end <= original.len and std.mem.eql(u8, original[start..end], old_name)) {
                try targets.append(allocator, .{ .start = start, .end = end });
            }
        }

        var child_index: u32 = node.childCount();
        while (child_index > 0) : (child_index -= 1) {
            if (node.child(child_index - 1)) |child| {
                try worklist.append(allocator, child);
                try parent_kinds.append(allocator, kind);
            }
        }
    }

    if (targets.items.len == 0) {
        try stderr.print("Error: no code references to '{s}' found in {s}\n", .{ old_name, file_path });
        return 1;
    }

    sortTargetsDescending(targets.items);

    const new_contents = try buildRenamedContents(allocator, original, targets.items, old_name, new_name);
    defer allocator.free(new_contents);

    var renamed_tree = parser.parseString(new_contents) orelse {
        try stderr.print("Error: renamed file does not parse for {s}\n", .{file_path});
        return 1;
    };
    defer renamed_tree.deinit();
    if (renamed_tree.rootNode().hasError()) {
        try stderr.print("Error: renamed file does not parse for {s}\n", .{file_path});
        return 1;
    }

    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    if (dry_run) {
        try stdout.print(
            "Dry run: would rename '{s}' -> '{s}' in {s}: {d} replacement(s).\n",
            .{ old_name, new_name, file_path, targets.items.len },
        );
        return 0;
    }

    var lock_guard = try file_lock.acquire(allocator, io, real_path);
    defer lock_guard.release();

    try backup.store(allocator, io, cache_dir, real_path, original);
    try backup.atomicWrite(allocator, io, real_path, new_contents);
    try restoreMtime(io, real_path, original_mtime);

    try stdout.print(
        "Renamed '{s}' -> '{s}' in {s}: {d} replacement(s). 0 model tokens.\n",
        .{ old_name, new_name, file_path, targets.items.len },
    );

    const basename = std.fs.path.basename(file_path);
    try emitDiffTail(allocator, stdout, basename, original, targets.items, old_name, new_name);
    return 0;
}

test "rename TypeScript identifier in two places and skip string literal" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{
        .sub_path = "sample.ts",
        .data =
        \\const oldFoo = 1;
        \\console.log(oldFoo);
        \\const s = "oldFoo";
        \\
    });

    const file_path = try tmp.dir.realPathFileAlloc(io, "sample.ts", allocator);
    defer allocator.free(file_path);

    var stdout_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_aw.deinit();
    var stderr_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_aw.deinit();

    const code = try run(allocator, io, file_path, "oldFoo", "newFoo", false, &stdout_aw.writer, &stderr_aw.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expect(stderr_aw.written().len == 0);

    const contents = try tmp.dir.readFileAlloc(io, "sample.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8,
        \\const newFoo = 1;
        \\console.log(newFoo);
        \\const s = "oldFoo";
        \\
        ,
        contents,
    );
}

test "rename rejects invalid new identifier" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{
        .sub_path = "invalid.ts",
        .data =
        \\const oldFoo = 1;
        \\oldFoo();
        \\
    });

    const file_path = try tmp.dir.realPathFileAlloc(io, "invalid.ts", allocator);
    defer allocator.free(file_path);

    var stdout_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_aw.deinit();
    var stderr_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_aw.deinit();

    const code = try run(allocator, io, file_path, "oldFoo", "new-name", false, &stdout_aw.writer, &stderr_aw.writer);
    try std.testing.expectEqual(@as(u8, 1), code);
    try std.testing.expect(std.mem.indexOf(u8, stderr_aw.written(), "invalid new identifier") != null);

    const contents = try tmp.dir.readFileAlloc(io, "invalid.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expect(std.mem.indexOf(u8, contents, "oldFoo") != null);
}

test "dry_run returns 0 and does not modify file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{
        .sub_path = "dry.ts",
        .data =
        \\const oldFoo = 1;
        \\oldFoo();
        \\
    });

    const file_path = try tmp.dir.realPathFileAlloc(io, "dry.ts", allocator);
    defer allocator.free(file_path);

    var stdout_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_aw.deinit();
    var stderr_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_aw.deinit();

    const code = try run(allocator, io, file_path, "oldFoo", "newFoo", true, &stdout_aw.writer, &stderr_aw.writer);
    try std.testing.expectEqual(@as(u8, 0), code);

    const contents = try tmp.dir.readFileAlloc(io, "dry.ts", allocator, .unlimited);
    defer allocator.free(contents);
    try std.testing.expectEqualSlices(u8,
        \\const oldFoo = 1;
        \\oldFoo();
        \\
        ,
        contents,
    );

    try std.testing.expect(std.mem.indexOf(u8, stdout_aw.written(), "Dry run: would rename 'oldFoo' -> 'newFoo'") != null);
    try std.testing.expect(stderr_aw.written().len == 0);
}

test "no occurrences returns 1 with no code references" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{
        .sub_path = "none.ts",
        .data =
        \\const s = "oldFoo";
        \\
    });

    const file_path = try tmp.dir.realPathFileAlloc(io, "none.ts", allocator);
    defer allocator.free(file_path);

    var stdout_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_aw.deinit();
    var stderr_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_aw.deinit();

    const code = try run(allocator, io, file_path, "oldFoo", "newFoo", false, &stdout_aw.writer, &stderr_aw.writer);
    try std.testing.expectEqual(@as(u8, 1), code);
    try std.testing.expect(std.mem.indexOf(u8, stderr_aw.written(), "no code references") != null);
}

test "real rename writes backup snapshot" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const allocator = std.testing.allocator;

    try tmp.dir.writeFile(io, .{
        .sub_path = "backup.ts",
        .data =
        \\const oldFoo = 1;
        \\oldFoo();
        \\
    });

    const file_path = try tmp.dir.realPathFileAlloc(io, "backup.ts", allocator);
    defer allocator.free(file_path);
    const cache_dir = try backup.defaultCacheDir(allocator);
    defer allocator.free(cache_dir);

    var stdout_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stdout_aw.deinit();
    var stderr_aw: std.Io.Writer.Allocating = .init(allocator);
    defer stderr_aw.deinit();

    const code = try run(allocator, io, file_path, "oldFoo", "newFoo", false, &stdout_aw.writer, &stderr_aw.writer);
    try std.testing.expectEqual(@as(u8, 0), code);
    try std.testing.expect(stderr_aw.written().len == 0);
    try std.testing.expect(try backup.exists(cache_dir, file_path));
}
