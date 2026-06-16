const normalizeName = (value: string) => value.trim();

export function displayName(name: string) {
  return normalizeName(name).toUpperCase();
}
