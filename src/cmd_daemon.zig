const std = @import("std");
const bindings = @import("tree_sitter/bindings.zig");
const cmd_doctor = @import("cmd_doctor.zig");
const cmd_read = @import("cmd_read.zig");
const workspace = @import("workspace.zig");
const main = @import("main.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const MAX_FRAME_BYTES = 1024 * 1024;

const DaemonError = error{
    InvalidJson,
    InvalidRequest,
    InvalidWorkspaceRoot,
    MissingMethod,
    UnsupportedMethod,
    MutatingMethodRejected,
    WorkspaceRootMismatch,
    PathEscapesWorkspace,
    UnsupportedLanguage,
    FileTooBig,
    FileNotFound,
    ParserLanguageRejected,
    ParseFailed,
    IoError,
    StreamTooLong,
};

const ErrorInfo = struct {
    code: []const u8,
    message: []const u8,
    fallback_allowed: bool,
};

const ParserSlot = struct {
    lang: bindings.Language,
    parser: bindings.Parser,
};

const ParserCache = struct {
    slots: std.ArrayList(ParserSlot) = .empty,

    fn deinit(self: *ParserCache, allocator: Allocator) void {
        for (self.slots.items) |*slot| slot.parser.deinit();
        self.slots.deinit(allocator);
    }

    fn get(self: *ParserCache, allocator: Allocator, lang: bindings.Language) !*bindings.Parser {
        for (self.slots.items) |*slot| {
            if (slot.lang == lang) return &slot.parser;
        }

        var parser = bindings.Parser.init();
        errdefer parser.deinit();
        if (!parser.setLanguage(lang)) return error.ParserLanguageRejected;
        try self.slots.append(allocator, .{ .lang = lang, .parser = parser });
        return &self.slots.items[self.slots.items.len - 1].parser;
    }
};

const State = struct {
    allocator: Allocator,
    io: Io,
    workspace_root: []const u8,
    cache_epoch: u64 = 0,
    parsers: ParserCache = .{},

    fn deinit(self: *State) void {
        self.parsers.deinit(self.allocator);
    }
};

pub fn run(
    allocator: Allocator,
    io: Io,
    workspace_root: []const u8,
    stdout: *Writer,
    stderr: *Writer,
    it: *std.process.Args.Iterator,
) !u8 {
    if (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "help")) {
            try stdout.writeAll(
                \\blitz daemon — serial JSONL warm worker (prototype)
                \\
                \\USAGE:
                \\    blitz [--workspace-root <root>] daemon
                \\    blitz daemon --help
                \\
                \\PROTOCOL:
                \\    stdin:  one JSON object per line
                \\    stdout: one JSON response per line
                \\    methods: doctor, read
                \\    mutating methods (apply/edit/batch-edit/rename/undo) fail closed
                \\
            );
            return 0;
        }
        try stderr.print("blitz daemon: unknown argument '{s}'\n", .{arg});
        return 1;
    }

    var owned_workspace_root: ?[:0]u8 = null;
    defer if (owned_workspace_root) |root| allocator.free(root);

    const effective_workspace_root = blk: {
        const root_path = if (workspace_root.len == 0) "." else workspace_root;
        const canonical_root = try canonicalWorkspaceRootAlloc(allocator, io, root_path);
        owned_workspace_root = canonical_root;
        break :blk canonical_root;
    };

    workspace.setRoot(effective_workspace_root);
    var state = State{ .allocator = allocator, .io = io, .workspace_root = effective_workspace_root };
    defer state.deinit();

    try loop(&state, stdout);
    return 0;
}

fn realPathAlloc(allocator: Allocator, io: Io, path: []const u8) ![:0]u8 {
    return std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
}

fn canonicalWorkspaceRootAlloc(allocator: Allocator, io: Io, path: []const u8) ![:0]u8 {
    const canonical_root = realPathAlloc(allocator, io, path) catch return error.InvalidWorkspaceRoot;
    errdefer allocator.free(canonical_root);

    var dir = std.Io.Dir.cwd().openDir(io, canonical_root, .{}) catch return error.InvalidWorkspaceRoot;
    dir.close(io);

    return canonical_root;
}

fn loop(state: *State, stdout: *Writer) !void {
    var buf: [4096]u8 = undefined;
    var stdin_fr = std.Io.File.stdin().readerStreaming(state.io, &buf);
    const reader = &stdin_fr.interface;

    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(state.allocator);

    var oversized = false;

    while (true) {
        var chunk: [4096]u8 = undefined;
        const n = try reader.readSliceShort(&chunk);
        if (n == 0) break;

        for (chunk[0..n]) |byte| {
            if (byte == '\n') {
                if (!oversized) try processLine(state, line.items, stdout);
                line.clearRetainingCapacity();
                oversized = false;
                continue;
            }
            if (oversized) continue;
            if (line.items.len >= MAX_FRAME_BYTES) {
                try emitError(stdout, null, errorInfo(error.StreamTooLong), 0);
                try stdout.flush();
                line.clearRetainingCapacity();
                oversized = true;
                continue;
            }
            try line.append(state.allocator, byte);
        }
    }

    if (line.items.len > 0 and !oversized) try processLine(state, line.items, stdout);
}

fn processLine(state: *State, raw_line: []const u8, stdout: *Writer) !void {
    const line = std.mem.trim(u8, raw_line, " \t\r");
    if (line.len == 0) return;

    const start = Io.Clock.awake.now(state.io);
    const parsed = std.json.parseFromSlice(std.json.Value, state.allocator, line, .{}) catch {
        try emitError(stdout, null, errorInfo(error.InvalidJson), elapsedMs(state.io, start));
        try stdout.flush();
        return;
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        try emitError(stdout, null, errorInfo(error.InvalidRequest), elapsedMs(state.io, start));
        try stdout.flush();
        return;
    }

    const object = parsed.value.object;
    const id = optionalString(object, "id");

    const method = optionalString(object, "method") orelse {
        try emitError(stdout, id, errorInfo(error.MissingMethod), elapsedMs(state.io, start));
        try stdout.flush();
        return;
    };

    if (object.get("workspaceRoot")) |workspace_root_value| {
        if (workspace_root_value != .string) {
            try emitError(stdout, id, errorInfo(error.InvalidWorkspaceRoot), elapsedMs(state.io, start));
            try stdout.flush();
            return;
        }
        const request_root = workspace_root_value.string;
        if (!std.mem.eql(u8, request_root, state.workspace_root)) {
            try emitError(stdout, id, errorInfo(error.WorkspaceRootMismatch), elapsedMs(state.io, start));
            try stdout.flush();
            return;
        }
    }

    if (std.mem.eql(u8, method, "doctor")) {
        try handleDoctor(state, stdout, id, start);
    } else if (std.mem.eql(u8, method, "read")) {
        const params = if (object.get("params")) |value| if (value == .object) value.object else null else null;
        const file = if (params) |p| optionalString(p, "file") else null;
        if (file == null) {
            try emitError(stdout, id, errorInfo(error.InvalidRequest), elapsedMs(state.io, start));
        } else {
            handleRead(state, stdout, id, start, file.?) catch |err| {
                try emitError(stdout, id, errorInfo(err), elapsedMs(state.io, start));
            };
        }
    } else if (isMutatingMethod(method)) {
        try emitError(stdout, id, errorInfo(error.MutatingMethodRejected), elapsedMs(state.io, start));
    } else {
        try emitError(stdout, id, errorInfo(error.UnsupportedMethod), elapsedMs(state.io, start));
    }

    try stdout.flush();
}

fn handleDoctor(state: *State, stdout: *Writer, id: ?[]const u8, start: anytype) !void {
    var out: Writer.Allocating = .init(state.allocator);
    defer out.deinit();
    const code = try cmd_doctor.run(state.allocator, state.io, &out.writer);

    try stdout.writeAll("{\"id\":");
    try writeJsonStringOrNull(stdout, id);
    try stdout.print(",\"ok\":{},\"result\":{{\"exitCode\":{d},\"output\":", .{ code == 0, code });
    try writeJsonString(stdout, out.written());
    try stdout.print(",\"workspaceRoot\":", .{});
    try writeJsonString(stdout, state.workspace_root);
    try stdout.print(",\"cache\":{{\"parserCount\":{d},\"queryCount\":0,\"openTreeCount\":0,\"epoch\":{d}}}}},\"elapsedMs\":{d},\"worker\":{{\"version\":", .{ state.parsers.slots.items.len, state.cache_epoch, elapsedMs(state.io, start) });
    try writeJsonString(stdout, main.version);
    try stdout.print(",\"cacheEpoch\":{d}}}}}\n", .{state.cache_epoch});
}

fn handleRead(state: *State, stdout: *Writer, id: ?[]const u8, start: anytype, file_path: []const u8) !void {
    const ext = std.fs.path.extension(file_path);
    const lang = bindings.Language.fromExtension(ext) orelse return error.UnsupportedLanguage;

    const real_path = resolveReadPath(state, file_path) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return error.FileNotFound,
        else => return err,
    };
    defer state.allocator.free(real_path);
    workspace.enforce(real_path) catch return error.PathEscapesWorkspace;

    const contents = try cmd_read.readFileAlloc(state.allocator, state.io, real_path);
    defer state.allocator.free(contents);

    var out: Writer.Allocating = .init(state.allocator);
    defer out.deinit();

    const line_count = cmd_read.countLines(contents);
    if (line_count <= 100) {
        try out.writer.print(
            "{s} ({d} lines — small file, showing full content)\n\n{s}",
            .{ file_path, line_count, contents },
        );
    } else {
        const parser = try state.parsers.get(state.allocator, lang);
        var tree = parser.parseString(contents) orelse return error.ParseFailed;
        defer tree.deinit();
        state.cache_epoch += 1;

        try out.writer.print("{s} ({s}, {d} lines)\n", .{ file_path, @tagName(lang), line_count });
        try cmd_read.writeStructureSummary(&out.writer, tree.rootNode(), contents);
    }

    try stdout.writeAll("{\"id\":");
    try writeJsonStringOrNull(stdout, id);
    try stdout.print(",\"ok\":true,\"result\":{{\"file\":", .{});
    try writeJsonString(stdout, file_path);
    try stdout.print(",\"realPath\":", .{});
    try writeJsonString(stdout, real_path);
    try stdout.print(",\"language\":", .{});
    try writeJsonString(stdout, @tagName(lang));
    try stdout.print(",\"lineCount\":{d},\"output\":", .{line_count});
    try writeJsonString(stdout, out.written());
    try stdout.print(",\"workspaceRoot\":", .{});
    try writeJsonString(stdout, state.workspace_root);
    try stdout.print("}},\"elapsedMs\":{d},\"worker\":{{\"version\":", .{elapsedMs(state.io, start)});
    try writeJsonString(stdout, main.version);
    try stdout.print(",\"cacheEpoch\":{d}}}}}\n", .{state.cache_epoch});
}

fn resolveReadPath(state: *State, file_path: []const u8) ![:0]u8 {
    if (std.fs.path.isAbsolute(file_path)) {
        return realPathAlloc(state.allocator, state.io, file_path);
    }

    const workspace_relative_path = try std.fs.path.join(state.allocator, &.{ state.workspace_root, file_path });
    defer state.allocator.free(workspace_relative_path);
    return realPathAlloc(state.allocator, state.io, workspace_relative_path);
}

fn optionalString(object: std.json.ObjectMap, field: []const u8) ?[]const u8 {
    const value = object.get(field) orelse return null;
    return if (value == .string) value.string else null;
}

fn isMutatingMethod(method: []const u8) bool {
    inline for (.{ "apply", "edit", "batch-edit", "rename", "undo" }) |name| {
        if (std.mem.eql(u8, method, name)) return true;
    }
    return false;
}

fn errorInfo(err: anyerror) ErrorInfo {
    return switch (err) {
        error.InvalidJson => .{ .code = "InvalidJson", .message = "invalid JSON request", .fallback_allowed = false },
        error.MissingMethod => .{ .code = "MissingMethod", .message = "request missing method", .fallback_allowed = false },
        error.InvalidRequest => .{ .code = "InvalidRequest", .message = "invalid request", .fallback_allowed = false },
        error.InvalidWorkspaceRoot => .{ .code = "InvalidWorkspaceRoot", .message = "invalid workspace root", .fallback_allowed = false },
        error.WorkspaceRootMismatch => .{ .code = "WorkspaceRootMismatch", .message = "request workspaceRoot differs from daemon workspace root", .fallback_allowed = false },
        error.PathEscapesWorkspace => .{ .code = "PathEscapesWorkspace", .message = "path escapes workspace", .fallback_allowed = false },
        error.FileNotFound => .{ .code = "FileNotFound", .message = "file not found", .fallback_allowed = false },
        error.UnsupportedLanguage => .{ .code = "UnsupportedLanguage", .message = "unsupported language", .fallback_allowed = true },
        error.MutatingMethodRejected => .{ .code = "MutatingMethodRejected", .message = "daemon prototype rejects mutating methods", .fallback_allowed = false },
        error.UnsupportedMethod => .{ .code = "UnsupportedMethod", .message = "unsupported daemon method", .fallback_allowed = false },
        error.StreamTooLong => .{ .code = "StreamTooLong", .message = "daemon JSONL frame exceeds 1048576 bytes", .fallback_allowed = false },
        error.ParserLanguageRejected => .{ .code = "ParserLanguageRejected", .message = "parser rejected language", .fallback_allowed = true },
        error.ParseFailed => .{ .code = "ParseFailed", .message = "tree-sitter parse failed", .fallback_allowed = true },
        error.FileTooBig => .{ .code = "FileTooBig", .message = "file too large", .fallback_allowed = false },
        else => .{ .code = "IoError", .message = "daemon I/O error", .fallback_allowed = true },
    };
}

fn emitError(stdout: *Writer, id: ?[]const u8, info: ErrorInfo, elapsed_ms: u64) !void {
    try stdout.writeAll("{\"id\":");
    try writeJsonStringOrNull(stdout, id);
    try stdout.print(",\"ok\":false,\"error\":{{\"code\":", .{});
    try writeJsonString(stdout, info.code);
    try stdout.print(",\"message\":", .{});
    try writeJsonString(stdout, info.message);
    try stdout.print(",\"retryable\":false,\"fallbackAllowed\":{} }},\"elapsedMs\":{d}}}\n", .{ info.fallback_allowed, elapsed_ms });
}

fn elapsedMs(io: Io, start: anytype) u64 {
    const end = Io.Clock.awake.now(io);
    return @intCast(start.durationTo(end).toMilliseconds());
}

fn writeJsonStringOrNull(w: *Writer, value: ?[]const u8) !void {
    if (value) |text| return writeJsonString(w, text);
    try w.writeAll("null");
}

fn writeJsonString(w: *Writer, text: []const u8) !void {
    try w.writeByte('"');
    for (text) |byte| {
        switch (byte) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            0x08 => try w.writeAll("\\b"),
            0x0c => try w.writeAll("\\f"),
            0x00...0x07, 0x0b, 0x0e...0x1f, 0x80...0xff => try w.print("\\u{x:0>4}", .{byte}),
            else => try w.writeByte(byte),
        }
    }
    try w.writeByte('"');
}

test "daemon rejects mutating method" {
    var out: Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try emitError(&out.writer, "m1", errorInfo(error.MutatingMethodRejected), 0);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "\"code\":\"MutatingMethodRejected\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.written(), "\"fallbackAllowed\":false") != null);
}
