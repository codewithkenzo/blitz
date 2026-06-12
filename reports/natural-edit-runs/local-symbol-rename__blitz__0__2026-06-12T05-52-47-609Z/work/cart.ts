export function calculateCart(items: number[]) {
  const itemTotal = items.reduce((sum, item) => sum + item, 0);
  return subtotal * 1.2;
}
