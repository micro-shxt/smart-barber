import http from "node:http";
import { loadConfig } from "./config/index.js";
import { InMemoryRepository } from "./repositories/memory/inMemoryRepository.js";
import { MockIdentityProvider } from "./middleware/auth.js";
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
  const repository = options.repository ?? new InMemoryRepository();
  const identityProvider = options.identityProvider ?? new MockIdentityProvider(repository);
  const marketplace = new MarketplaceService(repository);
  const availability = new AvailabilityService(repository);
  const appointments = new AppointmentService(repository);
  const controller = new ApiController({ marketplace, availability, appointments, identityProvider });
  const routes = createRouter(controller);

  const server = http.createServer(async (req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-User-Id, X-Tenant-Id");
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
      if (!route) throw errors.notFound("Endpoint not found");
      let body = null;
      if (req.method === "POST" || req.method === "PATCH") body = await readJson(req);
      const match = url.pathname.match(route.pattern);
      const query = Object.fromEntries(url.searchParams.entries());
      await route.handler(req, res, match, query, body);
    } catch (error) {
      sendError(res, error);
    }
  });

  return { server, repository, config };
}
