export function loadConfig(env = globalThis.process?.env ?? {}) {
  const allowedOrigins = (env.CORS_ALLOWED_ORIGINS || "http://localhost:5173,http://localhost:5174,http://localhost:5175")
    .split(",").map((value) => value.trim()).filter(Boolean);
  return Object.freeze({
    port: Number(env.PORT || 3001),
    timezone: "Africa/Johannesburg",
    currency: "ZAR",
    mockAuthEnabled: env.MOCK_AUTH_ENABLED !== "false",
    identityProviderType: env.IDENTITY_PROVIDER_TYPE || "development-mock",
    allowedOrigins,
    maxRequestBodyBytes: Number(env.MAX_REQUEST_BODY_BYTES || 1048576)
  });
}
