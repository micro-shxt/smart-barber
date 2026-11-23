# Security Guidelines

## Authentication

Supabase Auth will authenticate browser users. Applications must check authorization and never treat hidden navigation as security.

Administrative operations must require server-side authorization and role checks. Business and customer data must be filtered and protected by tenant, branch and role policies.

## Secrets

`VITE_SUPABASE_ANON_KEY` is designed for public browser use and is not an administrative secret. The Supabase service-role key must never be placed in JavaScript, Vite variables, GitHub files or Cloudflare Pages public configuration.

Trusted server-side code may use the service-role key only when the execution environment is protected and every privileged operation has explicit authorization checks.

Local environment files are ignored by Git. `.env.example` contains names only.

## Tenant isolation

Each business will have a stable tenant ID. The user-to-tenant relationship should include ownership and role data. Branches and employees belong to tenants.

PostgreSQL Row Level Security will be enabled for tenant-owned tables. Policies should derive access from the authenticated user, not from browser-supplied tenant values.

## Data operations

- Never trust a tenant ID sent only by the browser.
- Reject unauthorized reads and writes at database policy level.
- Use Edge Functions or trusted Workers for operations that require elevated privileges.
- Enable audit logs for administrative and sensitive business changes.
- Add constraints for appointment conflicts and other integrity rules.

## Supabase configuration

The anonymous key may be public. Database RLS is mandatory for browser-accessible tables. Storage buckets and Realtime subscriptions require similarly explicit policies.

## Deployment

Cloudflare secrets must be configured through the Cloudflare secret mechanism and rotated outside source control. GitHub Actions should use repository or environment secrets rather than checked-in files.
