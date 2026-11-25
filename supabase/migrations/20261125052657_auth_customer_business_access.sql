-- Separate customer accounts from provisioned business workspace accounts.
-- Customer signup never grants a business membership or platform role.

create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '' check (char_length(full_name) <= 160),
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_ref text not null check (char_length(provider_ref) between 1 and 100),
  provider_name text not null check (char_length(provider_name) between 1 and 160),
  service_name text not null check (char_length(service_name) between 1 and 160),
  starts_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  employee text not null default 'Any available' check (char_length(employee) <= 160),
  amount numeric(10, 2) not null check (amount >= 0),
  status text not null default 'Pending' check (status in ('Pending', 'Confirmed', 'Cancelled')),
  details text not null default '' check (char_length(details) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('Owner', 'Manager', 'Stylist', 'Receptionist')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

-- Supports indexed per-account history and indexed business membership checks at scale.
create index if not exists customer_bookings_user_created_idx
  on public.customer_bookings (user_id, created_at desc, id desc);
create index if not exists customer_bookings_provider_time_idx
  on public.customer_bookings (provider_ref, starts_at)
  where status <> 'Cancelled';
create unique index if not exists customer_bookings_provider_slot_idx
  on public.customer_bookings (provider_ref, starts_at, employee)
  where status <> 'Cancelled';
create index if not exists business_memberships_user_active_idx
  on public.business_memberships (user_id, business_id)
  where active;
create index if not exists business_memberships_business_active_idx
  on public.business_memberships (business_id, user_id)
  where active;

create or replace function private.is_business_member(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.business_memberships membership
    where membership.business_id = target_business_id
      and membership.user_id = (select auth.uid())
      and membership.active
  );
$$;

create or replace function private.has_business_role(target_business_id uuid, allowed_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.business_memberships membership
    where membership.business_id = target_business_id
      and membership.user_id = (select auth.uid())
      and membership.active
      and membership.role = any(allowed_roles)
  );
$$;

create or replace function private.protect_customer_booking()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null and (
    new.user_id is distinct from old.user_id
    or new.provider_ref is distinct from old.provider_ref
    or new.provider_name is distinct from old.provider_name
    or new.service_name is distinct from old.service_name
    or new.starts_at is distinct from old.starts_at
    or new.duration_minutes is distinct from old.duration_minutes
    or new.employee is distinct from old.employee
    or new.amount is distinct from old.amount
    or new.details is distinct from old.details
    or (new.status is distinct from old.status and not (old.status = 'Pending' and new.status = 'Cancelled'))
  ) then
    raise exception using errcode = '42501', message = 'Customers may only cancel their pending booking requests';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_customer_booking on public.customer_bookings;
create trigger protect_customer_booking
  before update on public.customer_bookings
  for each row execute function private.protect_customer_booking();

revoke all on function private.is_business_member(uuid) from public;
grant execute on function private.is_business_member(uuid) to authenticated;
revoke all on function private.has_business_role(uuid, text[]) from public;
grant execute on function private.has_business_role(uuid, text[]) to authenticated;

alter table public.customer_profiles enable row level security;
alter table public.customer_bookings enable row level security;
alter table public.business_memberships enable row level security;

revoke all on public.customer_profiles, public.customer_bookings, public.business_memberships from anon, authenticated;
grant select, insert, update on public.customer_profiles to authenticated;
grant select, insert, delete on public.customer_bookings to authenticated;
grant update (status) on public.customer_bookings to authenticated;
grant select on public.business_memberships to authenticated;

create policy customer_profiles_read_own on public.customer_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy customer_profiles_create_own on public.customer_profiles
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy customer_profiles_update_own on public.customer_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy customer_bookings_read_own on public.customer_bookings
  for select to authenticated using (user_id = (select auth.uid()));
create policy customer_bookings_create_own on public.customer_bookings
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy customer_bookings_update_own on public.customer_bookings
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy customer_bookings_delete_own on public.customer_bookings
  for delete to authenticated using (user_id = (select auth.uid()));

create policy business_memberships_read_self_or_admin on public.business_memberships
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_platform_admin());

-- Business data remains private to a business's active staff and platform admins.
drop policy if exists businesses_select on public.businesses;
create policy businesses_select on public.businesses for select to authenticated
  using (private.is_business_member(id) or private.has_any_role(array['platform_admin', 'support_admin', 'finance_admin', 'analyst']::text[]));
drop policy if exists businesses_update on public.businesses;
create policy businesses_update on public.businesses for update to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

drop policy if exists locations_admin on public.business_locations;
create policy locations_member_access on public.business_locations for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());
drop policy if exists team_admin on public.team_members;
create policy team_member_access on public.team_members for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());
drop policy if exists customers_select on public.customers;
create policy customers_member_read on public.customers for select to authenticated
  using (private.is_business_member(business_id) or private.is_platform_admin());
drop policy if exists customers_admin on public.customers;
create policy customers_member_manage on public.customers for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());
drop policy if exists services_admin on public.services;
create policy services_member_access on public.services for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());
drop policy if exists appointments_select on public.appointments;
create policy appointments_member_read on public.appointments for select to authenticated
  using (private.is_business_member(business_id) or private.is_platform_admin());
drop policy if exists appointments_admin on public.appointments;
create policy appointments_member_manage on public.appointments for all to authenticated
  using (private.is_business_member(business_id) or private.is_platform_admin())
  with check (private.is_business_member(business_id) or private.is_platform_admin());
drop policy if exists subscriptions_select on public.subscriptions;
create policy subscriptions_member_read on public.subscriptions for select to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
drop policy if exists subscriptions_admin on public.subscriptions;
create policy subscriptions_member_manage on public.subscriptions for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists licences_select on public.licences;
create policy licences_member_read on public.licences for select to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
drop policy if exists licences_admin on public.licences;
create policy licences_member_manage on public.licences for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
drop policy if exists billing_select on public.billing_transactions;
create policy billing_member_read on public.billing_transactions for select to authenticated
  using ((business_id is not null and private.has_business_role(business_id, array['Owner', 'Manager']::text[])) or private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
drop policy if exists billing_admin on public.billing_transactions;
create policy billing_admin on public.billing_transactions for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

comment on table public.business_memberships is 'Business access is provisioned by trusted administrators; customer signup never creates memberships.';
comment on table public.customer_bookings is 'Customer-owned booking requests, protected by per-user row-level security.';
