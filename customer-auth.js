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
      provider_name: row.provider_name,
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
      await this.loadDirectory();
      return user;
    },
    async loadDirectory() {
      if (!client) throw new Error("Supabase is not configured.");
      const { data, error } = await client.rpc("customer_public_directory");
      if (error) throw error;
      const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      const entries = (data || []).map((item) => {
        const hours = (item.hours || []).filter((row) => !row.closed);
        return {
          id: item.id, slug: item.slug, name: item.name, category: item.category,
          city: item.city, area: item.area, timezone: item.timezone,
          rating: Number(item.rating), reviews: Number(item.reviews), distance: "Local studio",
          next: item.is_demo ? "Demo listing" : "Choose a date to see available times",
          image: item.image, portfolio: item.portfolio || [], description: item.description,
          hours: hours.length ? hours.map((row) => `${dayNames[row.weekday - 1]} ${String(row.opens_at).slice(0, 5)}–${String(row.closes_at).slice(0, 5)}`).join(" · ") : "Hours not listed",
          hoursData: item.hours || [], team: item.team || [], isDemo: item.is_demo,
          services: (item.services || []).map((service) => [service.name, Number(service.price), Number(service.duration), service.description || "", service.id]),
        };
      });
      window.customerProviders.splice(0, window.customerProviders.length, ...entries);
      window.dispatchEvent(new CustomEvent("customer-directory-loaded"));
      return entries;
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
    async getAvailableSlots({ providerId, serviceId, date, employee = "Any available" }) {
      const { data, error } = await client.rpc("customer_available_slots", {
        p_provider_id: providerId, p_service_id: serviceId, p_date: date, p_employee: employee,
      });
      if (error) throw error;
      return data || [];
    },
    async saveBooking(record) {
      if (!(await this.requireUser())) return null;
      const { data, error } = await client.rpc("customer_create_booking", {
        p_provider_id: record.tenant_id,
        p_service_id: record.service_id,
        p_starts_at: record.starts_at,
        p_employee: record.employee || "Any available",
      });
      if (error) throw error;
      const saved = Array.isArray(data) ? data[0] : data;
      return saved ? mapBooking(saved) : null;
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
