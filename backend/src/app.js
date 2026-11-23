import { loadConfig } from "./config/index.js";
import { InMemoryRepository } from "./repositories/memory/inMemoryRepository.js";
import { SupabaseRepository } from "./repositories/supabase/supabaseRepository.js";
import { MockIdentityProvider, SupabaseIdentityProvider } from "./middleware/auth.js";
import { sendError } from "./middleware/errors.js";
import { MarketplaceService } from "./services/MarketplaceService.js";
import { AvailabilityService } from "./services/AvailabilityService.js";
import { AppointmentService } from "./services/AppointmentService.js";
import { ApiController } from "./controllers/ApiController.js";
import { createRouter } from "./routes/apiRoutes.js";
import { readJson } from "./utils/http.js";
import { errors } from "./domain/errors/domainErrors.js";

export function createApplication(options = {}) {
  const config = options.config ?? loadConfig();
  let repository = options.repository;
  if (!repository) {
    if (config.repositoryType === "supabase") {
      repository = new SupabaseRepository({
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey
      });
    } else {
      repository = new InMemoryRepository();
    }
  }
  let identityProvider = options.identityProvider;
  if (!identityProvider) {
    if (config.environment === "production" && config.identityProviderType !== "supabase") {
      throw new Error("Production requires a Supabase identity provider");
    }
    if (config.identityProviderType === "supabase") {
      identityProvider = new SupabaseIdentityProvider({
        repository,
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey
      });
    } else if (!config.mockAuthEnabled) {
      throw new Error("Mock authentication is disabled and no trusted identity provider is configured");
    } else {
      identityProvider = new MockIdentityProvider(repository, { enabled: true });
    }
  }
  const marketplace = new MarketplaceService(repository);
  const availability = new AvailabilityService(repository);
  const appointments = new AppointmentService(repository);
  const controller = new ApiController({ marketplace, availability, appointments, identityProvider });
  const routes = createRouter(controller);

  async function handleRequest(req, res) {
    const origin = req.headers.origin;
    if (origin && config.allowedOrigins.includes(origin)) {
      res.setHeader("Access-Control-Allow-Origin", origin);
      res.setHeader("Vary", "Origin");
    } else if (origin) {
      res.statusCode = 403;
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({ success: false, error: { code: "FORBIDDEN", message: "Origin is not allowed" } }));
      return;
    }
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,OPTIONS");
    if (req.method === "OPTIONS") { res.statusCode = 204; res.end(); return; }

    try {
      const url = new URL(req.url, "http://localhost");
      if (req.method === "GET" && url.pathname === "/health") {
        res.setHeader("Content-Type", "application/json");
        res.end(JSON.stringify({ success: true, data: { status: "ok", timezone: config.timezone, mode: "memory" }, message: "Backend is running" }));
        return;
      }
      const route = routes.find((candidate) => candidate.method === req.method && candidate.pattern.test(url.pathname));
      if (!route) {
        const methodAllowed = routes.some((candidate) => candidate.pattern.test(url.pathname));
        throw methodAllowed ? errors.methodNotAllowed("Method not allowed") : errors.notFound("Endpoint not found");
      }
      if (req.method === "POST" || req.method === "PATCH") {
        const contentType = req.headers["content-type"];
        const contentLength = Number(req.headers["content-length"] || 0);
        if (req.method === "POST" && contentLength > 0 && (!contentType || !contentType.toLowerCase().startsWith("application/json"))) {
          throw errors.validation("Content-Type must be application/json");
        }
        if (req.method === "PATCH" && contentType && !contentType.toLowerCase().startsWith("application/json")) {
          throw errors.validation("Content-Type must be application/json");
        }
      }
      let body = null;
      if (req.method === "POST" || req.method === "PATCH") body = await readJson(req, config.maxRequestBodyBytes);
      const match = url.pathname.match(route.pattern);
      const query = Object.fromEntries(url.searchParams.entries());
      await route.handler(req, res, match, query, body);
    } catch (error) {
      sendError(res, error);
    }
  }

  return { handleRequest, repository, config };
}
