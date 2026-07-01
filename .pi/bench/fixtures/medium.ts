function handleRequest(req: Request): Response {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method.toUpperCase();

  if (method !== "GET" && method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (path === "/health") {
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  if (path.startsWith("/api/")) {
    return new Response("api stub", { status: 200 });
  }

  return new Response("not found", { status: 404 });
}
