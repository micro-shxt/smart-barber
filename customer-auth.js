(() => {
  const config = window.SMART_BARBER_CONFIG || {};
  const supabaseSdk = window.supabase;
  const client = config.supabaseUrl && config.supabasePublishableKey && supabaseSdk?.createClient
    ? supabaseSdk.createClient(config.supabaseUrl, config.supabasePublishableKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
    })
    : null;
  let user = null;
  let profileData = null;

  function showMessage(message, isError = false) {
    const target = document.querySelector("#customer-auth-message");
    if (target) {
      target.textContent = message;
      target.style.color = isError ? "#bc504d" : "#007f78";
    }
  }

  function open(mode = "signup") {
    const root = document.querySelector("#overlay-root");
    if (!root) return;
    const signingUp = mode === "signup";
    root.innerHTML = `<div class="overlay" id="customer-auth-overlay"><section class="modal canva-panel" role="dialog" aria-modal="true" aria-labelledby="customer-auth-title"><div class="modal-head"><div><div class="eyebrow">CUSTOMER ACCOUNT</div><h2 id="customer-auth-title">${signingUp ? "Create your account" : "Welcome back"}</h2></div><button type="button" class="icon-btn" data-customer-auth-close aria-label="Close">×</button></div><p class="muted">Explore freely. Sign in only when you want to save a profile or manage appointments.</p><form id="customer-auth-form" data-mode="${signingUp ? "signup" : "signin"}">${signingUp ? '<label class="field">Full name<input class="input" name="full_name" autocomplete="name" required maxlength="160"></label>' : ""}<label class="field">Email<input class="input" name="email" type="email" autocomplete="email" required></label><label class="field">Password<input class="input" name="password" type="password" autocomplete="${signingUp ? "new-password" : "current-password"}" minlength="8" required></label><button class="btn" type="submit">${signingUp ? "Create account" : "Sign in"}</button></form><div id="customer-auth-message" role="status" aria-live="polite"></div><button class="text-btn" type="button" data-customer-auth-switch>${signingUp ? "Already have an account? Sign in" : "New here? Create a customer account"}</button></section></div>`;
  }

  async function saveProfile(fullName) {
    if (!client || !user) throw new Error("Sign in is required.");
    const { error } = await client.from("customer_profiles").upsert(
      { user_id: user.id, full_name: fullName || user.user_metadata?.full_name || "" },
      { onConflict: "user_id" },
    );
    if (error) throw error;
    profileData = { ...(profileData || {}), full_name: fullName || user.user_metadata?.full_name || "" };
  }

  function mapBooking(row) {
    return {
      id: row.id,
      item_id: row.id,
      record_type: "customer_booking",
      tenant_id: row.provider_ref,
      name: user?.user_metadata?.full_name || "Customer",
      service: row.service_name,
      employee: row.employee,
      starts_at: row.starts_at,
      duration: row.duration_minutes,
      amount: Number(row.amount),
      status: row.status,
      details: row.details,
      created_at: row.created_at,
    };
  }

  window.customerAuth = {
    get user() { return user; },
    get profile() { return profileData; },
    async initialize() {
      if (!client) throw new Error("Supabase is not configured.");
      const { data, error } = await client.auth.getSession();
      if (error) throw error;
      user = data.session?.user ?? null;
      if (user) {
        const { data: savedProfile, error: profileError } = await client.from("customer_profiles")
          .select("full_name, preferences").eq("user_id", user.id).maybeSingle();
        if (profileError) throw profileError;
        profileData = savedProfile;
      } else profileData = null;
      return user;
    },
    open,
    async requireUser() {
      if (!user) {
        await this.initialize();
      }
      if (!user) open("signup");
      return Boolean(user);
    },
    async listBookings() {
      if (!(await this.requireUser())) return [];
      const { data, error } = await client.from("customer_bookings")
        .select("id, provider_ref, provider_name, service_name, starts_at, duration_minutes, employee, amount, status, details, created_at")
        .order("created_at", { ascending: false }).order("id", { ascending: false }).limit(100);
      if (error) throw error;
      return (data || []).map(mapBooking);
    },
    async saveBooking(record) {
      if (!(await this.requireUser())) return null;
      const provider = window.customerProviders?.find((item) => item.id === record.tenant_id);
      const values = {
        provider_ref: record.tenant_id,
        provider_name: provider?.name || "Studio",
        service_name: record.service,
        starts_at: record.starts_at,
        duration_minutes: record.duration,
        employee: record.employee,
        amount: record.amount,
        status: record.status === "Cancelled" ? "Cancelled" : "Pending",
        details: record.details || "",
      };
      const query = record.id
        ? client.from("customer_bookings").update(values).eq("id", record.id)
        : client.from("customer_bookings").insert({ ...values, user_id: user.id });
      const { data, error } = await query.select("id, provider_ref, provider_name, service_name, starts_at, duration_minutes, employee, amount, status, details, created_at").single();
      if (error) throw error;
      return mapBooking(data);
    },
    async cancelBooking(id) {
      if (!(await this.requireUser())) return false;
      const { error } = await client.from("customer_bookings").update({ status: "Cancelled" }).eq("id", id);
      if (error) throw error;
      return true;
    },
    async updateProfile(fullName) {
      if (!(await this.requireUser())) return false;
      await saveProfile(fullName);
      return true;
    },
    async signOut() {
      if (!client) return;
      const { error } = await client.auth.signOut({ scope: "local" });
      if (error) throw error;
      user = null;
      profileData = null;
    },
  };

  document.addEventListener("submit", async (event) => {
    if (event.target.id !== "customer-auth-form") return;
    event.preventDefault();
    const form = event.target;
    const button = form.querySelector("button[type=submit]");
    const values = new FormData(form);
    button.disabled = true;
    showMessage("Working…");
    try {
      if (!client) throw new Error("Supabase is not configured. Contact the site administrator.");
      if (form.dataset.mode === "signup") {
        const fullName = String(values.get("full_name") || "").trim();
        const { data, error } = await client.auth.signUp({
          email: String(values.get("email") || "").trim(),
          password: String(values.get("password") || ""),
          options: { data: { full_name: fullName } },
        });
        if (error) throw error;
        user = data.session?.user ?? null;
        if (user) {
          await saveProfile(fullName);
          document.querySelector("#overlay-root").innerHTML = "";
          window.dispatchEvent(new CustomEvent("customer-auth-changed"));
        } else {
          showMessage("Check your email to confirm your account, then sign in.");
        }
      } else {
        const { data, error } = await client.auth.signInWithPassword({
          email: String(values.get("email") || "").trim(),
          password: String(values.get("password") || ""),
        });
        if (error) throw error;
        user = data.session?.user ?? null;
        if (user) await saveProfile(user.user_metadata?.full_name || "");
        document.querySelector("#overlay-root").innerHTML = "";
        window.dispatchEvent(new CustomEvent("customer-auth-changed"));
      }
    } catch (error) {
      showMessage(error.message || "Could not complete sign-in.", true);
    } finally {
      button.disabled = false;
    }
  });

  document.addEventListener("click", (event) => {
    if (event.target.closest("[data-customer-auth-close]") || event.target.id === "customer-auth-overlay") {
      document.querySelector("#overlay-root").innerHTML = "";
    }
    if (event.target.closest("[data-customer-auth-switch]")) {
      const signup = document.querySelector("#customer-auth-form")?.dataset.mode !== "signup";
      open(signup ? "signup" : "signin");
    }
  });
})();
