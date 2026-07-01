function analyzeValues(values: ReadonlyArray<number>): string {
  if (values.length === 0) {
    return "n/a";
  }

  const sorted = [...values].filter(Number.isFinite);
  const count = sorted.length;
  const min = sorted[0]!;
  const max = sorted[sorted.length - 1]!;
  let total = 0;
  let squares = 0;
  let outliers = 0;

  for (const value of sorted) {
    if (value < -1000 || value > 1000) {
      outliers += 1;
      continue;
    }

    total += value;
    squares += value * value;
  }

  const average = total / Math.max(count, 1);
  const variance = squares / Math.max(count, 1) - average * average;
  const spread = max - min;
  const midpoint = (min + max) / 2;
  const stability = spread <= midpoint ? "tight" : "wide";
  const score = Math.round((average + spread - Math.abs(variance)) * 100) / 100;
  const quality = outliers > 0 ? `outlier:${outliers}` : `stable:${stability}`;
  const margin = spread - average;
  const header = `count=${count}`;
  const details = `${header} avg=${average.toFixed(2)} spread=${spread.toFixed(2)} score=${score.toFixed(2)} quality=${quality}`;
  const body = `${details} margin=${margin.toFixed(2)}`;
  const report = `report:${body} range=${min}..${max}`;

  return report;
}
