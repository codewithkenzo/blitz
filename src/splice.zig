const std = @import("std");

pub const SpliceResult = struct {
    merged: []u8,
    used_markers: bool,
};

pub const SpliceError = error{
    AnchorNotFound,
    MarkerGrammarInvalid,
};

const MarkerMode = enum {
    existing,
    keep,
};

const Marker = struct {
    mode: MarkerMode,
    keep_lines: usize,
};

const ParsedMarker = struct {
    style: []const u8,
    marker: Marker,
};

const LineKind = enum {
    marker,
    content,
};

const SnippetLine = struct {
    kind: LineKind,
    text: []const u8,
    marker: Marker,
    orig_idx: ?usize,
};

pub fn maybeSplice(
    allocator: std.mem.Allocator,
    original_body: []const u8,
    snippet: []const u8,
    comment_styles: []const []const u8,
) error{ OutOfMemory, AnchorNotFound, MarkerGrammarInvalid }!?SpliceResult {
    const ends_with_nl = endsWithNewline(original_body);

    var original_lines = try splitLines(allocator, original_body);
    defer original_lines.deinit(allocator);

    var snippet_lines = try splitLines(allocator, snippet);
    defer snippet_lines.deinit(allocator);

    var parsed: std.ArrayList(SnippetLine) = .empty;
    defer parsed.deinit(allocator);

    var marker_style: ?[]const u8 = null;
    var marker_count: usize = 0;
    var anchor_count: usize = 0;

    var cursor: usize = 0;
    for (snippet_lines.items, 0..) |line, line_idx| {
        _ = line_idx;
        if (try parseMarker(line, comment_styles)) |detected| {
            if (marker_style) |style| {
                if (!std.mem.eql(u8, style, detected.style)) return error.MarkerGrammarInvalid;
            }
            marker_style = detected.style;
            marker_count += 1;
            try parsed.append(allocator, .{
                .kind = .marker,
                .text = line,
                .marker = detected.marker,
                .orig_idx = null,
            });
            continue;
        }

        var orig_idx: ?usize = null;
        if (!isAmbiguousAnchor(line)) {
            if (matchLine(original_lines.items, cursor, line)) |idx| {
                orig_idx = idx;
                cursor = idx + 1;
            }
        }

        if (orig_idx != null) anchor_count += 1;

        try parsed.append(allocator, .{
            .kind = .content,
            .text = line,
            .marker = .{ .mode = .existing, .keep_lines = 0 },
            .orig_idx = orig_idx,
        });
    }

    if (marker_count == 0) return null;

    const first_marker_idx: ?usize = blk: {
        for (parsed.items, 0..) |entry, i| {
            if (entry.kind == .marker) break :blk i;
        }
        break :blk null;
    };

    if (anchor_count == 0) {
        const marker_index = blk: {
            for (parsed.items, 0..) |entry, i| {
                if (entry.kind == .marker) break :blk i;
            }
            return error.AnchorNotFound;
        };

        const has_before = hasContentBefore(parsed.items, marker_index);
        const has_after = hasContentAfter(parsed.items, marker_index);
        if (has_before and has_after) return error.AnchorNotFound;

        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);

        if (has_before) {
            for (parsed.items[0..marker_index]) |entry| {
                if (entry.kind == .content) {
                    try appendLine(allocator, &out, entry.text);
                }
            }
            for (original_lines.items) |orig| try appendLine(allocator, &out, orig);
        } else if (has_after) {
            for (original_lines.items) |orig| try appendLine(allocator, &out, orig);
            for (parsed.items[marker_index + 1 ..]) |entry| {
                if (entry.kind == .content) {
                    try appendLine(allocator, &out, entry.text);
                }
            }
        } else if (parsed.items.len == 1) {
            const merged = try allocator.dupe(u8, original_body);
            return .{ .merged = merged, .used_markers = true };
        } else {
            return error.AnchorNotFound;
        }

        if (!ends_with_nl and out.items.len > 0 and out.getLast() == '\n') {
            _ = out.pop();
        }

        if (parsed.items.len == 1) {
            const merged = try allocator.dupe(u8, original_body);
            return .{ .merged = merged, .used_markers = true };
        }

        const merged = try out.toOwnedSlice(allocator);
        return .{ .merged = merged, .used_markers = true };
    }

    if (anchor_count < 2) return error.AnchorNotFound;

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var emitted_up_to: usize = 0;

    for (parsed.items, 0..) |entry, i| {
        switch (entry.kind) {
            .content => {
                const should_emit_content = if (entry.orig_idx) |oi| blk: {
                    if (first_marker_idx) |first_marker| {
                        if (i < first_marker) break :blk true;
                    }
                    break :blk oi >= emitted_up_to;
                } else true;

                if (should_emit_content) try appendLine(allocator, &out, entry.text);

                if (entry.orig_idx) |oi| {
                    if (oi + 1 > emitted_up_to) emitted_up_to = oi + 1;
                }
            },
            .marker => {
                const prev = prevAnchor(parsed.items, i);
                const next = nextAnchor(parsed.items, i);

                if (prev == null and next == null) return error.AnchorNotFound;

                const start = if (prev) |p| anchoredIndex(parsed.items[p]) + 1 else 0;
                const end = if (next) |n| anchoredIndex(parsed.items[n]) else original_lines.items.len;

                if (start > end or end > original_lines.items.len) return error.AnchorNotFound;

                var preserve_end = end;
                if (entry.marker.mode == .keep) {
                    if (start + entry.marker.keep_lines > end) return error.AnchorNotFound;
                    preserve_end = start + entry.marker.keep_lines;
                }

                if (next == null) {
                    const trailing_content = countTrailingContent(parsed.items[i + 1 ..]);
                    if (trailing_content > 0) {
                        if (trailing_content > end) return error.AnchorNotFound;
                        preserve_end = end - trailing_content;
                        if (preserve_end < start) preserve_end = start;
                    }
                }

                if (start < emitted_up_to and preserve_end <= emitted_up_to) continue;

                const emit_start = if (start > emitted_up_to) start else emitted_up_to;
                var oi: usize = emit_start;
                while (oi < preserve_end) : (oi += 1) {
                    try appendLine(allocator, &out, original_lines.items[oi]);
                }

                if (preserve_end > emitted_up_to) emitted_up_to = preserve_end;
            },
        }
    }

    if (!ends_with_nl and out.items.len > 0 and out.getLast() == '\n') {
        _ = out.pop();
    }

    const merged = try out.toOwnedSlice(allocator);
    return .{ .merged = merged, .used_markers = true };
}

fn endsWithNewline(text: []const u8) bool {
    return text.len > 0 and text[text.len - 1] == '\n';
}

fn splitLines(allocator: std.mem.Allocator, text: []const u8) !std.ArrayList([]const u8) {
    var lines: std.ArrayList([]const u8) = .empty;
    var start: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        if (text[i] == '\r') {
            if (i + 1 < text.len and text[i + 1] == '\n') {
                try lines.append(allocator, text[start..i]);
                i += 2;
                start = i;
                continue;
            }
        }

        if (text[i] == '\n') {
            try lines.append(allocator, text[start..i]);
            i += 1;
            start = i;
            continue;
        }

        i += 1;
    }

    if (start < text.len) try lines.append(allocator, text[start..text.len]);
    return lines;
}

fn matchLine(lines: []const []const u8, start: usize, target: []const u8) ?usize {
    var i = start;
    while (i < lines.len) : (i += 1) {
        if (isLineMatch(lines[i], target)) return i;
    }
    return null;
}

fn countTrailingContent(entries: []const SnippetLine) usize {
    var n: usize = 0;
    for (entries) |entry| {
        if (entry.kind == .content) n += 1;
    }
    return n;
}

fn isLineMatch(original: []const u8, candidate: []const u8) bool {
    return std.mem.eql(u8, trimLeft(original), trimLeft(candidate));
}

fn trimLeft(input: []const u8) []const u8 {
    var i: usize = 0;
    while (i < input.len and isIndentByte(input[i])) : (i += 1) {}
    return input[i..];
}

fn isIndentByte(ch: u8) bool {
    return ch == ' ' or ch == '\t';
}

fn parseMarker(line: []const u8, comment_styles: []const []const u8) error{ MarkerGrammarInvalid }!?ParsedMarker {
    const trimmed = trimLeft(line);

    for (comment_styles) |style| {
        if (style.len == 0) continue;
        if (!std.mem.startsWith(u8, trimmed, style)) continue;

        if (std.mem.eql(u8, style, "/*")) {
            if (trimmed.len < 4 or !std.mem.endsWith(u8, trimmed, "*/")) continue;
            const inside = trimmed[style.len .. trimmed.len - 2];
            if (try parseMarkerBody(inside)) |marker| {
                return .{ .style = style, .marker = marker };
            }
            continue;
        }

        const rest = trimmed[style.len..];
        if (try parseMarkerBody(rest)) |marker| {
            return .{ .style = style, .marker = marker };
        }
    }

    return null;
}

fn parseMarkerBody(raw: []const u8) error{ MarkerGrammarInvalid }!?Marker {
    const text = trimLeft(raw);
    if (text.len == 0) return null;

    if (isExistingCodeMarker(text)) return .{ .mode = .existing, .keep_lines = 0 };
    if (try isKeepMarker(text)) |count| return .{ .mode = .keep, .keep_lines = count };
    return null;
}

fn isExistingCodeMarker(text: []const u8) bool {
    const trimmed = trimLeft(text);
    var i: usize = 0;
    skipSpaces(trimmed, &i);

    if (!consumeDots(trimmed, &i)) return false;
    skipSpaces(trimmed, &i);
    if (!consumeWord(trimmed, &i, "existing")) return false;
    skipSpaces(trimmed, &i);
    if (!consumeWord(trimmed, &i, "code")) return false;
    skipSpaces(trimmed, &i);
    if (!consumeDots(trimmed, &i)) return false;
    skipSpaces(trimmed, &i);

    return i == trimmed.len;
}

fn consumeDots(text: []const u8, idx: *usize) bool {
    if (idx.* + 3 <= text.len and std.mem.startsWith(u8, text[idx.*..], "...")) {
        idx.* += 3;
        return true;
    }
    if (idx.* + 3 <= text.len and text[idx.*] == 0xE2 and text[idx.* + 1] == 0x80 and text[idx.* + 2] == 0xA6) {
        idx.* += 3;
        return true;
    }
    return false;
}

fn consumeWord(text: []const u8, idx: *usize, word: []const u8) bool {
    if (idx.* + word.len > text.len) return false;
    if (!std.mem.startsWith(u8, text[idx.*..], word)) return false;
    idx.* += word.len;
    return true;
}

fn skipSpaces(text: []const u8, idx: *usize) void {
    while (idx.* < text.len and (text[idx.*] == ' ' or text[idx.*] == '\t')) : (idx.* += 1) {}
}

fn isKeepMarker(text: []const u8) error{ MarkerGrammarInvalid }!?usize {
    const trimmed = trimLeft(text);
    if (!std.mem.startsWith(u8, trimmed, "@keep")) return null;

    var i: usize = 5;
    skipSpaces(trimmed, &i);
    if (i == trimmed.len) return 1;

    if (!std.mem.startsWith(u8, trimmed[i..], "lines")) return error.MarkerGrammarInvalid;
    i += "lines".len;
    skipSpaces(trimmed, &i);
    if (i >= trimmed.len or trimmed[i] != '=') return error.MarkerGrammarInvalid;
    i += 1;
    skipSpaces(trimmed, &i);
    if (i >= trimmed.len) return error.MarkerGrammarInvalid;

    var has_digit = false;
    var value: usize = 0;
    while (i < trimmed.len and trimmed[i] >= '0' and trimmed[i] <= '9') : (i += 1) {
        has_digit = true;
        value = value * 10 + @as(usize, trimmed[i] - '0');
    }
    if (!has_digit) return error.MarkerGrammarInvalid;

    skipSpaces(trimmed, &i);
    if (i != trimmed.len) return error.MarkerGrammarInvalid;

    return value;
}

fn anchoredIndex(entry: SnippetLine) usize {
    return entry.orig_idx orelse unreachable;
}

fn prevAnchor(entries: []const SnippetLine, idx: usize) ?usize {
    if (idx == 0) return null;
    var i: isize = @intCast(idx - 1);
    while (i >= 0) : (i -= 1) {
        const entry = entries[@intCast(i)];
        if (entry.kind == .content and entry.orig_idx != null) return @intCast(i);
    }
    return null;
}

fn nextAnchor(entries: []const SnippetLine, idx: usize) ?usize {
    var i: usize = idx + 1;
    while (i < entries.len) : (i += 1) {
        const entry = entries[i];
        if (entry.kind == .content and entry.orig_idx != null) return i;
    }
    return null;
}

fn hasContentBefore(entries: []const SnippetLine, idx: usize) bool {
    if (idx == 0) return false;
    for (entries[0..idx]) |entry| if (entry.kind == .content) return true;
    return false;
}

fn hasContentAfter(entries: []const SnippetLine, idx: usize) bool {
    if (idx + 1 >= entries.len) return false;
    for (entries[idx + 1 ..]) |entry| if (entry.kind == .content) return true;
    return false;
}

fn isAmbiguousAnchor(line: []const u8) bool {
    const compact = trimRight(trimLeft(line));

    if (compact.len < 4) return true;

    const ambiguous = [_][]const u8{
        "}",
        "{",
        "]",
        ")",
        "};",
        ");",
        "});",
        "else",
        "else:",
        "else {",
        "pass",
        "break",
        "continue",
        "return",
        "return;",
        "return None",
        "return nil",
    };

    for (ambiguous) |token| {
        if (std.mem.eql(u8, compact, token)) return true;
    }
    return false;
}

fn trimRight(input: []const u8) []const u8 {
    var end = input.len;
    while (end > 0 and (input[end - 1] == ' ' or input[end - 1] == '\t' or input[end - 1] == '\n' or input[end - 1] == '\r')) {
        end -= 1;
    }
    return input[0..end];
}

fn appendLine(allocator: std.mem.Allocator, out: *std.ArrayList(u8), line: []const u8) !void {
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}

// ---- Tests ----

test "maybeSplice returns null when snippet has no markers" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n}\n";
    const snippet = "function foo() {\n  const a = 2;\n  const b = 3;\n}\n";
    const styles = [_][]const u8{ "//", "#" };

    const result = try maybeSplice(allocator, original, snippet, &styles);
    defer if (result) |r| allocator.free(r.merged);
    try std.testing.expect(result == null);
}

test "marker preserves middle lines with existing-code marker" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n  const c = 3;\n  return a + c;\n}\n";
    const snippet = "function foo() {\n  const a = 1;\n  // ... existing code ...\n  return a + b + c;\n}\n";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    try std.testing.expect(result.used_markers);
    const expected = "function foo() {\n  const a = 1;\n  const b = 2;\n  const c = 3;\n  return a + b + c;\n}\n";
    try std.testing.expectEqualStrings(expected, result.merged);
}

test "@keep lines=3 preserves exactly 3 lines" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n  const c = 3;\n  const d = 4;\n  const e = 5;\n  return a + e;\n}\n";
    const snippet = "function foo() {\n  const a = 1;\n  // @keep lines=3\n  return a + e;\n}\n";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    const expected = "function foo() {\n  const a = 1;\n  const b = 2;\n  const c = 3;\n  const d = 4;\n  return a + e;\n}\n";
    try std.testing.expectEqualStrings(expected, result.merged);
}

test "mixed marker styles are rejected" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n}\n";
    const snippet = "function foo() {\n  // ... existing code ...\n  # @keep lines=1\n}\n";
    const styles = [_][]const u8{ "//", "#" };

    try std.testing.expectError(error.MarkerGrammarInvalid, maybeSplice(allocator, original, snippet, &styles));
}

test "marker with missing anchor returns AnchorNotFound" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n}\n";
    const snippet = "function bar() {\n  const x = 99;\n  // ... existing code ...\n  return 42;\n}\n";
    const styles = [_][]const u8{"//"};

    try std.testing.expectError(error.AnchorNotFound, maybeSplice(allocator, original, snippet, &styles));
}

test "single marker roundtrip keeps original body unchanged" {
    const allocator = std.testing.allocator;

    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n}\n";
    const snippet = "// ... existing code ...";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    try std.testing.expect(result.used_markers);
    try std.testing.expectEqualStrings(original, result.merged);
}
