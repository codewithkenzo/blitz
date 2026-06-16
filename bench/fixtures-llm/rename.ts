export function computeScore(data: number[]): number {
  if (data.length === 0) return 0;
  const total = data.reduce((a, b) => a + b, 0);
  const avg = total / data.length;
  return avg;
}
