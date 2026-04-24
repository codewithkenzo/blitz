# fastedit deterministic splice algorithm
## Inputs
1. `original_func: []const u8` — original symbol text.
2. `snippet: []const u8` — snippet lines; may contain context anchors, new lines, marker line(s).
3. `max_drop_gap: usize` — max original-line gap allowed to drop without marker; default `20`.
4. `name: []const u8` + `ast_nodes: []const ASTNode` for `_resolve_symbol`.
5. `source: []const u8` + `language: Language` for `validate_parse`.
## Outputs
1. Deterministic splice result `[]u8` / `[]const u8` when confident.
2. `null` when fast path must defer to model / semantic merge.
3. Parse-validation bool from `validate_parse`.
## Steps
1. Split `original_func` with `splitlines()` into `orig_lines`; keep `orig_stripped = trim(orig_lines[i])`.
2. Split `snippet` with `splitlines()` into `snip_raw`.
3. Classify each `snip_raw[i]` in order with a forward scan through `orig_lines`.
4. If marker-only zero-body-anchor shape is detected, do position-mode insert.
5. Else require at least 2 context anchors.
6. Reject unsafe gaps over `max_drop_gap` when no marker sits between anchor pair.
7. Build merged output by section: prefix, per-anchor body sections, suffix.
8. Preserve or shift indentation per anchor / gap rules.
9. Preserve trailing newline iff `original_func` ended with newline.
10. If post-splice parse validation is enabled and `validate_parse(merged, language) == false`, return `null`.
## Pseudocode
```zig
const MarkerKind = enum { blank, marker, context, new };
const ClassifiedLine = struct {
    kind: MarkerKind,
    snip_idx: usize,
    orig_idx: ?usize,
    line: []const u8,
};
fn deterministicEdit(original_func: []const u8, snippet: []const u8, max_drop_gap: usize) ?[]u8 {
    const orig_lines = splitLines(original_func);
    const orig_stripped = trimAll(orig_lines);
    const snip_raw = splitLines(snippet);
    var classified = ArrayList(ClassifiedLine).init(allocator);
    var orig_cursor: usize = 0;
    // 1) classify
    for (snip_raw, 0..) |sl, si| {
        const stripped = trim(sl);
        if (stripped.len == 0) {
            classified.append(.{ .kind = .blank, .snip_idx = si, .orig_idx = null, .line = sl });
            continue;
        }
        if (isMarkerLine(sl)) {
            classified.append(.{ .kind = .marker, .snip_idx = si, .orig_idx = null, .line = sl });
            continue;
        }
        var found_idx: ?usize = null;
        const remaining_significant = hasLaterSignificantLines(snip_raw, si);
        const skip_as_ambiguous = isAmbiguousAnchor(stripped) and remaining_significant;
        if (!skip_as_ambiguous) {
            var oi = orig_cursor;
            while (oi < orig_stripped.len) : (oi += 1) {
                if (!eql(orig_stripped[oi], stripped)) continue;
                // indent-consistency filter against previous context anchor
                if (lastContext(classified)) |ref_ctx| {
                    const expected_diff = indent(orig_lines[ref_ctx.orig_idx.?]) - indent(snip_raw[ref_ctx.snip_idx]);
                    const actual_diff = indent(orig_lines[oi]) - indent(sl);
                    if (abs(actual_diff - expected_diff) > 2) continue;
                }
                found_idx = oi;
                orig_cursor = oi + 1;
                break;
            }
        }
        if (found_idx) |oi| {
            classified.append(.{ .kind = .context, .snip_idx = si, .orig_idx = oi, .line = sl });
        } else {
            classified.append(.{ .kind = .new, .snip_idx = si, .orig_idx = null, .line = sl });
        }
    }
    const context_entries = filterKind(classified, .context);
    const marker_entries = filterKind(classified, .marker);
    const new_entries = filterKind(classified, .new);
    const body_anchors = filterBodyAnchors(context_entries); // orig_idx > 0
    // 2) marker-only position mode: zero body anchors, exactly one marker, at least one new line
    if (body_anchors.len == 0 and marker_entries.len == 1 and new_entries.len >= 1) {
        const marker_si = marker_entries[0].snip_idx;
        const new_before = filterBefore(new_entries, marker_si);
        const new_after = filterAfter(new_entries, marker_si);
        if (new_before.len > 0 and new_after.len > 0) return null; // ambiguous flank
        if (new_before.len > 0) {
            if (hasFlowTokenOverlap(new_before, orig_lines)) return null;
            if (looksLikeWrapBlock(new_before[new_before.len - 1].line) and markerNestedDeeper(new_before, marker_entries[0].line)) return null;
            return emitPositionTop(orig_lines, snip_raw, new_before, firstContext(context_entries), original_func);
        }
        if (new_after.len > 0) {
            return emitPositionBottom(orig_lines, snip_raw, new_after, firstContext(context_entries), original_func);
        }
    }
    // 3) hard minimum context anchors
    if (context_entries.len < 2) return null;
    // 4) unsafe gap without marker
    var ci: usize = 0;
    while (ci + 1 < context_entries.len) : (ci += 1) {
        const curr = context_entries[ci];
        const next = context_entries[ci + 1];
        const gap_size = next.orig_idx.? - curr.orig_idx.? - 1;
        if (gap_size == 0) continue;
        const has_marker = anyMarkerBetween(classified, curr.snip_idx, next.snip_idx);
        if (!has_marker and gap_size > max_drop_gap) return null;
    }
    // 5) build result
    var result = ArrayList([]const u8).init(allocator);
    const first_orig = context_entries[0].orig_idx.?;
    const last_orig = context_entries[context_entries.len - 1].orig_idx.?;
    // prefix / leading new lines
    const leading_new = newBeforeFirstContext(classified, context_entries[0].snip_idx);
    const first_anchor_shifted_right = indent(snip_raw[context_entries[0].snip_idx]) > indent(orig_lines[first_orig]);
    if (leading_new.len > 0) {
        for (leading_new) |e| result.append(adjustIndent(e.line, first_orig, context_entries[0].snip_idx, snip_raw, orig_lines, first_anchor_shifted_right));
    } else {
        appendSlice(result, orig_lines[0..first_orig]);
    }
    // between anchors
    for (context_entries, 0..) |ctx, i| {
        const ctx_orig = ctx.orig_idx.?;
        const ctx_si = ctx.snip_idx;
        const anchor_indent_delta = indent(snip_raw[ctx_si]) - indent(orig_lines[ctx_orig]);
        if (anchor_indent_delta > 0) result.append(spacesOrTabs(orig_lines[ctx_orig], anchor_indent_delta) ++ orig_lines[ctx_orig]);
        else result.append(orig_lines[ctx_orig]);
        if (i + 1 == context_entries.len) break;
        const next_ctx = context_entries[i + 1];
        const section = between(classified, ctx_si, next_ctx.snip_idx);
        if (countMarkers(section) >= 2) return null;
        if (hasMarker(section)) {
            // preserve original gap, insert new lines around marker position
            const marker_entry = firstMarker(section);
            const indent_delta = markerGapIndentDelta(orig_lines, snip_raw, ctx_orig, ctx_si, next_ctx.orig_idx.? , marker_entry.snip_idx);
            emitPreservedGapWithReplacementSkipping(result, orig_lines, ctx_orig, next_ctx.orig_idx.?, section, indent_delta, ctx, snip_raw);
            emitNewLinesInSection(result, section, ctx_orig, ctx_si, snip_raw, orig_lines);
        } else {
            // replace mode: drop original gap, keep blanks from snippet
            emitNewLinesAndBlanks(result, section, ctx_orig, ctx_si, snip_raw, orig_lines);
        }
    }
    // trailing section
    const trailing = after(classified, context_entries[context_entries.len - 1].snip_idx);
    var suffix_emitted = false;
    if (hasMarker(trailing)) {
        emitPreservedSuffixWithReplacementSkipping(result, orig_lines, last_orig, trailing, snip_raw, context_entries[context_entries.len - 1]);
        suffix_emitted = true;
    }
    emitTrailingNewAndBlank(result, trailing, last_orig, snip_raw, orig_lines, &suffix_emitted);
    if (!suffix_emitted and !hasTrailingNew(trailing)) appendSlice(result, orig_lines[last_orig + 1 ..]);
    var merged = joinLines(result);
    if (endsWithNewline(original_func) and !endsWithNewline(merged)) merged = merged ++ "\n";
    return merged;
}
```
## Helper: context classification
1. `blank` = `trim(line).len == 0`.
2. `marker` = `_is_marker(line)`.
3. `context` = first exact `trim()` match in original at or after `orig_cursor`.
4. `new` = nonblank, nonmarker, no valid original match.
5. Ambiguous anchors (`}`, `{`, `end`, `]`, `)`, `];`, `});`, `else:`, `else {`, `else`, `pass`, `break`, `continue`, `return`, `return;`, `return None`, `return nil`, or non-whitespace length `< 4`) are skipped as anchors when later significant snippet lines still exist.
6. Context matching is order-preserving: once original index `oi` is used, later matches search from `oi + 1`.
7. Extra guard: if prior context exists, reject match when line-indent delta differs from expected by more than `2`.
## Helper: marker parsing
1. Raw marker detection is substring-based: any line containing one of:
   - `"... existing code ..."`
   - `"// ..."`
   - `"# ..."`
2. Canonical long forms also exist:
   - `"# ... existing code ..."`
   - `"// ... existing code ..."`
3. Short-form normalization accepts per-line stripped bodies:
   - `#...`
   - `//...`
   - `…` (U+2026)
   - spacing variants matched by `^\s*#\s*\.\.\.\s*$` and `^\s*//\s*\.\.\.\s*$`
4. Normalizer preserves indentation and newline terminator.
5. Marker line itself is removed from output.
6. Snippet split point:
   - lines before marker = `new_before`
   - lines after marker = `new_after`
   - marker line excluded
## Helper: `_resolve_symbol`
1. Input `name` + AST node list.
2. If `name` contains `.`:
   - split once into `class_name` and `method_name`.
   - return first node where `node.name == method_name` and `node.parent == class_name`.
3. Else:
   - return first node where `node.name == name`.
4. If no match, return `null`.
5. No fuzzy match, no qualified fallback beyond `Class.method`, no duplicate disambiguation.
## Helper: splice / indentation
1. `_adjust_indent`:
   - `indent_diff = effective_orig_indent - snip_indent`.
   - `effective_orig_indent = snip_indent` when anchor was shifted right; else original anchor indent.
   - `target_indent = max(0, curr_indent + indent_diff)`.
   - indent char = `\t` if new line starts with tab, else `\t` if reference original starts with tab, else space.
2. `_reindent_new_lines`:
   - base = smallest nonblank new-line indent.
   - each line keeps relative offset from base.
   - target indent = body indent from `_infer_body_indent`.
3. `_infer_body_indent`:
   - first indented nonblank original line determines `(indent_count, indent_char)`.
   - fallback `(4, " ")`.
4. Marker-mode preserved gap:
   - keep original gap lines.
   - compute `indent_delta` from marker-vs-context indent minus original-gap-vs-context indent.
   - shift nonblank gap lines right or left by `indent_delta`.
   - blank gap lines stay blank.
5. Replacement-key skipping:
   - `_replacement_key(line)` extracts left side of assignment-like lines.
   - in marker sections, skip exactly one gap line only when `(lhs, indent)` matches exactly one new line.
   - used to prevent duplicate replacement lines.
6. Trailing marker branch mirrors middle marker branch.
7. No-marker branch drops original gap lines and emits new lines + blanks only.
8. Preserve trailing newline from original.
## Helper: validation
1. `validate_parse(source, language)` does:
   - `tree = parse_code(source, language)`
   - return `!tree.root_node.has_error`
2. Post-splice policy for blitz port:
   - if language known and `validate_parse(merged, language) == false`, reject deterministic result and return `null`.
3. `detect_language(file_path)` uses file suffix mapping only.
4. Example mappings: `.py → python`, `.ts → typescript`, `.tsx → tsx`, `.rs → rust`, `.go → go`, `.js/.jsx → javascript`.
## Failure / fallback conditions
1. `context_entries.len < 2` and no zero-body-anchor marker position mode.
2. Any original gap between adjacent context anchors exceeds `max_drop_gap` with no marker in between.
3. Marker position mode has new lines on both sides of marker and no body anchors.
4. Marker position mode has flow-token overlap against original body tokens.
5. Marker position mode looks like genuine wrap-block (`marker_indent > opener_indent`) for top insertion.
6. Two or more markers in one section between adjacent anchors.
7. `_resolve_symbol` finds no node.
8. Post-splice parse validation fails.
## Test vectors
1. `test_simple_single_line_addition`
   - original:
     - `def foo():`
     - `    x = 1`
     - `    return x`
   - snippet adds `    y = 2` between context lines.
   - output contains `y = 2`, keeps `x = 1`, `return x`.
2. `test_replace_drops_gap_lines`
   - original `a = 1 / b = 2 / c = 3 / return a`
   - snippet `a = 1 / z = 99 / return a`
   - output contains `z = 99`, drops `b = 2`, `c = 3`.
3. `test_marker_preserves_gap_lines`
   - snippet uses `# ... existing code ...` between `a = 1` and `return a`.
   - output keeps `b = 2` and `c = 3`; marker line removed.
4. `test_marker_at_end_inserts_at_top`
   - zero body anchors, snippet ends with marker after `log.info(...)` / `audit.record(...)`.
   - output inserts new lines at top of body, before preserved body.
5. `test_python_parse_valid`
   - `validate_parse("def foo():\n  pass", "python") == true`
   - `validate_parse("def foo(:\n  pass", "python") == false`.
