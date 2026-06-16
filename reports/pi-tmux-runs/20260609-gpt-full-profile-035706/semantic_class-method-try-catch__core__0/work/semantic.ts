export async function loadUser(id: string): Promise<string> {
  const response = await fetch(`/api/users/${id}`);
  const payload = await response.json();
  return payload.name;
}

export class Scoreboard {
  renderScore(score: number): string {
    try {
      const rounded = Math.round(score);
      return `score:${rounded}`;
    } catch (error) {
      console.error(error);
      throw error;
    }
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
