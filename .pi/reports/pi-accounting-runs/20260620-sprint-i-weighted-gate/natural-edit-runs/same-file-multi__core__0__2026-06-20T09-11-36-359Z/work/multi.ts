export function adjust(value: number): number {
  const base = value;
  return base + 1;
}

export function emit(value: string): string {
  const marker = value;
  const markerUpper = value.toUpperCase();
  return marker;
}

export function risky(value: number): number {
  try {
    return value;
  } catch (error) {
    throw error;
  }
}
