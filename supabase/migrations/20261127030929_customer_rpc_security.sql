-- Keep the privileged directory, slot lookup, and booking implementation in
-- the private schema. Public RPC wrappers remain SECURITY INVOKER functions.
alter function public.customer_public_directory() set schema private;
alter function public.customer_available_slots(uuid, uuid, date, text) set schema private;
alter function public.customer_create_booking(uuid, uuid, timestamptz, text) set schema private;

grant usage on schema private to anon, authenticated;

create or replace function public.customer_public_directory()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.customer_public_directory();
$$;

create or replace function public.customer_available_slots(
  p_provider_id uuid,
  p_service_id uuid,
  p_date date,
  p_employee text default 'Any available'
)
returns table(starts_at timestamptz, employee text, timezone text)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.customer_available_slots($1, $2, $3, $4);
$$;

create or replace function public.customer_create_booking(
  p_provider_id uuid,
  p_service_id uuid,
  p_starts_at timestamptz,
  p_employee text default 'Any available'
)
returns setof public.customer_bookings
language sql
security invoker
set search_path = ''
as $$
  select * from private.customer_create_booking($1, $2, $3, $4);
$$;

revoke all on function private.customer_public_directory() from public;
grant execute on function private.customer_public_directory() to anon, authenticated;
revoke all on function private.customer_available_slots(uuid, uuid, date, text) from public;
grant execute on function private.customer_available_slots(uuid, uuid, date, text) to anon, authenticated;
revoke all on function private.customer_create_booking(uuid, uuid, timestamptz, text) from public;
grant execute on function private.customer_create_booking(uuid, uuid, timestamptz, text) to authenticated;

revoke all on function public.customer_public_directory() from public;
grant execute on function public.customer_public_directory() to anon, authenticated;
revoke all on function public.customer_available_slots(uuid, uuid, date, text) from public;
grant execute on function public.customer_available_slots(uuid, uuid, date, text) to anon, authenticated;
revoke all on function public.customer_create_booking(uuid, uuid, timestamptz, text) from public;
grant execute on function public.customer_create_booking(uuid, uuid, timestamptz, text) to authenticated;
