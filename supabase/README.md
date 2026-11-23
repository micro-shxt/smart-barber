# Supabase workspace

This directory reserves the locations for future Supabase resources. Supabase is not connected and no credentials or live database configuration are included.

- `migrations/`: version-controlled PostgreSQL schema and Row Level Security migrations.
- `functions/`: trusted Edge Functions for operations that must not run in browser code.
- `seed/`: non-sensitive development and demonstration seed data only.

Before using Supabase:

1. Create the Supabase project.
2. Add the public URL and anonymous key to local Vite environment configuration.
3. Keep the service-role key only in Supabase or another trusted server environment.
4. Review every migration for tenant isolation and role checks.
5. Never commit `.env`, keys or credentials.
