Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`. For this edit, call `pi_blitz_replace_return` with symbol `pickLabel`, occurrence `last`. IMPORTANT: `expr` must be JSON string value containing the quoted TypeScript string literal, not identifier text. Exact one-line tool args JSON: {"symbol":"pickLabel","expr":"\"unknown\"","occurrence":"last"}.

Apply this change to the file at reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648/semantic_arrow-replace-return__blitz__0/work/semantic.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: in arrow function pickLabel, replace the last return expression with "unknown". Leave the earlier active return unchanged.

Original file contents:
export async function loadUser(id: string): Promise<string> {
  const response = await fetch(`/api/users/${id}`);
  const payload = await response.json();
  return payload.name;
}

export class Scoreboard {
  renderScore(score: number): string {
    const rounded = Math.round(score);
    return `score:${rounded}`;
  }
}

export const pickLabel = (active: boolean): string => {
  if (active) {
    return "active";
  }
  return "idle";
};

export function classify(value: number): string {
  if (value < 0) {
    return "negative";
  }
  if (value === 0) {
    return "zero";
  }
  return "positive";
}
