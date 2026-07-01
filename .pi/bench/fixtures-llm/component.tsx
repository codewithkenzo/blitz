export function StatusBadge({ status }: { status: string }) {
  const label = status.trim();
  return <span className="badge">{label}</span>;
}
