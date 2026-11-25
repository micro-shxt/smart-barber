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
7. Add the deployed admin and login URLs to Supabase Auth's Site URL and redirect allow-list.

The migration explicitly revokes anonymous table access, enables RLS on every public table, and records writes to the audit log through database triggers.

The `seed_mockup_data` migration copies the first records from the dashboard mockup into the database: businesses, applications, subscriptions, licences, customers, appointments, support tickets, billing transactions, health checks, settings, and audit activity. It is safe to apply once through migrations and is written to avoid duplicating those records if the migration is re-run during local development.

## Cloudflare Pages

This repository is a static site, so configure the Pages project with:

- Production branch: `main`
- Build command: `exit 0`
- Build output directory: `.`
- Root directory: repository root

The current project URL and publishable key are already configured in `admin/technicians/supabase-config.js`. Never put the service-role key there. The admin entry point will then be `/admin/technicians/login.html`.
