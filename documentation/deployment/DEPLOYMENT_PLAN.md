# Deployment Plan

## Supabase

Supabase hosts PostgreSQL, Auth and Edge Functions. Database migrations should be reviewed and applied through version control. Realtime should be enabled only for data that is subject to explicit RLS policies.

Public browser configuration will include the Supabase project URL and anonymous key. The service-role key will remain in the Supabase or trusted server environment.

## Cloudflare Pages

Each frontend application should be deployed as a separate Cloudflare Pages project or separate route:

- Deployment Manager
- Smart Barber Business
- Smart Barber

Cloudflare Pages build settings should point to the root workspace and use the corresponding build script.

Environment variables in Cloudflare Pages must contain public values only. Privileged operations should use protected Edge Functions or Cloudflare Workers.

## Cloudflare Workers

Workers may be used for routing, public APIs or server-side integrations that are not suitable for direct browser calls. Workers must not expose Supabase service-role credentials and should use least-privilege secrets.

## Android

Capacitor will eventually package the customer-facing application and selected mobile surfaces. Native permissions and signing configuration must be managed separately. Android build artifacts and signing keys must remain untracked.

## GitHub

Pull requests should run dependency installation and focused builds before deployment. Production credentials must use protected GitHub environments or provider-side secret managers.
