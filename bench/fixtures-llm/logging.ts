export function processOrder(orderId: string, amount: number): string {
  console.log(`Processing order ${orderId}`);
  const discounted = amount > 100 ? amount * 0.9 : amount;
  const tax = discounted * 0.08;
  const total = discounted + tax;
  return `Order ${orderId}: $${total.toFixed(2)}`;
}
