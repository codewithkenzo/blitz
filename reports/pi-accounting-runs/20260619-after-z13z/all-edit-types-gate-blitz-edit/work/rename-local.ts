export function total(items: number[]): number {
  const totalValue = items.reduce((acc, item) => acc + item, 0);
  return totalValue;
}
