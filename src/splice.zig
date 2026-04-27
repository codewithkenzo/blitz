const std = @import("std");

pub const SpliceResult = struct {
    merged: []u8,
    used_markers: bool,
};

pub const SpliceError = error{
    AnchorNotFound,
    MarkerGrammarInvalid,
    AmbiguousAnchor,
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

const SnippetEntry = union(enum) {
    content: []const u8,
    marker: Marker,
};

const DiffOp = union(enum) {
    equal: struct { orig_idx: usize, snippet_idx: usize },
    delete: usize,
    insert: usize,
};

pub fn maybeSplice(
    allocator: std.mem.Allocator,
    original_body: []const u8,
    snippet: []const u8,
    comment_styles: []const []const u8,
) error{ OutOfMemory, AnchorNotFound, MarkerGrammarInvalid, AmbiguousAnchor }!?SpliceResult {
    const ends_with_nl = endsWithNewline(original_body);

    var original_lines = try splitLines(allocator, original_body);
    defer original_lines.deinit(allocator);

    var snippet_lines = try splitLines(allocator, snippet);
    defer snippet_lines.deinit(allocator);

    var entries: std.ArrayList(SnippetEntry) = .empty;
    defer entries.deinit(allocator);

    var marker_style: ?[]const u8 = null;
    var marker: ?Marker = null;

    for (snippet_lines.items) |line| {
        if (try parseMarker(line, comment_styles)) |parsed_marker| {
            if (marker_style) |style| {
                if (!std.mem.eql(u8, style, parsed_marker.style)) return error.MarkerGrammarInvalid;
            }
            marker_style = parsed_marker.style;
            if (marker != null) return error.MarkerGrammarInvalid;
            marker = parsed_marker.marker;
            try entries.append(allocator, .{ .marker = parsed_marker.marker });
            continue;
        }
        try entries.append(allocator, .{ .content = line });
    }

    const splice_marker = marker orelse return null;
    if (entries.items.len == 1) {
        const merged = try allocator.dupe(u8, original_body);
        return .{ .merged = merged, .used_markers = true };
    }

    const marker_split = countContentBeforeMarker(entries.items);
    const snippet_content = try collectContentLines(allocator, entries.items);
    defer allocator.free(snippet_content);

    const merged = try mergeWithDiff(
        allocator,
        original_lines.items,
        snippet_content,
        marker_split,
        splice_marker,
        ends_with_nl,
    );
    return .{ .merged = merged, .used_markers = true };
}

fn mergeWithDiff(
    allocator: std.mem.Allocator,
    original_lines: []const []const u8,
    snippet_lines: []const []const u8,
    marker_split: usize,
    marker: Marker,
    ends_with_nl: bool,
) ![]u8 {
    const ops = try buildDiffOps(allocator, original_lines, snippet_lines);
    defer allocator.free(ops);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var delete_block: std.ArrayList(usize) = .empty;
    defer delete_block.deinit(allocator);
    var insert_block: std.ArrayList(usize) = .empty;
    defer insert_block.deinit(allocator);

    var preserved_lines_total: usize = 0;
    var keep_applied = false;

    for (ops) |op| {
        switch (op) {
            .equal => |eq| {
                preserved_lines_total += try flushEditBlock(
                    allocator,
                    &out,
                    &delete_block,
                    &insert_block,
                    original_lines,
                    snippet_lines,
                    marker_split,
                    marker,
                    &keep_applied,
                );
                try appendLine(allocator, &out, snippet_lines[eq.snippet_idx]);
            },
            .delete => |orig_idx| try delete_block.append(allocator, orig_idx),
            .insert => |snippet_idx| try insert_block.append(allocator, snippet_idx),
        }
    }

    preserved_lines_total += try flushEditBlock(
        allocator,
        &out,
        &delete_block,
        &insert_block,
        original_lines,
        snippet_lines,
        marker_split,
        marker,
        &keep_applied,
    );

    if (marker.mode == .keep and !keep_applied and marker.keep_lines > 0) return error.AnchorNotFound;
    if (marker.mode == .existing and preserved_lines_total == 0) return error.AnchorNotFound;

    if (!ends_with_nl and out.items.len > 0 and out.getLast() == '\n') {
        _ = out.pop();
    }

    return out.toOwnedSlice(allocator);
}

fn flushEditBlock(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    delete_block: *std.ArrayList(usize),
    insert_block: *std.ArrayList(usize),
    original_lines: []const []const u8,
    snippet_lines: []const []const u8,
    marker_split: usize,
    marker: Marker,
    keep_applied: *bool,
) !usize {
    defer delete_block.clearRetainingCapacity();
    defer insert_block.clearRetainingCapacity();

    if (delete_block.items.len == 0 and insert_block.items.len == 0) return 0;

    if (delete_block.items.len > 0 and insert_block.items.len == 0) {
        return switch (marker.mode) {
            .existing => blk: {
                for (delete_block.items) |orig_idx| try appendLine(allocator, out, original_lines[orig_idx]);
                break :blk delete_block.items.len;
            },
            .keep => blk: {
                if (keep_applied.*) return error.AmbiguousAnchor;
                if (marker.keep_lines > delete_block.items.len) return error.AnchorNotFound;
                for (delete_block.items[0..marker.keep_lines]) |orig_idx| {
                    try appendLine(allocator, out, original_lines[orig_idx]);
                }
                keep_applied.* = true;
                break :blk marker.keep_lines;
            },
        };
    }

    if (delete_block.items.len == 0) {
        for (insert_block.items) |snippet_idx| try appendLine(allocator, out, snippet_lines[snippet_idx]);
        return 0;
    }

    var has_before_inserts = false;
    var has_after_inserts = false;
    for (insert_block.items) |snippet_idx| {
        if (snippet_idx < marker_split) {
            has_before_inserts = true;
        } else {
            has_after_inserts = true;
        }
    }
    if (has_before_inserts and has_after_inserts) return error.AmbiguousAnchor;

    const replaced_count = @min(delete_block.items.len, insert_block.items.len);
    const preserved_count = delete_block.items.len - replaced_count;

    if (has_before_inserts) {
        for (insert_block.items) |snippet_idx| try appendLine(allocator, out, snippet_lines[snippet_idx]);
        for (delete_block.items[replaced_count..]) |orig_idx| try appendLine(allocator, out, original_lines[orig_idx]);
        return preserved_count;
    }

    for (delete_block.items[0..preserved_count]) |orig_idx| try appendLine(allocator, out, original_lines[orig_idx]);
    for (insert_block.items) |snippet_idx| try appendLine(allocator, out, snippet_lines[snippet_idx]);
    return preserved_count;
}

fn buildDiffOps(
    allocator: std.mem.Allocator,
    original_lines: []const []const u8,
    snippet_lines: []const []const u8,
) ![]DiffOp {
    const m = original_lines.len;
    const n = snippet_lines.len;
    const width = n + 1;
    const table = try allocator.alloc(usize, (m + 1) * width);
    defer allocator.free(table);
    @memset(table, 0);

    var i: usize = 1;
    while (i <= m) : (i += 1) {
        var j: usize = 1;
        while (j <= n) : (j += 1) {
            const idx = i * width + j;
            if (isLineMatch(original_lines[i - 1], snippet_lines[j - 1])) {
                table[idx] = table[(i - 1) * width + (j - 1)] + 1;
            } else {
                const up = table[(i - 1) * width + j];
                const left = table[i * width + (j - 1)];
                table[idx] = if (up >= left) up else left;
            }
        }
    }

    var reverse_ops: std.ArrayList(DiffOp) = .empty;
    defer reverse_ops.deinit(allocator);

    i = m;
    var j = n;
    while (i > 0 or j > 0) {
        if (i > 0 and j > 0 and isLineMatch(original_lines[i - 1], snippet_lines[j - 1]) and
            table[i * width + j] == table[(i - 1) * width + (j - 1)] + 1)
        {
            try reverse_ops.append(allocator, .{ .equal = .{ .orig_idx = i - 1, .snippet_idx = j - 1 } });
            i -= 1;
            j -= 1;
            continue;
        }

        if (j > 0 and (i == 0 or table[i * width + (j - 1)] >= table[(i - 1) * width + j])) {
            try reverse_ops.append(allocator, .{ .insert = j - 1 });
            j -= 1;
        } else {
            try reverse_ops.append(allocator, .{ .delete = i - 1 });
            i -= 1;
        }
    }

    const ops = try allocator.alloc(DiffOp, reverse_ops.items.len);
    for (reverse_ops.items, 0..) |op, idx| {
        ops[idx] = reverse_ops.items[reverse_ops.items.len - 1 - idx];
        _ = op;
    }
    return ops;
}

fn collectContentLines(allocator: std.mem.Allocator, entries: []const SnippetEntry) ![][]const u8 {
    var count: usize = 0;
    for (entries) |entry| {
        switch (entry) {
            .content => count += 1,
            .marker => {},
        }
    }

    const out = try allocator.alloc([]const u8, count);
    var idx: usize = 0;
    for (entries) |entry| {
        switch (entry) {
            .content => |line| {
                out[idx] = line;
                idx += 1;
            },
            .marker => {},
        }
    }
    return out;
}

fn countContentBeforeMarker(entries: []const SnippetEntry) usize {
    var count: usize = 0;
    for (entries) |entry| {
        switch (entry) {
            .content => count += 1,
            .marker => return count,
        }
    }
    return count;
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

fn isLineMatch(original: []const u8, candidate: []const u8) bool {
    return std.mem.eql(u8, trimLeft(original), trimLeft(candidate));
}

fn trimLeft(input: []const u8) []const u8 {
    var idx: usize = 0;
    while (idx < input.len and isIndentByte(input[idx])) : (idx += 1) {}
    return input[idx..];
}

fn trimRight(input: []const u8) []const u8 {
    var end = input.len;
    while (end > 0 and (input[end - 1] == ' ' or input[end - 1] == '\t' or input[end - 1] == '\n' or input[end - 1] == '\r')) {
        end -= 1;
    }
    return input[0..end];
}

fn isIndentByte(ch: u8) bool {
    return ch == ' ' or ch == '\t';
}

fn appendLine(allocator: std.mem.Allocator, out: *std.ArrayList(u8), line: []const u8) !void {
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}

fn parseMarker(line: []const u8, comment_styles: []const []const u8) error{MarkerGrammarInvalid}!?ParsedMarker {
    const trimmed = trimLeft(line);

    for (comment_styles) |style| {
        if (style.len == 0) continue;
        if (!std.mem.startsWith(u8, trimmed, style)) continue;

        if (std.mem.eql(u8, style, "/*")) {
            if (trimmed.len < 4 or !std.mem.endsWith(u8, trimmed, "*/")) continue;
            const inside = trimmed[style.len .. trimmed.len - 2];
            if (try parseMarkerBody(inside)) |marker| return .{ .style = style, .marker = marker };
            continue;
        }

        const rest = trimmed[style.len..];
        if (try parseMarkerBody(rest)) |marker| return .{ .style = style, .marker = marker };
    }

    return null;
}

fn parseMarkerBody(raw: []const u8) error{MarkerGrammarInvalid}!?Marker {
    const text = trimLeft(raw);
    if (text.len == 0) return null;

    if (isExistingCodeMarker(text) or isEllipsisOnlyMarker(text)) {
        return .{ .mode = .existing, .keep_lines = 0 };
    }
    if (try isKeepMarker(text)) |count| {
        return .{ .mode = .keep, .keep_lines = count };
    }
    return null;
}

fn isExistingCodeMarker(text: []const u8) bool {
    const trimmed = trimRight(trimLeft(text));
    var idx: usize = 0;
    skipSpaces(trimmed, &idx);
    if (!consumeDots(trimmed, &idx)) return false;
    skipSpaces(trimmed, &idx);
    if (!consumeWord(trimmed, &idx, "existing")) return false;
    skipSpaces(trimmed, &idx);
    if (!consumeWord(trimmed, &idx, "code")) return false;
    skipSpaces(trimmed, &idx);
    if (!consumeDots(trimmed, &idx)) return false;
    skipSpaces(trimmed, &idx);
    return idx == trimmed.len;
}

fn isEllipsisOnlyMarker(text: []const u8) bool {
    const trimmed = trimRight(trimLeft(text));
    var idx: usize = 0;
    skipSpaces(trimmed, &idx);
    if (!consumeDots(trimmed, &idx)) return false;
    skipSpaces(trimmed, &idx);
    return idx == trimmed.len;
}

fn isKeepMarker(text: []const u8) error{MarkerGrammarInvalid}!?usize {
    const trimmed = trimLeft(text);
    if (!std.mem.startsWith(u8, trimmed, "@keep")) return null;

    var idx: usize = 5;
    skipSpaces(trimmed, &idx);
    if (idx == trimmed.len) return 1;

    if (!std.mem.startsWith(u8, trimmed[idx..], "lines")) return error.MarkerGrammarInvalid;
    idx += "lines".len;
    skipSpaces(trimmed, &idx);
    if (idx >= trimmed.len or trimmed[idx] != '=') return error.MarkerGrammarInvalid;
    idx += 1;
    skipSpaces(trimmed, &idx);
    if (idx >= trimmed.len) return error.MarkerGrammarInvalid;

    var value: usize = 0;
    var has_digit = false;
    while (idx < trimmed.len and trimmed[idx] >= '0' and trimmed[idx] <= '9') : (idx += 1) {
        has_digit = true;
        value = value * 10 + @as(usize, trimmed[idx] - '0');
    }
    if (!has_digit) return error.MarkerGrammarInvalid;

    skipSpaces(trimmed, &idx);
    if (idx != trimmed.len) return error.MarkerGrammarInvalid;
    return value;
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

test "marker preserves long middle block and replaces tail line" {
    const allocator = std.testing.allocator;
    const original =
        "function foo() {\n" ++
        "  const start = 1;\n" ++
        "  const keep1 = 2;\n" ++
        "  const keep2 = 3;\n" ++
        "  const keep3 = 4;\n" ++
        "  const report = start + keep1 + keep2 + keep3;\n" ++
        "  return report;\n" ++
        "}\n";
    const snippet =
        "function foo() {\n" ++
        "  const start = 1;\n" ++
        "  // ... existing code ...\n" ++
        "  const report = start + keep1 + keep2 + keep3 + 1;\n" ++
        "  return report + 1;\n" ++
        "}\n";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    const expected =
        "function foo() {\n" ++
        "  const start = 1;\n" ++
        "  const keep1 = 2;\n" ++
        "  const keep2 = 3;\n" ++
        "  const keep3 = 4;\n" ++
        "  const report = start + keep1 + keep2 + keep3 + 1;\n" ++
        "  return report + 1;\n" ++
        "}\n";
    try std.testing.expectEqualStrings(expected, result.merged);
}

test "marker can replace head line and preserve rest" {
    const allocator = std.testing.allocator;
    const original = "function foo(a: number): number {\n  return a + 1;\n}\n";
    const snippet = "function foo(a: number): string {\n  // ...\n}\n";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    const expected = "function foo(a: number): string {\n  return a + 1;\n}\n";
    try std.testing.expectEqualStrings(expected, result.merged);
}

test "analyzeValues marker preserves declarations without duplicate report" {
    const allocator = std.testing.allocator;
    const original =
        "function analyzeValues(values: ReadonlyArray<number>): string {\n" ++
        "  if (values.length === 0) {\n" ++
        "    return \"n/a\";\n" ++
        "  }\n\n" ++
        "  const sorted = [...values].filter(Number.isFinite);\n" ++
        "  const count = sorted.length;\n" ++
        "  const min = sorted[0]!;\n" ++
        "  const max = sorted[sorted.length - 1]!;\n" ++
        "  let total = 0;\n" ++
        "  let squares = 0;\n" ++
        "  let outliers = 0;\n\n" ++
        "  for (const value of sorted) {\n" ++
        "    if (value < -1000 || value > 1000) {\n" ++
        "      outliers += 1;\n" ++
        "      continue;\n" ++
        "    }\n\n" ++
        "    total += value;\n" ++
        "    squares += value * value;\n" ++
        "  }\n\n" ++
        "  const average = total / Math.max(count, 1);\n" ++
        "  const variance = squares / Math.max(count, 1) - average * average;\n" ++
        "  const spread = max - min;\n" ++
        "  const midpoint = (min + max) / 2;\n" ++
        "  const stability = spread <= midpoint ? \"tight\" : \"wide\";\n" ++
        "  const score = Math.round((average + spread - Math.abs(variance)) * 100) / 100;\n" ++
        "  const quality = outliers > 0 ? `outlier:${outliers}` : `stable:${stability}`;\n" ++
        "  const margin = spread - average;\n" ++
        "  const header = `count=${count}`;\n" ++
        "  const details = `${header} avg=${average.toFixed(2)} spread=${spread.toFixed(2)} score=${score.toFixed(2)} quality=${quality}`;\n" ++
        "  const body = `${details} margin=${margin.toFixed(2)}`;\n" ++
        "  const report = `report:${body} range=${min}..${max}`;\n\n" ++
        "  return report;\n" ++
        "}\n";
    const snippet =
        "function analyzeValues(values: ReadonlyArray<number>): string {\n" ++
        "  if (values.length === 0) {\n" ++
        "    return \"n/a\";\n" ++
        "  }\n\n" ++
        "  const sorted = [...values].filter(Number.isFinite);\n" ++
        "  const count = sorted.length + 0;\n" ++
        "  const min = sorted[0]!;\n" ++
        "  let outliers = 0;\n" ++
        "  // ... existing code ...\n" ++
        "  const report = `report:${body} range=${min}..${max}`;\n" ++
        "  return report + \" [bounded]\";\n" ++
        "}\n";
    const styles = [_][]const u8{"//"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    const expected =
        "function analyzeValues(values: ReadonlyArray<number>): string {\n" ++
        "  if (values.length === 0) {\n" ++
        "    return \"n/a\";\n" ++
        "  }\n\n" ++
        "  const sorted = [...values].filter(Number.isFinite);\n" ++
        "  const count = sorted.length + 0;\n" ++
        "  const min = sorted[0]!;\n" ++
        "  const max = sorted[sorted.length - 1]!;\n" ++
        "  let total = 0;\n" ++
        "  let squares = 0;\n" ++
        "  let outliers = 0;\n\n" ++
        "  for (const value of sorted) {\n" ++
        "    if (value < -1000 || value > 1000) {\n" ++
        "      outliers += 1;\n" ++
        "      continue;\n" ++
        "    }\n\n" ++
        "    total += value;\n" ++
        "    squares += value * value;\n" ++
        "  }\n\n" ++
        "  const average = total / Math.max(count, 1);\n" ++
        "  const variance = squares / Math.max(count, 1) - average * average;\n" ++
        "  const spread = max - min;\n" ++
        "  const midpoint = (min + max) / 2;\n" ++
        "  const stability = spread <= midpoint ? \"tight\" : \"wide\";\n" ++
        "  const score = Math.round((average + spread - Math.abs(variance)) * 100) / 100;\n" ++
        "  const quality = outliers > 0 ? `outlier:${outliers}` : `stable:${stability}`;\n" ++
        "  const margin = spread - average;\n" ++
        "  const header = `count=${count}`;\n" ++
        "  const details = `${header} avg=${average.toFixed(2)} spread=${spread.toFixed(2)} score=${score.toFixed(2)} quality=${quality}`;\n" ++
        "  const body = `${details} margin=${margin.toFixed(2)}`;\n" ++
        "  const report = `report:${body} range=${min}..${max}`;\n\n" ++
        "  return report + \" [bounded]\";\n" ++
        "}\n";
    try std.testing.expectEqualStrings(expected, result.merged);
    try std.testing.expect(std.mem.count(u8, result.merged, "const report =") == 1);
    try std.testing.expect(std.mem.indexOf(u8, result.merged, "let total = 0;") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.merged, "let squares = 0;") != null);
}

test "shorthand marker is accepted" {
    const allocator = std.testing.allocator;
    const original = "def greet(name):\n    prefix = \"hi\"\n    return prefix + name\n";
    const snippet = "def greet(name):\n    # ...\n    return prefix + name.upper()\n";
    const styles = [_][]const u8{"#"};

    const result = try maybeSplice(allocator, original, snippet, &styles) orelse return;
    defer allocator.free(result.merged);

    const expected = "def greet(name):\n    prefix = \"hi\"\n    return prefix + name.upper()\n";
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

test "marker with ambiguous anchors returns AmbiguousAnchor" {
    const allocator = std.testing.allocator;
    const original = "function foo() {\n  const a = 1;\n  const b = 2;\n}\n";
    const snippet = "function bar() {\n  const x = 99;\n  // ... existing code ...\n  return 42;\n}\n";
    const styles = [_][]const u8{"//"};

    try std.testing.expectError(error.AmbiguousAnchor, maybeSplice(allocator, original, snippet, &styles));
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
