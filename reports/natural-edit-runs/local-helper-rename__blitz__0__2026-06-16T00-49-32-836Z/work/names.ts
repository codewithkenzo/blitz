const cleanName = (value: string) => value.trim();

export function displayName(name: string) {
  return cleanName(name).toUpperCase();
}
