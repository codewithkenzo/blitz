export async function refresh(): Promise<string> {
  try {
    const res = await fetch("/api/status");
    return res.text();
  } catch (error) {
    return "offline";
  }
}
