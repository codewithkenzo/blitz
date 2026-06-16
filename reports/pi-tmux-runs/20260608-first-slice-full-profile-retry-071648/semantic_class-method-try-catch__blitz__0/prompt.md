Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`. For this edit, call `pi_blitz_try_catch`. Exact tool args JSON: {"symbol":"renderScore","catchBody":"console.error(error);\nthrow error;","indent":2}. JSON escape must decode to a newline character; do not pass catchBody as one line.

Apply this change to the file at reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648/semantic_class-method-try-catch__blitz__0/work/semantic.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: wrap the entire body of class method renderScore in try/catch. Catch should call console.error(error); then throw error on the next line.

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
