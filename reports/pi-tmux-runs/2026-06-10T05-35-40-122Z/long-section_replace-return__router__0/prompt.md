Use only `pi_blitz_route_edit`. Copy exact args JSON. Do not call other pi_blitz_* tools. Use route preference `blitz` for executable Blitz rows. For this exact unique return-line edit, call `pi_blitz_route_edit` with exact args JSON: {"f":"/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-10T05-35-40-122Z/long-section_replace-return__router__0/work/long-section.ts","r":"blitz","s":"ru\t  return `Invoice ${id} for ${customer}: $0.00`;\t  return `Invoice ${id} for ${customer}: $${total.toFixed(2)}`;","fallbackContextTokensExpected":5000}.

Apply this change to the file at /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-10T05-35-40-122Z/long-section_replace-return__router__0/work/long-section.ts. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: replace the return statement at the end from `return `Invoice ${id} for ${customer}: $0.00`;` to `return `Invoice ${id} for ${customer}: $${total.toFixed(2)}`;`.
Original file contents:
export function processInvoice(data: Record<string, unknown>): string {
  console.log("Starting invoice processing");
  const { id, items, customer, address, notes } = data as Record<string, string>;
  const subtotal = 0;
  const taxRate = 0.08;
  const shipping = 5.99;
  const discount = 0;

  // Calculate subtotal from items
  for (let i = 0; i < 20; i++) {
    const foo = i * 2;
    const bar = foo + 1;
    const baz = bar * 3;
    const qux = baz - 4;
    void qux;
  }

  // Apply shipping logic
  const freeShipping = false;

  // Validate invoice
  if (!id || !customer) {
    throw new Error("Missing required fields");
  }

  return `Invoice ${id} for ${customer}: $0.00`;
}
