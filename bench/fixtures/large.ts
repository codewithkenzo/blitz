function processBatch(items: ReadonlyArray<{ id: string; payload: unknown }>): Map<string, BatchResult> {
  const results = new Map<string, BatchResult>();
  const startTime = performance.now();

  for (const item of items) {
    if (!item.id) {
      results.set(crypto.randomUUID(), {
        ok: false,
        error: "missing id",
        durationMs: 0,
      });
      continue;
    }

    if (item.payload === null || item.payload === undefined) {
      results.set(item.id, {
        ok: false,
        error: "missing payload",
        durationMs: 0,
      });
      continue;
    }

    const itemStart = performance.now();
    try {
      const validated = validate(item.payload);
      const transformed = transform(validated);
      const enriched = enrich(transformed);
      const persisted = persist(item.id, enriched);

      results.set(item.id, {
        ok: true,
        value: persisted,
        durationMs: performance.now() - itemStart,
      });
    } catch (err) {
      results.set(item.id, {
        ok: false,
        error: err instanceof Error ? err.message : String(err),
        durationMs: performance.now() - itemStart,
      });
    }
  }

  const totalDuration = performance.now() - startTime;
  console.log(`[processBatch] ${items.length} items in ${totalDuration.toFixed(2)}ms`);
  return results;
}

interface BatchResult {
  ok: boolean;
  value?: unknown;
  error?: string;
  durationMs: number;
}

declare function validate(payload: unknown): unknown;
declare function transform(value: unknown): unknown;
declare function enrich(value: unknown): unknown;
declare function persist(id: string, value: unknown): unknown;
