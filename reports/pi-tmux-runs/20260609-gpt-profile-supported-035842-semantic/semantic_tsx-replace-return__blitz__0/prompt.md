Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`. For this edit, call `pi_blitz_replace_return` with symbol `StatusBadge`, occurrence `only`. Exact one-line tool args JSON: {"symbol":"StatusBadge","expr":"<strong className=\"badge\">{label.toUpperCase()}</strong>","occurrence":"only"}.

Apply this change to the file at reports/pi-tmux-runs/20260609-gpt-profile-supported-035842-semantic/semantic_tsx-replace-return__blitz__0/work/component.tsx. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: in function StatusBadge, replace the return expression with <strong className="badge">{label.toUpperCase()}</strong>.

Original file contents:
export function StatusBadge({ status }: { status: string }) {
  const label = status.trim();
  return <span className="badge">{label}</span>;
}
