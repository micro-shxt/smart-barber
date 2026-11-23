export async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return null;
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    const { errors } = await import("../domain/errors/domainErrors.js");
    throw errors.validation("Request body must contain valid JSON");
  }
}
