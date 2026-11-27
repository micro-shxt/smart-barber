-- Customer-facing demo directory and authoritative, race-safe booking slots.
-- The seeded listings are explicitly demo data; replace them with verified
-- provider-submitted records before opening the directory to real customers.

create table if not exists public.customer_provider_profiles (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  public_slug text not null unique,
  description text not null default '',
  rating numeric(2,1) not null default 0 check (rating between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  cover_url text not null default '',
  portfolio_urls text[] not null default '{}',
  is_demo boolean not null default true,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_provider_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  opens_at time,
  closes_at time,
  closed boolean not null default false,
  slot_interval_minutes integer not null default 15 check (slot_interval_minutes between 5 and 120),
  unique (business_id, weekday),
  check (closed or (opens_at is not null and closes_at > opens_at))
);

alter table public.business_locations
  add column if not exists timezone text not null default 'Africa/Johannesburg';
alter table public.services
  add column if not exists description text not null default '';

alter table public.customer_provider_profiles enable row level security;
alter table public.customer_provider_hours enable row level security;
revoke all on public.customer_provider_profiles, public.customer_provider_hours from anon, authenticated;
grant select, insert, update, delete on public.customer_provider_profiles, public.customer_provider_hours to authenticated;

drop policy if exists customer_provider_profiles_manage on public.customer_provider_profiles;
create policy customer_provider_profiles_manage on public.customer_provider_profiles
  for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());
drop policy if exists customer_provider_hours_manage on public.customer_provider_hours;
create policy customer_provider_hours_manage on public.customer_provider_hours
  for all to authenticated
  using (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin())
  with check (private.has_business_role(business_id, array['Owner', 'Manager']::text[]) or private.is_platform_admin());

-- Public RPC returns only intentionally published marketplace fields.
create or replace function public.customer_public_directory()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id,
    'slug', profile.public_slug,
    'name', b.name,
    'category', b.category,
    'city', b.city,
    'area', coalesce(location.city, b.city),
    'timezone', coalesce(location.timezone, 'Africa/Johannesburg'),
    'description', profile.description,
    'rating', profile.rating,
    'reviews', profile.review_count,
    'image', profile.cover_url,
    'portfolio', profile.portfolio_urls,
    'is_demo', profile.is_demo,
    'hours', coalesce((select jsonb_agg(jsonb_build_object(
      'weekday', hours.weekday, 'opens_at', hours.opens_at, 'closes_at', hours.closes_at,
      'closed', hours.closed, 'slot_interval_minutes', hours.slot_interval_minutes
    ) order by hours.weekday) from public.customer_provider_hours hours where hours.business_id = b.id), '[]'::jsonb),
    'team', coalesce((select jsonb_agg(team.full_name order by team.full_name) from public.team_members team where team.business_id = b.id and team.active), '[]'::jsonb),
    'services', coalesce((select jsonb_agg(jsonb_build_object(
      'id', service.id, 'name', service.name, 'price', service.price,
      'duration', service.duration_minutes, 'description', service.description
    ) order by service.name) from public.services service where service.business_id = b.id and service.active), '[]'::jsonb)
  ) order by b.name), '[]'::jsonb)
  from public.customer_provider_profiles profile
  join public.businesses b on b.id = profile.business_id
  left join lateral (
    select loc.city, loc.timezone from public.business_locations loc
    where loc.business_id = b.id and loc.active order by loc.created_at limit 1
  ) location on true
  where profile.published and b.status = 'Active';
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
security definer
set search_path = ''
as $$
  with provider as (
    select b.id, coalesce(location.timezone, 'Africa/Johannesburg') as timezone
    from public.businesses b
    join public.customer_provider_profiles profile on profile.business_id = b.id and profile.published
    left join lateral (
      select loc.timezone from public.business_locations loc
      where loc.business_id = b.id and loc.active order by loc.created_at limit 1
    ) location on true
    where b.id = p_provider_id and b.status = 'Active'
  ), service as (
    select id, business_id, duration_minutes from public.services
    where id = p_service_id and active and business_id = p_provider_id
  ), schedule as (
    select hours.opens_at, hours.closes_at, hours.slot_interval_minutes, provider.timezone
    from provider join public.customer_provider_hours hours on hours.business_id = provider.id
    where hours.weekday = extract(isodow from p_date)::smallint and not hours.closed
  ), candidates as (
    select (p_date + schedule.opens_at) at time zone schedule.timezone
      + make_interval(mins => slot.n * schedule.slot_interval_minutes) as slot_start,
      (p_date + schedule.closes_at) at time zone schedule.timezone as close_at,
      schedule.timezone,
      service.duration_minutes
    from schedule cross join service
    cross join lateral generate_series(
      0,
      greatest(0, floor((extract(epoch from (schedule.closes_at - schedule.opens_at)) / 60 - service.duration_minutes) / schedule.slot_interval_minutes)::integer)
    ) slot(n)
  )
  select candidates.slot_start,
    (select team.full_name
     from public.team_members team
     where team.business_id = p_provider_id and team.active
       and (p_employee = 'Any available' or team.full_name = p_employee)
       and not exists (
         select 1 from public.customer_bookings booking
         where booking.provider_ref = p_provider_id::text
           and booking.status in ('Pending', 'Confirmed')
           and (booking.employee = 'Any available' or booking.employee = team.full_name)
           and booking.starts_at < candidates.slot_start + make_interval(mins => candidates.duration_minutes)
           and booking.starts_at + make_interval(mins => booking.duration_minutes) > candidates.slot_start
       )
       and not exists (
         select 1 from public.appointments appointment
         left join public.team_members booked_team on booked_team.id = appointment.team_member_id
         where appointment.business_id = p_provider_id
           and appointment.status in ('Pending', 'Confirmed')
           and (appointment.team_member_id is null or booked_team.full_name = team.full_name)
           and appointment.starts_at < candidates.slot_start + make_interval(mins => candidates.duration_minutes)
           and appointment.ends_at > candidates.slot_start
       )
     order by team.full_name limit 1) as employee,
     candidates.timezone
  from candidates
  where candidates.slot_start > now()
  order by candidates.slot_start;
$$;

create or replace function public.customer_create_booking(
  p_provider_id uuid,
  p_service_id uuid,
  p_starts_at timestamptz,
  p_employee text default 'Any available'
)
returns setof public.customer_bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_employee text;
  service_row public.services%rowtype;
  provider_name text;
  provider_area text;
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'Sign in is required to request an appointment';
  end if;

  -- Serialize slot claims per provider so simultaneous requests cannot both win.
  perform pg_advisory_xact_lock(hashtextextended(p_provider_id::text, 0));

  select service.* into service_row
  from public.services service
  join public.businesses business on business.id = service.business_id and business.status = 'Active'
  join public.customer_provider_profiles profile on profile.business_id = business.id and profile.published
  where service.id = p_service_id and service.business_id = p_provider_id and service.active;
  if not found then
    raise exception using errcode = '22023', message = 'This service is not available';
  end if;

  select business.name, coalesce(location.city, business.city)
    into provider_name, provider_area
  from public.businesses business
  left join lateral (
    select loc.city from public.business_locations loc
    where loc.business_id = business.id and loc.active order by loc.created_at limit 1
  ) location on true
  where business.id = p_provider_id;

  select slots.employee into selected_employee
  from public.customer_available_slots(p_provider_id, p_service_id,
    (p_starts_at at time zone (select coalesce(loc.timezone, 'Africa/Johannesburg')
      from public.business_locations loc where loc.business_id = p_provider_id and loc.active order by loc.created_at limit 1)),
    p_employee) slots
  where slots.starts_at = p_starts_at
  limit 1;
  if selected_employee is null then
    raise exception using errcode = '23P01', message = 'That appointment time is no longer available';
  end if;

  return query insert into public.customer_bookings (
    user_id, provider_ref, provider_name, service_name, starts_at,
    duration_minutes, employee, amount, status, details
  ) values (
    (select auth.uid()), p_provider_id::text, provider_name, service_row.name, p_starts_at,
    service_row.duration_minutes, selected_employee, service_row.price, 'Pending', provider_area
  ) returning *;
end;
$$;

-- Provider-side appointment writes share the same advisory lock as customer
-- requests and reject overlaps with both existing appointments and requests.
create or replace function private.prevent_appointment_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  employee_name text;
begin
  if new.status not in ('Pending', 'Confirmed') then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.business_id::text, 0));
  select full_name into employee_name from public.team_members where id = new.team_member_id;

  if exists (
    select 1 from public.customer_bookings booking
    where booking.provider_ref = new.business_id::text
      and booking.status in ('Pending', 'Confirmed')
      and (new.team_member_id is null or booking.employee = 'Any available' or booking.employee = employee_name)
      and booking.starts_at < new.ends_at
      and booking.starts_at + make_interval(mins => booking.duration_minutes) > new.starts_at
  ) or exists (
    select 1 from public.appointments appointment
    where appointment.business_id = new.business_id
      and appointment.id is distinct from new.id
      and appointment.status in ('Pending', 'Confirmed')
      and (new.team_member_id is null or appointment.team_member_id is null or appointment.team_member_id = new.team_member_id)
      and appointment.starts_at < new.ends_at
      and appointment.ends_at > new.starts_at
  ) then
    raise exception using errcode = '23P01', message = 'This appointment overlaps an existing booking';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_appointment_overlap on public.appointments;
create trigger prevent_appointment_overlap
  before insert or update of business_id, team_member_id, starts_at, ends_at, status
  on public.appointments
  for each row execute function private.prevent_appointment_overlap();

revoke all on function public.customer_public_directory() from public;
grant execute on function public.customer_public_directory() to anon, authenticated;
revoke all on function public.customer_available_slots(uuid, uuid, date, text) from public;
grant execute on function public.customer_available_slots(uuid, uuid, date, text) to anon, authenticated;
revoke all on function public.customer_create_booking(uuid, uuid, timestamptz, text) from public;
grant execute on function public.customer_create_booking(uuid, uuid, timestamptz, text) to authenticated;

-- Customer writes go through the server-side slot and price checks above.
revoke insert, delete on public.customer_bookings from authenticated;
grant select, update (status) on public.customer_bookings to authenticated;

-- Demo entries use reserved .invalid email addresses and are visibly marked as demos.
do $$
declare
  demo record;
  existing_business_id uuid;
  weekdays smallint[];
  declare_day smallint;
begin
  for demo in select * from (values
    ('11111111-1111-4111-8111-111111111111'::uuid, 'the-cut', 'The Cut Collective', 'Barbers', 'Cape Town', 'Sea Point', 'demo-cut@smartbarber.invalid', 'A demo neighbourhood barbershop for sharp cuts and an unhurried experience.', 4.9::numeric, 128, 'https://images.pexels.com/photos/1813272/pexels-photo-1813272.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R280'::text),
    ('22222222-2222-4222-8222-222222222222'::uuid, 'muse', 'Muse Hair Studio', 'Hair salons', 'Cape Town', 'Gardens', 'demo-muse@smartbarber.invalid', 'A demo hair studio focused on colour, texture and personal style.', 4.8::numeric, 94, 'https://images.pexels.com/photos/1564828/pexels-photo-1564828.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R350'::text),
    ('33333333-3333-4333-8333-333333333333'::uuid, 'form', 'Form Grooming', 'Barbers', 'Johannesburg', 'Rosebank', 'demo-form@smartbarber.invalid', 'A demo grooming studio with modern service and old-school hospitality.', 4.9::numeric, 210, 'https://images.pexels.com/photos/3998421/pexels-photo-3998421.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R260'::text),
    ('44444444-4444-4444-8444-444444444444'::uuid, 'glow', 'Glow Ritual', 'Skin & beauty', 'Cape Town', 'Claremont', 'demo-glow@smartbarber.invalid', 'A demo studio for thoughtful skin and beauty rituals.', 4.7::numeric, 76, 'https://images.pexels.com/photos/3985360/pexels-photo-3985360.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R190'::text),
    ('55555555-5555-4555-8555-555555555555'::uuid, 'strand', 'Strand & Co.', 'Hair salons', 'Durban', 'Umhlanga', 'demo-strand@smartbarber.invalid', 'A demo coastal studio specialising in wearable hair.', 4.8::numeric, 112, 'https://images.pexels.com/photos/3993323/pexels-photo-3993323.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R320'::text),
    ('66666666-6666-4666-8666-666666666666'::uuid, 'atelier', 'Atelier Nails', 'Nails', 'Pretoria', 'Brooklyn', 'demo-atelier@smartbarber.invalid', 'A demo nail studio for detail-led care and artistry.', 4.7::numeric, 63, 'https://images.pexels.com/photos/939836/pexels-photo-939836.jpeg?auto=compress&cs=tinysrgb&w=800&h=600&fit=crop', 'R250'::text)
  ) as d(id, slug, name, category, city, area, email, description, rating, reviews, image, starting_price)
  loop
    select id into existing_business_id from public.businesses where id = demo.id;
    if existing_business_id is null then
      insert into public.businesses (id, name, category, city, contact_email, plan_code, status, locations_count)
      values (demo.id, demo.name, demo.category, demo.city, demo.email, 'starter', 'Active', 1);
    else
      update public.businesses set status = 'Active', category = demo.category, city = demo.city where id = demo.id;
    end if;

    insert into public.business_locations (id, business_id, name, city, country_code, timezone, active)
    values (demo.id, demo.id, demo.area, demo.city, 'ZA',
      case when demo.city = 'Cape Town' then 'Africa/Johannesburg' else 'Africa/Johannesburg' end, true)
    on conflict (id) do update set city = excluded.city, active = true, timezone = excluded.timezone;

    insert into public.customer_provider_profiles (business_id, public_slug, description, rating, review_count, cover_url, portfolio_urls, is_demo, published)
    values (demo.id, demo.slug, demo.description, demo.rating, demo.reviews, demo.image,
      array[demo.image], true, true)
    on conflict (business_id) do update set description = excluded.description, rating = excluded.rating,
      review_count = excluded.review_count, cover_url = excluded.cover_url,
      portfolio_urls = excluded.portfolio_urls, published = true;

    if demo.slug = 'the-cut' then weekdays := array[1,2,3,4,5,6];
    elsif demo.slug in ('muse','strand') then weekdays := array[2,3,4,5,6];
    else weekdays := array[1,2,3,4,5,6]; end if;
    for declare_day in 1..7 loop
      insert into public.customer_provider_hours (business_id, weekday, opens_at, closes_at, closed, slot_interval_minutes)
      values (demo.id, declare_day, '09:00', '18:00', not (declare_day = any(weekdays)), 15)
      on conflict (business_id, weekday) do update set opens_at = excluded.opens_at,
        closes_at = excluded.closes_at, closed = excluded.closed;
    end loop;

    if not exists (select 1 from public.team_members where business_id = demo.id) then
      insert into public.team_members (business_id, full_name, role_title) values
        (demo.id, 'Demo Stylist A', 'Technician'), (demo.id, 'Demo Stylist B', 'Technician');
    end if;
    if not exists (select 1 from public.services where business_id = demo.id) then
      if demo.slug = 'the-cut' then
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Signature cut', 'Consultation, cut and finish.', 45, 280, true),
          (demo.id, 'Skin fade', 'A detailed fade and clean finish.', 45, 320, true),
          (demo.id, 'Beard sculpt', 'Shape, trim and finish.', 30, 180, true);
      elsif demo.slug = 'muse' then
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Wash & blowout', 'Wash and styled finish.', 45, 350, true),
          (demo.id, 'Cut & style', 'Consultation, cut and styled finish.', 60, 550, true),
          (demo.id, 'Colour refresh', 'Colour refresh with consultation.', 120, 950, true);
      elsif demo.slug = 'form' then
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Classic cut', 'A considered everyday cut.', 40, 260, true),
          (demo.id, 'Fade & finish', 'Precision fade and hot-towel finish.', 45, 310, true),
          (demo.id, 'Cut & beard', 'A complete grooming session.', 70, 420, true);
      elsif demo.slug = 'glow' then
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Express facial', 'A refreshing facial treatment.', 45, 450, true),
          (demo.id, 'Signature facial', 'A tailored skin treatment.', 75, 680, true),
          (demo.id, 'Brow shaping', 'Natural brow shaping.', 25, 190, true);
      elsif demo.slug = 'strand' then
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Style cut', 'A cut suited to your hair and style.', 60, 490, true),
          (demo.id, 'Blowout', 'A polished wash and blowout.', 45, 320, true),
          (demo.id, 'Gloss treatment', 'Gloss and conditioning treatment.', 60, 620, true);
      else
        insert into public.services (business_id, name, description, duration_minutes, price, active) values
          (demo.id, 'Classic manicure', 'Care, shaping and polish.', 45, 250, true),
          (demo.id, 'Gel manicure', 'Gel colour with detailed prep.', 60, 390, true),
          (demo.id, 'Spa pedicure', 'Foot care and spa pedicure.', 60, 430, true);
      end if;
    end if;
  end loop;
end;
$$;
