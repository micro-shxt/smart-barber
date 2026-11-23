export async function handleWebRequest(request, application) {
  const url = new URL(request.url);
  const bodyText = request.method === "GET" || request.method === "HEAD" ? null : await request.text();
  const headers = Object.fromEntries(request.headers.entries());
  const req = {
    method: request.method,
    url: `${url.pathname}${url.search}`,
    headers,
    async *[Symbol.asyncIterator]() {
      if (bodyText) yield new TextEncoder().encode(bodyText);
    }
  };
  let statusCode = 200;
  const responseHeaders = new Map();
  const res = {
    statusCode,
    setHeader(name, value) { responseHeaders.set(name.toLowerCase(), String(value)); },
    get statusCode() { return statusCode; },
    set statusCode(value) { statusCode = value; },
    end(body = "") {
      this.body = body;
    }
  };
  await application.handleRequest(req, res);
  return new Response(res.body || "", {
    status: statusCode,
    headers: Object.fromEntries(responseHeaders)
  });
}

export function createWorkerFetch(createApplication) {
  return async function fetch(request, env) {
    const config = {
      port: 3001,
      timezone: "Africa/Johannesburg",
      currency: "ZAR",
      mockAuthEnabled: env.MOCK_AUTH_ENABLED !== "false",
      identityProviderType: env.IDENTITY_PROVIDER_TYPE || "development-mock",
      allowedOrigins: (env.CORS_ALLOWED_ORIGINS || "*").split(",").map((value) => value.trim()).filter(Boolean),
      maxRequestBodyBytes: Number(env.MAX_REQUEST_BODY_BYTES || 1048576)
    };
    const application = createApplication({ config });
    return handleWebRequest(request, application);
  };
}
