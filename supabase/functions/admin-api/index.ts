import { withSupabase } from "npm:@supabase/server@1";

function corsHeaders(request: Request) {
  const configuredOrigin = Deno.env.get("ADMIN_ALLOWED_ORIGIN") ?? "http://127.0.0.1:3000";
  const requestOrigin = request.headers.get("origin");
  const origin = requestOrigin === configuredOrigin ? requestOrigin : configuredOrigin;
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Vary": "Origin",
    "Content-Type": "application/json",
  };
}

function json(request: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(request) });
}

async function readJson(request: Request) {
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > 32_768) throw new Error("Request payload is too large");
  const body = await request.json();
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Request body must be a JSON object");
  }
  return body as Record<string, unknown>;
}

async function requirePlatformAdmin(ctx: any) {
  const userId = ctx.userClaims?.sub;
  if (!userId) return false;
  const { data, error } = await ctx.supabase
    .from("user_roles")
    .select("role")
    .eq("user_id", userId)
    .eq("active", true);
  if (error) throw error;
  return data?.some((role: { role: string }) => role.role === "platform_admin") ?? false;
}

async function getDashboardSummary(ctx: any) {
  const results = await Promise.all([
    ctx.supabase.from("businesses").select("id", { count: "exact", head: true }),
    ctx.supabase.from("businesses").select("id", { count: "exact", head: true }).eq("status", "Active"),
    ctx.supabase.from("business_applications").select("id", { count: "exact", head: true }).eq("status", "Pending"),
    ctx.supabase.from("subscriptions").select("id", { count: "exact", head: true }).in("status", ["Trialing", "Active", "Past due"]),
    ctx.supabase.from("customers").select("id", { count: "exact", head: true }).eq("status", "Active"),
    ctx.supabase.from("appointments").select("id", { count: "exact", head: true }),
    ctx.supabase.from("support_tickets").select("id", { count: "exact", head: true }).in("status", ["Open", "Review"]),
  ]);
  const failed = results.find((result) => result.error);
  if (failed?.error) throw failed.error;
  const [businesses, activeBusinesses, pendingApplications, subscriptions, customers, appointments, tickets] = results;
  return {
    businesses: businesses.count ?? 0,
    activeBusinesses: activeBusinesses.count ?? 0,
    pendingApplications: pendingApplications.count ?? 0,
    activeSubscriptions: subscriptions.count ?? 0,
    activeCustomers: customers.count ?? 0,
    appointments: appointments.count ?? 0,
    openTickets: tickets.count ?? 0,
  };
}

export default {
  fetch: withSupabase({ auth: "user" }, async (request: Request, ctx: any) => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(request) });

    try {
      if (!(await requirePlatformAdmin(ctx))) {
        return json(request, { error: "Platform administrator role required" }, 403);
      }

      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname.endsWith("/dashboard")) {
        return json(request, { data: await getDashboardSummary(ctx) });
      }

      if (request.method === "POST" && url.pathname.endsWith("/businesses/application")) {
        const body = await readJson(request);
        const { data, error } = await ctx.supabase.rpc("submit_business_application", {
          p_name: body.name,
          p_category: body.category,
          p_city: body.city,
          p_contact_email: body.contact_email,
          p_plan_code: body.plan_code,
          p_notes: body.notes ?? "",
        });
        if (error) throw error;
        return json(request, { data }, 201);
      }

      if (request.method === "POST" && url.pathname.endsWith("/businesses/update")) {
        const body = await readJson(request);
        const { data, error } = await ctx.supabase.rpc("admin_update_business", {
          p_business_id: body.business_id,
          p_status: body.status ?? null,
          p_plan_code: body.plan_code ?? null,
        });
        if (error) throw error;
        return json(request, { data });
      }

      return json(request, { error: "Route not found" }, 404);
    } catch (error) {
      console.error("admin-api request failed", error);
      return json(request, { error: "Request could not be completed" }, 400);
    }
  }),
};
