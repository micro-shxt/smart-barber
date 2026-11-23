export class ApiError extends Error {
  constructor(message, status, code) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code = code;
  }
}

const baseUrl = import.meta.env?.VITE_API_BASE_URL || "http://localhost:3001";
const apiPrefix = "/api/v1";

export function createApiClient({ headers = {}, onLoading = () => {} } = {}) {
  let loading = false;

  async function request(method, path, { body, headers: requestHeaders } = {}) {
    loading = true;
    onLoading(loading);
    try {
      const response = await fetch(`${baseUrl}${apiPrefix}${path}`, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...headers,
          ...requestHeaders
        },
        body: body === undefined ? undefined : JSON.stringify(body)
      });
      let payload;
      try {
        payload = await response.json();
      } catch {
        throw new ApiError("The server returned an invalid response", response.status, "INVALID_RESPONSE");
      }
      if (!response.ok) {
        throw new ApiError(payload?.error?.message || "The request failed", response.status, payload?.error?.code);
      }
      return payload.data;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError("Could not reach the Smart Barber API", 0, "NETWORK_ERROR");
    } finally {
      loading = false;
      onLoading(loading);
    }
  }

  return {
    get: (path, options) => request("GET", path, options),
    post: (path, body, options) => request("POST", path, { ...options, body }),
    patch: (path, body, options) => request("PATCH", path, { ...options, body }),
    isLoading: () => loading
  };
}
