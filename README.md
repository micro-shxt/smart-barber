# Smart Barber System

Smart Barber System is a three-application ecosystem for a salon and personal-care marketplace. The applications share future Supabase services while remaining independently runnable.

## Applications

- **Deployment Manager** (`apps/deployment-manager`): platform-owner and administrator operations.
- **Smart Barber Business** (`apps/merchant-app`): multi-tenant business, employee, schedule and booking management.
- **Smart Barber** (`apps/customer-app`): customer discovery, marketplace and appointment management.

## Technology

- HTML5, CSS3 and JavaScript
- Vite
- Supabase Auth, PostgreSQL, Realtime and Edge Functions
- Cloudflare Pages and Workers
- GitHub
- Capacitor for Android packaging

No Supabase or Cloudflare credentials are configured in this repository.

## Project structure

```text
apps/                    Independent Vite applications
packages/                Shared packages and future design system
supabase/                Future migrations, functions and seed data
infrastructure/          Future Cloudflare, deployment and security configuration
documentation/           Architecture and operational documentation
scripts/                 Repository automation
tests/                   Cross-application and integration tests
```

See [documentation/architecture/FOLDER_STRUCTURE.md](documentation/architecture/FOLDER_STRUCTURE.md) for directory details.

## Install

Use Node.js 20 or newer and npm 10 or newer.

```bash
npm install
cp .env.example .env.local
npm run dev:customer
```

Do not add real credentials to `.env.local` unless they are suitable for browser use. The service-role key must never be added to a Vite or `VITE_` variable.

## Run locally

```bash
npm run dev:admin
npm run dev:merchant
npm run dev:customer
```

Each command starts a separate Vite development server. Run each application in a separate terminal.

## Build

```bash
npm run build:admin
npm run build:merchant
npm run build:customer
# or build all three
npm run build
```

Vite output is written to each application's `dist/` directory.

## Environment variables

Copy `.env.example` to `.env.local`. Only `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are browser-public values. Server-only names must remain in Supabase Edge Functions or trusted Cloudflare Worker configuration.

## Documentation

- [System architecture](documentation/architecture/SYSTEM_ARCHITECTURE.md)
- [Folder structure](documentation/architecture/FOLDER_STRUCTURE.md)
- [Security guidelines](documentation/security/SECURITY_GUIDELINES.md)
- [Development guide](documentation/development/DEVELOPMENT_GUIDE.md)
- [Database plan](documentation/database/DATABASE_PLAN.md)
- [Deployment plan](documentation/deployment/DEPLOYMENT_PLAN.md)
