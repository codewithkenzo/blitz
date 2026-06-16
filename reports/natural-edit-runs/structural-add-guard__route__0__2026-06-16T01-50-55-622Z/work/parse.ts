export function parseCount(input: string): number {
  const value = Number.parseInt(input, 10);
  return Number.isNaN(value) ? 0 : value;
}
