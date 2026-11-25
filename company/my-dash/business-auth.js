(() => {
  const config = window.SMART_BARBER_CONFIG || {};
  const client = window.supabase?.createClient && config.supabaseUrl && config.supabasePublishableKey
    ? window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
    : null;

  async function activeMembership() {
    if (!client) throw new Error("Supabase is not configured.");
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) throw sessionError;
    if (!sessionData.session) return { user: null, membership: null };
    const { data, error } = await client.from("business_memberships")
      .select("business_id, role, businesses(name)")
      .eq("user_id", sessionData.session.user.id)
      .eq("active", true)
      .order("created_at", { ascending: true })
      .limit(1);
    if (error) throw error;
    return { user: sessionData.session.user, membership: data?.[0] || null };
  }

  window.businessAuth = {
    client,
    activeMembership,
    async guard() {
      const result = await activeMembership();
      if (!result.user || !result.membership) {
        window.location.replace("./login.html?denied=" + (result.user ? "1" : "0"));
        return null;
      }
      return result;
    },
  };
})();
