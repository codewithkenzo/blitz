export function StatusBadge({ status }: { status: string }) {
  const label = status.trim();
  return <strong className="badge">{label.toUpperCase()}</strong>;
}
