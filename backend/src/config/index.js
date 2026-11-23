export function loadConfig(env = globalThis.process?.env ?? {}) {
  return Object.freeze({
    port: Number(env.PORT || 3001),
    timezone: "Africa/Johannesburg",
    currency: "ZAR",
    mockAuthEnabled: env.MOCK_AUTH_ENABLED !== "false"
  });
}
