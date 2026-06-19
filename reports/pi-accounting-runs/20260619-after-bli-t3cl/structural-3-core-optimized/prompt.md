Run 3 ordered edits in this one Pi session.
Use only edit. No prose. Keep calling tools until every step is done. Then stop.

Steps:
1. Call edit with exact JSON: {"path":"/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/structural-3-core-optimized/work/structural.ts","oldText":"const doubled = value * 2;\n  return doubled","newText":"return value + 1"}
2. Call edit with exact JSON: {"path":"/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/structural-3-core-optimized/work/structural.ts","oldText":"\"old\"","newText":"\"new\""}
3. Call edit with exact JSON: {"path":"/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/structural-3-core-optimized/work/structural.ts","oldText":"  return \"new\";\n}\n","newText":"  return \"new\";\n}\n\nexport function gamma(): boolean { return true; }\n"}

Initial file contents:
--- /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/structural-3-core-optimized/work/structural.ts ---
export function alpha(value: number): number {
  const doubled = value * 2;
  return doubled;
}

export function beta(): string {
  return "old";
}
