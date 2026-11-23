import http from "node:http";
import { pathToFileURL } from "node:url";
import { createApplication } from "./app.js";

export function createNodeServer(application) {
  return http.createServer((req, res) => {
    application.handleRequest(req, res).catch((error) => {
      res.statusCode = 500;
      res.setHeader("Content-Type", "application/json");
      res.end(JSON.stringify({ success: false, error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred" } }));
    });
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const application = createApplication();
  const { config } = application;
  const server = createNodeServer(application);
  server.listen(config.port, () => {
    console.log(`Smart Barber backend listening on http://localhost:${config.port}`);
  });
}
