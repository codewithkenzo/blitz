export function adjust(value: number): number {
  const base = value;
  return base + 1;
}

export function emit(value: string): string {
  const marker = value;
  return marker;
  const markerUpper = value.toUpperCase();
}

export function risky(value: number): number {
  try {
    return value;
  } catch (error) {
    throw error;
  }
}
