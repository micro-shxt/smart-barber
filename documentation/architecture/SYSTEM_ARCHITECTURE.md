# System Architecture

## Applications

The ecosystem consists of three independent Vite frontend applications:

- **Deployment Manager** is restricted to platform administrators.
- **Smart Barber Business** is used by employees and owners of tenant businesses.
- **Smart Barber** is used by customers.

Each application has its own build and local development command, but they consume shared packages and the same backend contracts.

## Shared backend

Supabase PostgreSQL is the system of record. Supabase Auth identifies users and creates authenticated sessions. Edge Functions provide trusted server-side operations. Supabase Realtime will carry selected live updates.

Application boundaries do not replace database isolation. Browser calls must use the anonymous key and remain constrained by PostgreSQL Row Level Security.

## Communication flow

```text
Customer / Merchant / Admin browser
                |
                v
       Supabase Auth
                |
                v
  Supabase PostgreSQL + RLS
                ^
                |
       Supabase Edge Functions
                |
                v
        Trusted integrations
```

The browser should call Edge Functions only for operations that require trusted logic or privileged server-side access. No frontend code will receive or use the service-role key.

## Shared packages

- `shared-ui`: reusable visual styles and interface components.
- `shared-utils`: non-domain common functions.
- `validation`: shared input and data validation.
- `authentication`: future browser auth helpers.
- `booking-engine`: future availability and booking rules.
- `tenant-management`: tenant membership and branch concepts.
- `shared-config`: shared constants and environment-safe configuration.
