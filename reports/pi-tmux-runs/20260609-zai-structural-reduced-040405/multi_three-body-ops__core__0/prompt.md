Apply this change to the file at reports/pi-tmux-runs/20260609-zai-structural-reduced-040405/multi_three-body-ops__core__0/work/multi.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

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
