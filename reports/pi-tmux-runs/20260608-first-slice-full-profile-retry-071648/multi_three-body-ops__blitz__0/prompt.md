Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`. For this edit, call `pi_blitz_multi_body`. Exact tool args JSON: {"edits":[{"symbol":"adjust","op":"replace_body_span","find":"return base;","replace":"return base + 1;","occurrence":"only"},{"symbol":"emit","op":"insert_body_span","anchor":"const marker = value;","position":"after","text":"\n  const markerUpper = value.toUpperCase();","occurrence":"only"},{"symbol":"risky","op":"wrap_body","before":"\n  try {","keep":"body","after":"  } catch (error) {\n    throw error;\n  }\n","indentKeptBodyBy":2}]}. JSON escapes must decode to newline characters; do not pass literal backslash-n text. Emit insert text starts with newline escape `\n`; risky `after` MUST end with newline escape `\n`.

Apply this change to the file at reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648/multi_three-body-ops__blitz__0/work/multi.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: make three edits in the same file:
1) in adjust, replace the final return statement with `return base + 1;`,
2) in emit, insert `const markerUpper = value.toUpperCase();` immediately after `const marker = value;`,
3) in risky, wrap the function body in try/catch and rethrow error.

Original file contents:
export function adjust(value: number): number {
  const base = value;
  return base;
}

export function emit(value: string): string {
  const marker = value;
  return marker;
}

export function risky(value: number): number {
  return value;
}
