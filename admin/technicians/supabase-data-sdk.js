(function () {
  const config = window.SMART_BARBER_CONFIG || {};
  const sdk = window.supabase;
  let client = null;
  let changeHandler = null;
  let realtimeChannel = null;

  function error(message, reason) {
    return { isOk: false, reason, error: new Error(message) };
  }

  function ensureClient() {
    if (!config.supabaseUrl || !config.supabasePublishableKey || !sdk?.createClient) {
      return error("Supabase has not been configured.", "CONFIG_REQUIRED");
    }
    if (!client) {
      client = sdk.createClient(config.supabaseUrl, config.supabasePublishableKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
      });
      window.smartBarberSupabase = client;
    }
    return { isOk: true };
  }

  function toUiRecord(row) {
    return {
      ...row,
      __backendId: row.id,
      record_type: "business",
      plan: row.plan_code ? row.plan_code.charAt(0).toUpperCase() + row.plan_code.slice(1) : "",
      locations: row.locations_count || 1,
      appointments: 0,
      saved: true,
    };
  }

  async function loadBusinesses() {
    const result = await client
      .from("businesses")
      .select("id, name, category, city, contact_email, plan_code, status, notes, locations_count, created_at, updated_at")
      .order("created_at", { ascending: false });
    if (result.error) return result;
    return { data: (result.data || []).map(toUiRecord), error: null };
  }

  async function refresh() {
    const result = await loadBusinesses();
    if (!result.error) changeHandler?.(result.data);
    return result;
  }

  function planCode(value) {
    return String(value || "").trim().toLowerCase();
  }

  window.dataSdk = {
    async init(options) {
      changeHandler = options?.onDataChanged;
      const clientResult = ensureClient();
      if (!clientResult.isOk) return clientResult;

      const sessionResult = await client.auth.getSession();
      if (sessionResult.error || !sessionResult.data.session) return error("Sign-in is required.", "AUTH_REQUIRED");

      const rolesResult = await client
        .from("user_roles")
        .select("role")
        .eq("user_id", sessionResult.data.session.user.id)
        .eq("active", true);
      if (rolesResult.error) return error("Could not verify administrator access.", "ADMIN_REQUIRED");
      if (!(rolesResult.data || []).some((item) => item.role === "platform_admin")) {
        await client.auth.signOut();
        return error("Platform administrator access is required.", "ADMIN_REQUIRED");
      }

      const result = await refresh();
      if (result.error) return error("Could not load saved business data.", "DATA_UNAVAILABLE");

      document.querySelector(".app")?.style.setProperty("visibility", "visible");

      realtimeChannel = client
        .channel("admin-businesses")
        .on("postgres_changes", { event: "*", schema: "public", table: "businesses" }, refresh)
        .subscribe();
      return { isOk: true };
    },

    async create(record) {
      const clientResult = ensureClient();
      if (!clientResult.isOk) return clientResult;
      const result = await client.rpc("submit_business_application", {
        p_name: record.name,
        p_category: record.category,
        p_city: record.city,
        p_contact_email: record.contact_email,
        p_plan_code: planCode(record.plan),
        p_notes: record.notes || "",
      });
      if (result.error) return { isOk: false, error: result.error };
      await refresh();
      return { isOk: true, data: result.data };
    },

    async update(record) {
      const clientResult = ensureClient();
      if (!clientResult.isOk) return clientResult;
      const result = await client.rpc("admin_update_business", {
        p_business_id: record.__backendId,
        p_status: record.status || null,
        p_plan_code: record.plan ? planCode(record.plan) : null,
      });
      if (result.error) return { isOk: false, error: result.error };
      await refresh();
      return { isOk: true, data: result.data };
    },

    async signOut() {
      if (realtimeChannel) await client?.removeChannel(realtimeChannel);
      return client?.auth.signOut({ scope: "local" });
    },
  };
})();
