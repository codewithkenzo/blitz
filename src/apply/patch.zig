const std = @import("std");

const apply_ir = @import("ir.zig");
const apply_ops = @import("operations.zig");
const diff = @import("diff.zig");
const target = @import("target.zig");
const bindings = @import("../tree_sitter/bindings.zig");
const grammar_config = @import("../grammar_config.zig");

fn expectObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |obj| obj,
        else => return error.FieldTypeMismatch,
    };
}

fn requireString(object: std.json.ObjectMap, field: []const u8) ![]const u8 {
    const node = object.get(field) orelse return error.MissingField;
    return switch (node) {
        .string => |value| value,
        else => return error.FieldTypeMismatch,
    };
}

pub fn makeCompactPatchOp(
    allocator: std.mem.Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    original: []const u8,
    edit_value: std.json.Value,
    require_single_match: bool,
) !apply_ops.OpResult {
    const edit_obj = try expectObject(edit_value);
    const ops = try apply_ir.requireArray(edit_obj, "ops");
    const patch = try resolveCompactPatchEdits(
        allocator,
        lang,
        root,
        original,
        ops,
        require_single_match,
    );
    defer {
        for (patch) |edit| {
            if (edit.replacement_owned) allocator.free(edit.replacement);
        }
        allocator.free(patch);
    }

    const contents = try diff.applyResolvedEdits(allocator, original, patch);
    return .{
        .contents = contents,
        .range = diff.combinedRangeFromEdits(patch),
        .single_match = diff.allSingleMatch(patch),
        .changed_before = diff.totalChangedBefore(patch),
        .changed_after = diff.totalChangedAfter(patch),
    };
}

pub fn makeMultiBodyOp(
    allocator: std.mem.Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    original: []const u8,
    edit_value: std.json.Value,
    require_single_match: bool,
) !apply_ops.OpResult {
    const edit_obj = try expectObject(edit_value);
    const edits = try apply_ir.requireArray(edit_obj, "edits");
    const resolved = try resolveMultiBodyEdits(
        allocator,
        lang,
        root,
        original,
        edits,
        require_single_match,
    );
    defer {
        for (resolved) |edit| {
            if (edit.replacement_owned) allocator.free(edit.replacement);
        }
        allocator.free(resolved);
    }

    const out = try diff.applyResolvedEdits(allocator, original, resolved);
    const combined = diff.combinedRangeFromEdits(resolved);
    return .{
        .contents = out,
        .range = combined,
        .single_match = diff.allSingleMatch(resolved),
        .changed_before = diff.totalChangedBefore(resolved),
        .changed_after = diff.totalChangedAfter(resolved),
    };
}

fn resolveCompactPatchEdits(
    allocator: std.mem.Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    source: []const u8,
    ops: std.json.Array,
    require_single_match: bool,
) ![]apply_ops.MultiEdit {
    if (ops.items.len == 0) return error.PatternEmpty;

    var resolved = std.ArrayList(apply_ops.MultiEdit).empty;
    errdefer {
        for (resolved.items) |entry| {
            if (entry.replacement_owned) allocator.free(entry.replacement);
        }
        resolved.deinit(allocator);
    }

    for (ops.items) |op_item| {
        const op_arr = switch (op_item) {
            .array => |arr| arr,
            else => return error.FieldTypeMismatch,
        };
        if (op_arr.items.len < 2) return error.MissingField;

        const op_name = try apply_ops.requireTupleString(op_arr, 0);
        const symbol = try apply_ops.requireTupleString(op_arr, 1);
        const target_node = try target.resolveEditableSymbol(source, root, symbol);
        const target_start: usize = @intCast(target_node.startByte());
        const target_end: usize = @intCast(target_node.endByte());
        const body_range = target.replacementRangeFor(lang, source, target_node);
        const body = source[body_range.start..body_range.end];

        if (std.mem.eql(u8, op_name, "replace")) {
            if (op_arr.items.len < 4) return error.MissingField;
            const find = try apply_ops.requireTupleString(op_arr, 2);
            const replace = try apply_ops.requireTupleString(op_arr, 3);
            const selector = target.parseMatchSelector(apply_ops.tupleOptionalValue(op_arr, 4));
            const match = try target.selectMatch(body, find, selector, require_single_match);
            const edit_start = body_range.start + match.start;
            const edit_end = body_range.start + match.end;
            try resolved.append(allocator, .{
                .start = edit_start,
                .end = edit_end,
                .replacement = replace,
                .replacement_owned = false,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = edit_start, .editEnd = edit_end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replace.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "insert_after")) {
            if (op_arr.items.len < 4) return error.MissingField;
            const anchor = try apply_ops.requireTupleString(op_arr, 2);
            const text = try apply_ops.requireTupleString(op_arr, 3);
            const selector = target.parseMatchSelector(apply_ops.tupleOptionalValue(op_arr, 4));
            const match = try target.selectMatch(body, anchor, selector, require_single_match);
            const insert_at = body_range.start + match.end;
            try resolved.append(allocator, .{
                .start = insert_at,
                .end = insert_at,
                .replacement = text,
                .replacement_owned = false,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = insert_at, .editEnd = insert_at },
                .single_match = match.single_match,
                .changed_before = 0,
                .changed_after = text.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "wrap")) {
            if (op_arr.items.len < 4) return error.MissingField;
            const before = try apply_ops.requireTupleString(op_arr, 2);
            const after = try apply_ops.requireTupleString(op_arr, 3);
            const indent = try apply_ops.tupleOptionalIndent(op_arr, 4, 0);
            const kept_body = if (indent == 0) try allocator.dupe(u8, body) else try indentBody(allocator, body, indent);
            defer allocator.free(kept_body);
            const wrapped = try concat3(allocator, before, kept_body, after);
            try resolved.append(allocator, .{
                .start = body_range.start,
                .end = body_range.end,
                .replacement = wrapped,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body.len,
                .changed_after = wrapped.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "replace_return")) {
            if (op_arr.items.len < 3) return error.MissingField;
            const expr = try apply_ops.requireTupleString(op_arr, 2);
            const selector = target.parseMatchSelector(apply_ops.tupleOptionalValue(op_arr, 3));
            const body_node = target.findBodyNode(target_node) orelse return error.UnsupportedMultiEditOperation;
            const returns = try collectReturnStatements(allocator, source, body_node);
            defer allocator.free(returns);
            const match = try target.selectSpanFromCandidates(returns, selector, require_single_match);
            const replacement = try buildReturnReplacement(allocator, lang, expr);
            try resolved.append(allocator, .{
                .start = match.start,
                .end = match.end,
                .replacement = replacement,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = match.start, .editEnd = match.end },
                .single_match = match.single_match,
                .changed_before = match.end - match.start,
                .changed_after = replacement.len,
            });
            continue;
        }

        if (std.mem.eql(u8, op_name, "try_catch")) {
            if (op_arr.items.len < 3) return error.MissingField;
            if (!grammar_config.supportsTryCatch(lang)) return error.UnsupportedMultiEditOperation;
            const catch_body = try normalizeMultilineTrim(allocator, try apply_ops.requireTupleString(op_arr, 2));
            defer allocator.free(catch_body);
            const indent = try apply_ops.tupleOptionalIndent(op_arr, 3, 2);
            const wrapped = try buildTryCatchWrapped(allocator, body, catch_body, indent);
            try resolved.append(allocator, .{
                .start = body_range.start,
                .end = body_range.end,
                .replacement = wrapped,
                .replacement_owned = true,
                .range = .{ .targetStart = target_start, .targetEnd = target_end, .bodyStart = body_range.start, .bodyEnd = body_range.end, .editStart = body_range.start, .editEnd = body_range.end },
                .single_match = true,
                .changed_before = body.len,
                .changed_after = wrapped.len,
            });
            continue;
        }

        return error.UnsupportedMultiEditOperation;
    }

    return resolved.toOwnedSlice(allocator);
}

fn resolveMultiBodyEdits(
    allocator: std.mem.Allocator,
    lang: bindings.Language,
    root: bindings.Node,
    source: []const u8,
    edits: std.json.Array,
    require_single_match: bool,
) ![]apply_ops.MultiEdit {
    if (edits.items.len == 0) return error.PatternEmpty;

    var resolved = std.ArrayList(apply_ops.MultiEdit).empty;
    errdefer {
        for (resolved.items) |entry| {
            if (entry.replacement_owned) allocator.free(entry.replacement);
        }
        resolved.deinit(allocator);
    }

    for (edits.items) |edit_item| {
        const edit_obj = switch (edit_item) {
            .object => |obj| obj,
            else => return error.FieldTypeMismatch,
        };

        const symbol = try requireString(edit_obj, "symbol");
        const op_raw = try requireString(edit_obj, "op");
        const op = try apply_ops.parseOperation(op_raw);

        const target_node = try target.resolveEditableSymbol(source, root, symbol);
        const target_start: usize = @intCast(target_node.startByte());
        const target_end: usize = @intCast(target_node.endByte());
        const body_range = target.replacementRangeFor(lang, source, target_node);

        switch (op) {
            .replace_unique, .insert_after_anchor, .insert_before_anchor, .replace_between, .append_section, .ensure_line, .delete_range, .set_key, .patch, .set_body, .merge_body_chunk => return error.UnsupportedMultiEditOperation,
            .replace_body_span => {
                const find = try requireString(edit_obj, "find");
                const replace = try requireString(edit_obj, "replace");
                const selector = target.parseMatchSelector(edit_obj.get("occurrence"));
                const match = try target.selectMatch(source[body_range.start..body_range.end], find, selector, require_single_match);
                const edit_start = body_range.start + match.start;
                const edit_end = body_range.start + match.end;
                const range = apply_ir.RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = edit_start,
                    .editEnd = edit_end,
                };
                try resolved.append(allocator, .{
                    .start = edit_start,
                    .end = edit_end,
                    .replacement = replace,
                    .replacement_owned = false,
                    .range = range,
                    .single_match = match.single_match,
                    .changed_before = match.end - match.start,
                    .changed_after = replace.len,
                });
            },
            .insert_body_span => {
                const anchor = try requireString(edit_obj, "anchor");
                const text = try requireString(edit_obj, "text");
                const raw_pos = try requireString(edit_obj, "position");
                const selector = target.parseMatchSelector(edit_obj.get("occurrence"));
                const match = try target.selectMatch(source[body_range.start..body_range.end], anchor, selector, require_single_match);
                const insert_at = if (std.mem.eql(u8, raw_pos, "after"))
                    body_range.start + match.end
                else if (std.mem.eql(u8, raw_pos, "before"))
                    body_range.start + match.start
                else
                    return error.InvalidPosition;

                const range = apply_ir.RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = insert_at,
                    .editEnd = insert_at,
                };

                try resolved.append(allocator, .{
                    .start = insert_at,
                    .end = insert_at,
                    .replacement = text,
                    .replacement_owned = false,
                    .range = range,
                    .single_match = match.single_match,
                    .changed_before = 0,
                    .changed_after = text.len,
                });
            },
            .wrap_body => {
                const before = try requireString(edit_obj, "before");
                const keep = try requireString(edit_obj, "keep");
                const after = try requireString(edit_obj, "after");
                if (!std.mem.eql(u8, keep, "body")) return error.FieldTypeMismatch;

                const indent = if (edit_obj.get("indentKeptBodyBy")) |indent_raw| switch (indent_raw) {
                    .integer => |v| if (v < 0) return error.InvalidOccurrence else @as(usize, @intCast(v)),
                    .float => |v| float_blk: {
                        const rounded = @round(v);
                        if (v < 0 or rounded != v) return error.InvalidOccurrence;
                        break :float_blk @as(usize, @intFromFloat(rounded));
                    },
                    else => 0,
                } else 0;

                const body = source[body_range.start..body_range.end];
                const kept_body = if (indent == 0) body else try indentBody(allocator, body, indent);
                defer if (indent != 0) allocator.free(kept_body);
                const wrapped = try concat3(allocator, before, kept_body, after);

                const range = apply_ir.RangesResult{
                    .targetStart = target_start,
                    .targetEnd = target_end,
                    .bodyStart = body_range.start,
                    .bodyEnd = body_range.end,
                    .editStart = body_range.start,
                    .editEnd = body_range.end,
                };

                try resolved.append(allocator, .{
                    .start = body_range.start,
                    .end = body_range.end,
                    .replacement = wrapped,
                    .replacement_owned = true,
                    .range = range,
                    .single_match = true,
                    .changed_before = body.len,
                    .changed_after = wrapped.len,
                });
            },
            .compose_body => {
                // Multi-body compose_body stays unsupported until nested span composition is proven safe.
                return error.UnsupportedMultiEditOperation;
            },
            .multi_body, .insert_after_symbol => return error.UnsupportedMultiEditOperation,
        }
    }

    return resolved.toOwnedSlice(allocator);
}

fn collectReturnStatements(allocator: std.mem.Allocator, source: []const u8, node: bindings.Node) ![]target.EditSpan {
    var spans = std.ArrayList(target.EditSpan).empty;
    errdefer spans.deinit(allocator);
    try collectReturnStatementsRecursive(allocator, &spans, source, node);
    return spans.toOwnedSlice(allocator);
}

fn collectReturnStatementsRecursive(allocator: std.mem.Allocator, list: *std.ArrayList(target.EditSpan), source: []const u8, node: bindings.Node) !void {
    const kind = node.kind();
    if (isReturnNodeKind(kind)) {
        try list.append(allocator, .{ .start = @intCast(node.startByte()), .end = @intCast(node.endByte()) });
        return;
    }

    const child_count = node.namedChildCount();
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        if (node.namedChild(i)) |child| {
            try collectReturnStatementsRecursive(allocator, list, source, child);
        }
    }
}

fn isReturnNodeKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "return_statement") or std.mem.eql(u8, kind, "return_expression");
}

fn buildReturnReplacement(allocator: std.mem.Allocator, lang: bindings.Language, expr: []const u8) ![]u8 {
    const cleaned = trimReturnExpr(expr);
    const suffix = grammar_config.returnStatementSuffix(lang);
    return concat3(allocator, "return ", cleaned, suffix);
}

fn trimAscii(value: []const u8) []const u8 {
    return std.mem.trim(u8, value, " \t\r\n");
}

fn trimReturnExpr(value: []const u8) []const u8 {
    var cleaned = trimAscii(value);
    if (cleaned.len > 0 and cleaned[cleaned.len - 1] == ';') {
        cleaned = trimAscii(cleaned[0 .. cleaned.len - 1]);
    }
    return cleaned;
}

fn normalizeMultilineTrim(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    const cleaned = trimAscii(value);
    var out = std.ArrayList(u8).empty;
    var it = std.mem.splitScalar(u8, cleaned, '\n');
    var first = true;
    while (it.next()) |line| {
        if (!first) try out.append(allocator, '\n');
        first = false;
        try out.appendSlice(allocator, trimAscii(line));
    }
    return out.toOwnedSlice(allocator);
}

pub fn indentBody(allocator: std.mem.Allocator, body: []const u8, indent: usize) ![]u8 {
    var line_count: usize = 1;
    for (body) |ch| {
        if (ch == '\n') line_count += 1;
    }
    const out = try allocator.alloc(u8, body.len + (line_count * indent));

    var si: usize = 0;
    var di: usize = 0;
    var at_line_start = true;
    while (si < body.len) : (si += 1) {
        if (at_line_start) {
            if (body[si] == '\n') {
                out[di] = '\n';
                di += 1;
                at_line_start = true;
                continue;
            }
            if (body[si] == '\r' and si + 1 < body.len and body[si + 1] == '\n') {
                out[di] = '\r';
                out[di + 1] = '\n';
                di += 2;
                si += 1;
                at_line_start = true;
                continue;
            }
            var i: usize = 0;
            while (i < indent) : (i += 1) out[di + i] = ' ';
            di += indent;
            at_line_start = false;
        }

        out[di] = body[si];
        di += 1;
        at_line_start = body[si] == '\n' or (body[si] == '\r' and si + 1 < body.len and body[si + 1] == '\n');
    }

    return try allocator.realloc(out, di);
}

fn buildTryCatchWrapped(allocator: std.mem.Allocator, body: []const u8, catch_body: []const u8, indent: usize) ![]u8 {
    const body_clean = std.mem.trimEnd(u8, body, " \t");
    const trailing_outer = body[body_clean.len..];
    const base_indent = firstContentIndent(body_clean);
    const base = try spaces(allocator, base_indent);
    defer allocator.free(base);
    const catch_indent = base_indent + indent;
    const catch_prefix = try spaces(allocator, catch_indent);
    defer allocator.free(catch_prefix);
    const body_for_try = if (indent == 0) try allocator.dupe(u8, body_clean) else try indentBody(allocator, body_clean, indent);
    defer allocator.free(body_for_try);
    const catch_for_try = if (catch_indent == 0) try allocator.dupe(u8, catch_body) else try indentBody(allocator, catch_body, catch_indent);
    defer allocator.free(catch_for_try);

    const len = 1 + base.len + "try {".len + body_for_try.len + base.len + "} catch (error) {\n".len + catch_for_try.len + 1 + base.len + "}\n".len + trailing_outer.len;
    const out = try allocator.alloc(u8, len);
    var pos: usize = 0;
    const parts = [_][]const u8{ "\n", base, "try {", body_for_try, base, "} catch (error) {\n", catch_for_try, "\n", base, "}\n", trailing_outer };
    for (parts) |part| {
        @memcpy(out[pos .. pos + part.len], part);
        pos += part.len;
    }
    return out;
}

fn firstContentIndent(body: []const u8) usize {
    var i: usize = 0;
    while (i < body.len) {
        var count: usize = 0;
        while (i < body.len and body[i] == ' ') : (i += 1) count += 1;
        if (i >= body.len) return 0;
        if (body[i] == '\n') {
            i += 1;
            continue;
        }
        if (body[i] == '\r') {
            i += 1;
            if (i < body.len and body[i] == '\n') i += 1;
            continue;
        }
        return count;
    }
    return 0;
}

fn spaces(allocator: std.mem.Allocator, count: usize) ![]u8 {
    const out = try allocator.alloc(u8, count);
    @memset(out, ' ');
    return out;
}

pub fn concat3(allocator: std.mem.Allocator, a: []const u8, b: []const u8, c: []const u8) ![]u8 {
    const out = try allocator.alloc(u8, a.len + b.len + c.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len .. a.len + b.len], b);
    @memcpy(out[a.len + b.len ..], c);
    return out;
}
