# Architecture

## Dependency direction

HTTP route -> controller -> service -> repository interface -> in-memory/D1 implementation.

Domain entities and rules do not import HTTP or database libraries. Repositories own data access and return plain domain-shaped objects.

## Layers

- `routes`: endpoint definitions
- `controllers`: HTTP and validation boundary
- `services`: application workflows and tenant checks
- `repositories`: data-access interfaces and implementations
- `domain`: statuses, entities and transition rules
- `middleware`: mock authentication and central errors

## Repository audit

The existing repository contains three independent Vite HTML applications. The customer and merchant interfaces are preserved and are not rewritten. Existing documentation references future Supabase integration, while this phase introduces no Supabase or Cloudflare runtime dependency.
