-- Smart Barber production backend
--
-- This migration is intentionally admin-first. The dashboard is a platform
-- operations console, so the initial policies expose platform data only to
-- users granted an explicit role in public.user_roles.

create schema if not exists private;

create table if not exists public.subscription_plans (
  code text primary key,
  name text not null,
  description text not null default '',
  monthly_price numeric(10, 2) not null check (monthly_price >= 0),
  location_limit integer check (location_limit is null or location_limit > 0),
  team_member_limit integer check (team_member_limit is null or team_member_limit > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('platform_admin', 'support_admin', 'finance_admin', 'analyst')),
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  category text not null check (char_length(trim(category)) between 2 and 80),
  city text not null check (char_length(trim(city)) between 2 and 100),
  contact_email text not null check (char_length(trim(contact_email)) between 3 and 320),
  plan_code text not null references public.subscription_plans(code),
  status text not null default 'Pending' check (status in ('Pending', 'Active', 'Suspended', 'Inactive', 'Rejected')),
  notes text not null default '' check (char_length(notes) <= 5000),
  locations_count integer not null default 1 check (locations_count > 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_applications (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  submitted_by uuid references auth.users(id) on delete set null,
  status text not null default 'Pending' check (status in ('Pending', 'Approved', 'Rejected', 'Withdrawn')),
  requested_plan_code text not null references public.subscription_plans(code),
  notes text not null default '' check (char_length(notes) <= 5000),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  address_line_1 text,
  address_line_2 text,
  city text not null,
  postal_code text,
  country_code text not null default 'GB' check (char_length(country_code) = 2),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  full_name text not null,
  email text,
  role_title text not null default 'Technician',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  status text not null default 'Active' check (status in ('Active', 'Inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  price numeric(10, 2) not null check (price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  location_id uuid references public.business_locations(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  team_member_id uuid references public.team_members(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'Confirmed' check (status in ('Pending', 'Confirmed', 'Completed', 'Cancelled', 'No-show')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  plan_code text not null references public.subscription_plans(code),
  status text not null default 'Active' check (status in ('Trialing', 'Active', 'Past due', 'Cancelled', 'Paused')),
  current_period_start date not null default current_date,
  current_period_end date not null default (current_date + interval '1 month')::date,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (current_period_end >= current_period_start)
);

create table if not exists public.licences (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  seats_allocated integer not null default 1 check (seats_allocated >= 0),
  seat_limit integer check (seat_limit is null or seat_limit >= 0),
  status text not null default 'Active' check (status in ('Active', 'Inactive', 'Expired')),
  expires_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  amount numeric(12, 2) not null check (amount >= 0),
  currency text not null default 'GBP' check (char_length(currency) = 3),
  type text not null check (type in ('Subscription', 'Transaction fee', 'Refund', 'Adjustment')),
  status text not null default 'Pending' check (status in ('Pending', 'Paid', 'Failed', 'Refunded', 'Void')),
  external_reference text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number bigint generated always as identity unique,
  business_id uuid references public.businesses(id) on delete set null,
  requester_id uuid references auth.users(id) on delete set null,
  subject text not null check (char_length(trim(subject)) between 3 and 200),
  category text not null default 'Account enquiry',
  status text not null default 'Open' check (status in ('Open', 'Review', 'Resolved', 'Closed')),
  priority text not null default 'Normal' check (priority in ('Low', 'Normal', 'High', 'Urgent')),
  body text not null default '',
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.platform_settings (
  key text primary key check (key ~ '^[a-z][a-z0-9_.-]{1,100}$'),
  value jsonb not null default '{}'::jsonb,
  description text not null default '',
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_health_checks (
  id uuid primary key default gen_random_uuid(),
  service_name text not null,
  status text not null check (status in ('Operational', 'Degraded', 'Down')),
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  details jsonb not null default '{}'::jsonb,
  checked_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists businesses_status_idx on public.businesses(status);
create index if not exists businesses_created_at_idx on public.businesses(created_at desc);
create index if not exists business_applications_status_idx on public.business_applications(status);
create index if not exists subscriptions_status_idx on public.subscriptions(status);
create index if not exists customers_business_id_idx on public.customers(business_id);
create index if not exists appointments_business_starts_at_idx on public.appointments(business_id, starts_at desc);
create index if not exists billing_transactions_occurred_at_idx on public.billing_transactions(occurred_at desc);
create index if not exists support_tickets_status_idx on public.support_tickets(status);
create index if not exists audit_logs_created_at_idx on public.audit_logs(created_at desc);

create or replace function private.has_any_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select exists (
      select 1
      from public.user_roles ur
      where ur.user_id = (select auth.uid())
        and ur.active
        and ur.role = any(required_roles)
    )), false
  );
$$;

create or replace function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_any_role(array['platform_admin']::text[]);
$$;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  entity_id_value uuid;
begin
  entity_id_value := coalesce((to_jsonb(new) ->> 'id')::uuid, (to_jsonb(old) ->> 'id')::uuid);
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, before_data, after_data)
  values (
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    entity_id_value,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'subscription_plans', 'profiles', 'businesses', 'business_applications',
    'business_locations', 'team_members', 'customers', 'services', 'appointments',
    'subscriptions', 'licences', 'support_tickets', 'platform_settings'
  ] loop
    execute format('drop trigger if exists set_updated_at on public.%I', table_name);
    execute format('create trigger set_updated_at before update on public.%I for each row execute function private.set_updated_at()', table_name);
  end loop;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'subscription_plans', 'businesses', 'business_applications', 'subscriptions',
    'licences', 'billing_transactions', 'support_tickets', 'platform_settings', 'user_roles'
  ] loop
    execute format('drop trigger if exists audit_row_change on public.%I', table_name);
    execute format('create trigger audit_row_change after insert or update or delete on public.%I for each row execute function private.audit_row_change()', table_name);
  end loop;
end;
$$;

insert into public.subscription_plans (code, name, description, monthly_price, location_limit, team_member_limit)
values
  ('starter', 'Starter', 'For independent professionals', 29, 1, 3),
  ('growth', 'Growth', 'For growing teams', 79, 3, 15),
  ('pro', 'Pro', 'For ambitious multi-site brands', 149, null, null)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  monthly_price = excluded.monthly_price,
  location_limit = excluded.location_limit,
  team_member_limit = excluded.team_member_limit,
  updated_at = now();

create or replace function public.submit_business_application(
  p_name text,
  p_category text,
  p_city text,
  p_contact_email text,
  p_plan_code text,
  p_notes text default ''
)
returns public.businesses
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  new_business public.businesses;
begin
  if not private.has_any_role(array['platform_admin']::text[]) then
    raise exception using errcode = '42501', message = 'Platform administrator role required';
  end if;

  insert into public.businesses (name, category, city, contact_email, plan_code, status, notes, created_by)
  values (trim(p_name), trim(p_category), trim(p_city), lower(trim(p_contact_email)), p_plan_code, 'Pending', coalesce(p_notes, ''), (select auth.uid()))
  returning * into new_business;

  insert into public.business_applications (business_id, submitted_by, requested_plan_code, notes)
  values (new_business.id, (select auth.uid()), new_business.plan_code, new_business.notes);

  return new_business;
end;
$$;

create or replace function public.admin_update_business(
  p_business_id uuid,
  p_status text default null,
  p_plan_code text default null
)
returns public.businesses
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  updated_business public.businesses;
begin
  if not private.has_any_role(array['platform_admin']::text[]) then
    raise exception using errcode = '42501', message = 'Platform administrator role required';
  end if;

  update public.businesses
  set status = coalesce(p_status, status),
      plan_code = coalesce(p_plan_code, plan_code)
  where id = p_business_id
  returning * into updated_business;

  if updated_business.id is null then
    raise exception using errcode = 'P0002', message = 'Business not found';
  end if;

  if p_status in ('Active', 'Rejected') then
    update public.business_applications
    set status = case when p_status = 'Active' then 'Approved' else 'Rejected' end,
        reviewed_by = (select auth.uid()),
        reviewed_at = now()
    where business_id = updated_business.id
      and status = 'Pending';
  end if;

  if updated_business.status = 'Active'
     and not exists (
       select 1 from public.subscriptions
       where business_id = updated_business.id and status in ('Trialing', 'Active', 'Past due')
     ) then
    insert into public.subscriptions (business_id, plan_code)
    values (updated_business.id, updated_business.plan_code);
  end if;

  return updated_business;
end;
$$;

revoke all on schema private from public;
grant usage on schema private to authenticated;
revoke all on function private.has_any_role(text[]) from public;
grant execute on function private.has_any_role(text[]) to authenticated;
revoke all on function private.is_platform_admin() from public;
grant execute on function private.is_platform_admin() to authenticated;
revoke all on function public.submit_business_application(text, text, text, text, text, text) from public;
grant execute on function public.submit_business_application(text, text, text, text, text, text) to authenticated;
revoke all on function public.admin_update_business(uuid, text, text) from public;
grant execute on function public.admin_update_business(uuid, text, text) to authenticated;

alter table public.subscription_plans enable row level security;
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_applications enable row level security;
alter table public.business_locations enable row level security;
alter table public.team_members enable row level security;
alter table public.customers enable row level security;
alter table public.services enable row level security;
alter table public.appointments enable row level security;
alter table public.subscriptions enable row level security;
alter table public.licences enable row level security;
alter table public.billing_transactions enable row level security;
alter table public.support_tickets enable row level security;
alter table public.notifications enable row level security;
alter table public.platform_settings enable row level security;
alter table public.system_health_checks enable row level security;
alter table public.audit_logs enable row level security;

revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_platform_admin());
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = (select auth.uid()) or private.is_platform_admin());
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()) or private.is_platform_admin())
  with check (id = (select auth.uid()) or private.is_platform_admin());

create policy roles_select on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or private.is_platform_admin());
create policy roles_insert on public.user_roles for insert to authenticated
  with check (private.is_platform_admin());
create policy roles_update on public.user_roles for update to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy roles_delete on public.user_roles for delete to authenticated
  using (private.is_platform_admin());

create policy plans_select on public.subscription_plans for select to authenticated
  using (private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
create policy plans_mutate on public.subscription_plans for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

create policy businesses_select on public.businesses for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin', 'finance_admin', 'analyst']::text[]));
create policy businesses_insert on public.businesses for insert to authenticated
  with check (private.is_platform_admin());
create policy businesses_update on public.businesses for update to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy businesses_delete on public.businesses for delete to authenticated
  using (private.is_platform_admin());

create policy applications_select on public.business_applications for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin', 'analyst']::text[]));
create policy applications_insert on public.business_applications for insert to authenticated
  with check (private.is_platform_admin());
create policy applications_update on public.business_applications for update to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

create policy locations_admin on public.business_locations for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy team_admin on public.team_members for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy customers_select on public.customers for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin', 'analyst']::text[]));
create policy customers_admin on public.customers for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy services_admin on public.services for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy appointments_select on public.appointments for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin', 'analyst']::text[]));
create policy appointments_admin on public.appointments for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

create policy subscriptions_select on public.subscriptions for select to authenticated
  using (private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
create policy subscriptions_admin on public.subscriptions for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy licences_select on public.licences for select to authenticated
  using (private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
create policy licences_admin on public.licences for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy billing_select on public.billing_transactions for select to authenticated
  using (private.has_any_role(array['platform_admin', 'finance_admin', 'analyst']::text[]));
create policy billing_admin on public.billing_transactions for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

create policy support_select on public.support_tickets for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin']::text[]));
create policy support_insert on public.support_tickets for insert to authenticated
  with check (private.has_any_role(array['platform_admin', 'support_admin']::text[]));
create policy support_update on public.support_tickets for update to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin']::text[]))
  with check (private.has_any_role(array['platform_admin', 'support_admin']::text[]));

create policy notifications_select on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) or private.is_platform_admin());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = (select auth.uid()) or private.is_platform_admin())
  with check (user_id = (select auth.uid()) or private.is_platform_admin());
create policy settings_select on public.platform_settings for select to authenticated
  using (private.has_any_role(array['platform_admin', 'analyst']::text[]));
create policy settings_admin on public.platform_settings for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy health_select on public.system_health_checks for select to authenticated
  using (private.has_any_role(array['platform_admin', 'analyst']::text[]));
create policy audit_select on public.audit_logs for select to authenticated
  using (private.has_any_role(array['platform_admin', 'support_admin', 'finance_admin']::text[]));

comment on table public.user_roles is 'Authorization source of truth. Do not use user-editable metadata for access decisions.';
comment on table public.audit_logs is 'Append-only audit trail populated by database triggers.';
