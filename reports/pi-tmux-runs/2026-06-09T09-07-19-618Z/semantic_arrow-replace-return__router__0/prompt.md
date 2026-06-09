Use only `pi_blitz_route_edit`. Copy exact args JSON. Do not call other pi_blitz_* tools. Use route preference `blitz` for executable Blitz rows. For this edit, call `pi_blitz_route_edit` with exact args JSON: {"f":"/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T09-07-19-618Z/semantic_arrow-replace-return__router__0/work/semantic.ts","r":"blitz","s":"rr\tpickLabel\t\"unknown\"\tlast","fallbackContextTokensExpected":5000}.

Apply this change to the file at /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T09-07-19-618Z/semantic_arrow-replace-return__router__0/work/semantic.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

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
