import { createApplication } from "./app.js";

const { server, config } = createApplication();
server.listen(config.port, () => {
  console.log(`Smart Barber backend listening on http://localhost:${config.port}`);
});
