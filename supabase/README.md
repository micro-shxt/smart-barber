# Smart Barber Supabase backend

This directory contains the database migration, RLS policies, audit triggers, and the authenticated `admin-api` Edge Function used by the admin workspace.

## Local verification

```bash
npx supabase start
npx supabase db reset
npx supabase db lint --schema public --fail-on error
npx supabase functions serve admin-api
```

The migration creates the `platform_admin`, `support_admin`, `finance_admin`, and `analyst` roles. The admin dashboard requires `platform_admin`.

After creating a local Auth user, grant access from the SQL editor or local database:

```sql
insert into public.user_roles (user_id, role)
values ('AUTH_USER_UUID', 'platform_admin');
```

Do not place a service-role/secret key in the browser. The admin page uses only the public project URL and publishable key, while the database and Edge Function enforce authorization.

## Hosted setup

1. Link this directory to the intended Supabase project.
2. Apply the migration with `npx supabase db push` after reviewing it.
3. Create the first administrator in Supabase Auth, then insert their UUID into `public.user_roles`.
4. Deploy the function with `npx supabase functions deploy admin-api`.
5. Set the function secret `ADMIN_ALLOWED_ORIGIN` to the exact Cloudflare Pages origin.
6. Set the same project URL and publishable key in `admin/technicians/supabase-config.js`.
7. Set the deployed site root as Supabase Auth's Site URL and allow the customer root, business login, admin login, and any email-confirmation return URLs in the redirect allow-list.

The migration explicitly revokes anonymous table access, enables RLS on every public table, and records writes to the audit log through database triggers.

## Customer and business access

`index.html` stays publicly browsable. Creating a customer account is available from its Profile screen; booking requests, profile writes, and appointment history require a Supabase email/password session. `customer_bookings` rows and customer profiles are restricted to the owning Auth user by RLS. A customer signup does not create a business membership or an admin role.

`company/my-dash/home.html` redirects to `company/my-dash/login.html` unless the signed-in user has an active `business_memberships` row. Business accounts are not self-service: create their Auth user in Supabase, then provision their membership from the SQL editor. For example:

```sql
insert into public.business_memberships (business_id, user_id, role)
values ('BUSINESS_UUID', 'AUTH_USER_UUID', 'Owner');
```

The `business_id` must identify an existing business and the user must already exist in Supabase Auth. Use `Manager`, `Stylist`, or `Receptionist` as appropriate. No browser signup path can insert memberships. The deployment dashboard continues to require the separately provisioned `platform_admin` role.

The customer marketplace migration adds six explicitly labeled demo businesses, their services, staff, opening hours, South African time zones, and sample portfolio data. The customer page reads these records through a restricted public directory RPC. The demo ratings and listings are not verified business claims and should be replaced before a real public launch.

Slot availability is calculated from the saved service duration, provider hours, staff, and existing bookings. Booking requests are inserted through a database RPC that rechecks the chosen slot and price while holding a provider-scoped advisory lock. Provider appointment writes use the same lock and reject overlapping customer requests or appointments. This protects against concurrent requests for the same staff member. The company dashboard still contains prototype operational screens and does not yet manage these customer booking requests; production rollout still needs a provider confirmation workflow and paginated business-scoped dashboard queries.

Cloudflare Pages serves static HTML publicly. The page guards redirect unauthenticated visitors and hide the workspace UI, while Supabase RLS protects actual database rows; they cannot make the downloaded HTML source itself private. Do not embed confidential business data or secrets in the static pages. If the HTML route itself must return an HTTP denial before delivery, add a Cloudflare Pages Function/Worker that verifies a secure server-managed session cookie.

The `seed_mockup_data` migration copies the first records from the dashboard mockup into the database: businesses, applications, subscriptions, licences, customers, appointments, support tickets, billing transactions, health checks, settings, and audit activity. It is safe to apply once through migrations and is written to avoid duplicating those records if the migration is re-run during local development.

## Cloudflare Pages

This repository is a static site, so configure the Pages project with:

- Production branch: `main`
- Build command: `exit 0`
- Build output directory: `.`
- Root directory: repository root

The current project URL and publishable key are already configured in `admin/technicians/supabase-config.js`. Never put the service-role key there. The admin entry point will then be `/admin/technicians/login.html`.
