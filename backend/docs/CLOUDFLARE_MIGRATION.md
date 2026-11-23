# Future Cloudflare Migration

This phase does not implement Cloudflare Workers or a database.

## Repository replacement

Implement a D1 repository satisfying `RepositoryInterface`, with SQL for each method. Replace `InMemoryRepository` during application composition. Add a transaction-backed `createAppointmentAtomically` implementation that checks conflicts and inserts the booking in a single database transaction.

## Worker entry point

Adapt `createApplication()` or the HTTP routing layer to the Worker `fetch(request, env, ctx)` API. The service and domain layers should remain unchanged. Inject configuration and repositories from `env`.

## Authentication

Replace `MockIdentityProvider` with an adapter that verifies a production identity token or session and maps it to a trusted internal user identity. Never accept `x-user-id` in production.

## Known incomplete work

- Production identity and session issuance
- Persistent D1 schema and migrations
- Atomic cross-instance conflict prevention
- Complete operating-hours and time-off administration
- Staff/location/service management mutations
- Customer profile and favourites
- Real availability slot endpoint persistence
- Concurrency, rate limiting and audit logging
