export function sum(values: number[]) {
  const seen: number[] = [];
  let total = 0;
  for (const value of values) {
    seen.push(value);
    total += value;
  }
  return { total, seen };
}
