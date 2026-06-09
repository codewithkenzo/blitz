export async function loadUser(id: string): Promise<string> {
  try {
    const response = await fetch(`/api/users/${id}`);
    const payload = await response.json();
    return payload.name;
  } catch (error) {
    console.error(error);
    throw error;
  }
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
