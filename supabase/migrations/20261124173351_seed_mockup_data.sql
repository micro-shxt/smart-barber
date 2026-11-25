-- Smart Admin mockup data
--
-- These records intentionally mirror the first visible records in
-- admin/technicians/smart-admin.html. They are real database rows so the
-- authenticated dashboard opens with believable data and the prototype can
-- be replaced incrementally without changing its first-run experience.

alter table public.businesses
  add column if not exists appointment_count integer not null default 0
    check (appointment_count >= 0);

alter table public.customers
  add column if not exists visits integer not null default 0
    check (visits >= 0);

alter table public.customers
  add column if not exists joined_at date;

alter table public.licences
  add column if not exists plan_code text references public.subscription_plans(code);

alter table public.support_tickets
  add column if not exists ticket_code text;

alter table public.appointments
  add column if not exists appointment_code text;

create unique index if not exists appointments_appointment_code_idx
  on public.appointments(appointment_code)
  where appointment_code is not null;

create unique index if not exists support_tickets_ticket_code_idx
  on public.support_tickets(ticket_code)
  where ticket_code is not null;

do $$
declare
  item record;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_businesses$
      [
        {"name":"The Modern Cut","category":"Barbershop","city":"London","contact_email":"hello@moderncut.example","plan_code":"growth","status":"Active","created_at":"2026-01-12T09:00:00Z","locations_count":3,"appointment_count":1284},
        {"name":"Olive & Ivy Studio","category":"Hair salon","city":"Manchester","contact_email":"team@oliveivy.example","plan_code":"pro","status":"Active","created_at":"2026-01-18T09:00:00Z","locations_count":2,"appointment_count":947},
        {"name":"Northside Grooming","category":"Barbershop","city":"Birmingham","contact_email":"info@northside.example","plan_code":"starter","status":"Pending","created_at":"2026-02-03T09:00:00Z","locations_count":1,"appointment_count":0},
        {"name":"Forma Hair House","category":"Hair salon","city":"Bristol","contact_email":"hello@forma.example","plan_code":"growth","status":"Active","created_at":"2026-02-07T09:00:00Z","locations_count":2,"appointment_count":816},
        {"name":"Common Ground Barber","category":"Barbershop","city":"Leeds","contact_email":"team@commonground.example","plan_code":"starter","status":"Suspended","created_at":"2026-02-11T09:00:00Z","locations_count":1,"appointment_count":209},
        {"name":"Atelier No. 4","category":"Beauty studio","city":"London","contact_email":"studio@atelier4.example","plan_code":"pro","status":"Active","created_at":"2026-02-16T09:00:00Z","locations_count":4,"appointment_count":1508},
        {"name":"Goodform Collective","category":"Hair salon","city":"Brighton","contact_email":"hello@goodform.example","plan_code":"growth","status":"Pending","created_at":"2026-02-20T09:00:00Z","locations_count":1,"appointment_count":0},
        {"name":"District Fade Co.","category":"Barbershop","city":"Liverpool","contact_email":"contact@districtfade.example","plan_code":"starter","status":"Active","created_at":"2026-02-24T09:00:00Z","locations_count":1,"appointment_count":543},
        {"name":"Sage & Strand","category":"Hair salon","city":"Oxford","contact_email":"hello@sagestrand.example","plan_code":"growth","status":"Active","created_at":"2026-03-02T09:00:00Z","locations_count":2,"appointment_count":632},
        {"name":"Studio Meridian","category":"Beauty studio","city":"Cardiff","contact_email":"team@meridian.example","plan_code":"pro","status":"Pending","created_at":"2026-03-06T09:00:00Z","locations_count":1,"appointment_count":0}
      ]
    $mockup_businesses$::jsonb) as x(
      name text,
      category text,
      city text,
      contact_email text,
      plan_code text,
      status text,
      created_at timestamptz,
      locations_count integer,
      appointment_count integer
    )
  loop
    if not exists (
      select 1 from public.businesses where contact_email = item.contact_email
    ) then
      insert into public.businesses (
        name, category, city, contact_email, plan_code, status,
        locations_count, appointment_count, created_at, updated_at
      ) values (
        item.name, item.category, item.city, item.contact_email, item.plan_code,
        item.status, item.locations_count, item.appointment_count,
        item.created_at, item.created_at
      );
    end if;

    if item.status = 'Pending' then
      insert into public.business_applications (
        business_id, requested_plan_code, status, notes, created_at, updated_at
      )
      select b.id, b.plan_code, 'Pending', 'Seeded from the Smart Admin mockup.', item.created_at, item.created_at
      from public.businesses b
      where b.contact_email = item.contact_email
        and not exists (
          select 1
          from public.business_applications a
          where a.business_id = b.id and a.status = 'Pending'
        );
    end if;
  end loop;
end;
$$;

do $$
declare
  item record;
  business_id_value uuid;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_subscriptions$
      [
        {"contact_email":"hello@moderncut.example","period_start":"2026-03-01","period_end":"2026-03-31"},
        {"contact_email":"team@oliveivy.example","period_start":"2026-03-01","period_end":"2026-03-31"},
        {"contact_email":"hello@forma.example","period_start":"2026-03-01","period_end":"2026-03-31"},
        {"contact_email":"studio@atelier4.example","period_start":"2026-03-01","period_end":"2026-03-31"},
        {"contact_email":"contact@districtfade.example","period_start":"2026-03-01","period_end":"2026-03-31"},
        {"contact_email":"hello@sagestrand.example","period_start":"2026-03-01","period_end":"2026-03-31"}
      ]
    $mockup_subscriptions$::jsonb) as x(
      contact_email text,
      period_start date,
      period_end date
    )
  loop
    select id into business_id_value
    from public.businesses
    where contact_email = item.contact_email;

    if business_id_value is not null and not exists (
      select 1 from public.subscriptions
      where business_id = business_id_value
    ) then
      insert into public.subscriptions (
        business_id, plan_code, status, current_period_start, current_period_end,
        created_at, updated_at
      )
      select business_id_value, b.plan_code, 'Active', item.period_start, item.period_end,
        item.period_start::timestamptz, item.period_start::timestamptz
      from public.businesses b
      where b.id = business_id_value;
    end if;
  end loop;
end;
$$;

do $$
declare
  item record;
  business_id_value uuid;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_licences$
      [
        {"contact_email":"hello@moderncut.example","plan_code":"growth","seats_allocated":12,"expires_at":"2026-03-15","status":"Active"},
        {"contact_email":"team@oliveivy.example","plan_code":"pro","seats_allocated":28,"expires_at":"2026-03-24","status":"Active"},
        {"contact_email":"team@commonground.example","plan_code":"starter","seats_allocated":3,"expires_at":"2026-03-02","status":"Inactive"},
        {"contact_email":"studio@atelier4.example","plan_code":"pro","seats_allocated":36,"expires_at":"2026-04-08","status":"Active"}
      ]
    $mockup_licences$::jsonb) as x(
      contact_email text,
      plan_code text,
      seats_allocated integer,
      expires_at date,
      status text
    )
  loop
    select id into business_id_value
    from public.businesses
    where contact_email = item.contact_email;

    if business_id_value is not null and not exists (
      select 1 from public.licences
      where business_id = business_id_value
    ) then
      insert into public.licences (
        business_id, plan_code, seats_allocated, seat_limit, status,
        expires_at, created_at, updated_at
      ) values (
        business_id_value, item.plan_code, item.seats_allocated,
        case item.plan_code when 'starter' then 3 when 'growth' then 15 else null end,
        item.status, item.expires_at, item.expires_at::timestamptz, item.expires_at::timestamptz
      );
    end if;
  end loop;
end;
$$;

do $$
declare
  item record;
  business_id_value uuid;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_customers$
      [
        {"business_name":"The Modern Cut","full_name":"Amelia R.","visits":8,"joined_at":"2026-02-02"},
        {"business_name":"Olive & Ivy Studio","full_name":"Jordan P.","visits":4,"joined_at":"2026-01-16"},
        {"business_name":"Atelier No. 4","full_name":"Taylor M.","visits":12,"joined_at":"2025-12-12"},
        {"business_name":"Forma Hair House","full_name":"Morgan S.","visits":2,"joined_at":"2026-02-22"}
      ]
    $mockup_customers$::jsonb) as x(
      business_name text,
      full_name text,
      visits integer,
      joined_at date
    )
  loop
    select id into business_id_value
    from public.businesses
    where name = item.business_name;

    if business_id_value is not null and not exists (
      select 1 from public.customers
      where business_id = business_id_value and full_name = item.full_name
    ) then
      insert into public.customers (
        business_id, full_name, status, visits, joined_at, created_at, updated_at
      ) values (
        business_id_value, item.full_name, 'Active', item.visits, item.joined_at,
        item.joined_at::timestamptz, item.joined_at::timestamptz
      );
    end if;
  end loop;
end;
$$;

do $$
declare
  item record;
  business_id_value uuid;
  customer_id_value uuid;
  service_id_value uuid;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_appointments$
      [
        {"appointment_code":"APT-83124","business_name":"The Modern Cut","customer_name":"Amelia R.","service_name":"Classic cut","starts_at":"2026-03-08T10:30:00Z","ends_at":"2026-03-08T11:15:00Z","status":"Confirmed","duration_minutes":45,"price":28},
        {"appointment_code":"APT-83123","business_name":"Olive & Ivy Studio","customer_name":"Jordan P.","service_name":"Colour & style","starts_at":"2026-03-08T11:00:00Z","ends_at":"2026-03-08T12:30:00Z","status":"Confirmed","duration_minutes":90,"price":68},
        {"appointment_code":"APT-83122","business_name":"Forma Hair House","customer_name":"Morgan S.","service_name":"Blow dry","starts_at":"2026-03-07T15:30:00Z","ends_at":"2026-03-07T16:15:00Z","status":"Completed","duration_minutes":45,"price":32},
        {"appointment_code":"APT-83121","business_name":"District Fade Co.","customer_name":null,"service_name":"Skin fade","starts_at":"2026-03-07T14:00:00Z","ends_at":"2026-03-07T14:45:00Z","status":"Cancelled","duration_minutes":45,"price":26}
      ]
    $mockup_appointments$::jsonb) as x(
      appointment_code text,
      business_name text,
      customer_name text,
      service_name text,
      starts_at timestamptz,
      ends_at timestamptz,
      status text,
      duration_minutes integer,
      price numeric
    )
  loop
    select id into business_id_value
    from public.businesses
    where name = item.business_name;

    select id into customer_id_value
    from public.customers
    where business_id = business_id_value and full_name = item.customer_name;

    select id into service_id_value
    from public.services
    where business_id = business_id_value and name = item.service_name;

    if service_id_value is null and business_id_value is not null then
      insert into public.services (
        business_id, name, duration_minutes, price, created_at, updated_at
      ) values (
        business_id_value, item.service_name, item.duration_minutes, item.price,
        item.starts_at, item.starts_at
      ) returning id into service_id_value;
    end if;

    if business_id_value is not null and not exists (
      select 1 from public.appointments where appointment_code = item.appointment_code
    ) then
      insert into public.appointments (
        business_id, customer_id, service_id, appointment_code,
        starts_at, ends_at, status, created_at, updated_at
      ) values (
        business_id_value, customer_id_value, service_id_value, item.appointment_code,
        item.starts_at, item.ends_at, item.status, item.starts_at, item.starts_at
      );
    end if;
  end loop;
end;
$$;

do $$
declare
  item record;
  business_id_value uuid;
begin
  for item in
    select *
    from jsonb_to_recordset($mockup_tickets$
      [
        {"ticket_code":"SUP-2048","subject":"Appointment sync delay","category":"Technical incident","business_name":"The Modern Cut","status":"Open","created_at":"2026-03-08T09:42:00Z"},
        {"ticket_code":"SUP-2047","subject":"Billing invoice request","category":"Account enquiry","business_name":"Olive & Ivy Studio","status":"Review","created_at":"2026-03-07T09:42:00Z"},
        {"ticket_code":"SUP-2046","subject":"Booking cancellation question","category":"Customer complaint","business_name":"District Fade Co.","status":"Resolved","created_at":"2026-03-04T09:42:00Z"},
        {"ticket_code":"SUP-2045","subject":"Notification not delivered","category":"Technical incident","business_name":"Atelier No. 4","status":"Open","created_at":"2026-03-03T09:42:00Z"}
      ]
    $mockup_tickets$::jsonb) as x(
      ticket_code text,
      subject text,
      category text,
      business_name text,
      status text,
      created_at timestamptz
    )
  loop
    select id into business_id_value
    from public.businesses
    where name = item.business_name;

    if not exists (
      select 1 from public.support_tickets where ticket_code = item.ticket_code
    ) then
      insert into public.support_tickets (
        ticket_code, business_id, subject, category, status, priority,
        body, created_at, updated_at
      ) values (
        item.ticket_code, business_id_value, item.subject, item.category,
        item.status, case when item.status = 'Open' then 'High' else 'Normal' end,
        'Seeded from the Smart Admin mockup.', item.created_at, item.created_at
      );
    end if;
  end loop;
end;
$$;

insert into public.system_health_checks (service_name, status, latency_ms, details, checked_at)
select service_name, 'Operational', latency_ms,
  jsonb_build_object('source', 'smart-admin-mockup'), '2026-03-08T09:42:00Z'::timestamptz
from (values
  ('Application', 48),
  ('Backend connectivity', 48),
  ('Database', 12),
  ('Authentication activity', 34),
  ('Booking service', 67),
  ('Notification delivery', 91)
) as health(service_name, latency_ms)
where not exists (
  select 1 from public.system_health_checks h
  where h.service_name = health.service_name
);

insert into public.billing_transactions (
  business_id, subscription_id, amount, currency, type, status,
  external_reference, occurred_at
)
select b.id, s.id, p.monthly_price, 'GBP', 'Subscription', 'Paid',
  'mockup-' || b.contact_email, '2026-03-01T09:00:00Z'::timestamptz
from public.businesses b
join public.subscriptions s on s.business_id = b.id
join public.subscription_plans p on p.code = s.plan_code
where b.status = 'Active'
  and not exists (
    select 1 from public.billing_transactions t
    where t.external_reference = 'mockup-' || b.contact_email
  );

insert into public.platform_settings (key, value, description)
values (
  'workspace.mockup_seed',
  jsonb_build_object('source', 'admin/technicians/smart-admin.html', 'seeded_at', '2026-03-08'),
  'Identifies the initial Smart Admin records that were copied from the prototype.'
)
on conflict (key) do update set
  value = excluded.value,
  description = excluded.description,
  updated_at = now();

insert into public.audit_logs (actor_id, action, entity_type, after_data, created_at)
select null, activity.action, 'system_activity',
  jsonb_build_object('summary', activity.summary, 'source', 'smart-admin-mockup'),
  activity.created_at
from (values
  ('seed', 'New business application received', '2026-03-08T09:42:00Z'::timestamptz),
  ('seed', 'Subscription renewal processed', '2026-03-08T08:18:00Z'::timestamptz),
  ('seed', 'Notification retry completed', '2026-03-07T16:05:00Z'::timestamptz),
  ('seed', 'Business status updated', '2026-03-07T13:30:00Z'::timestamptz)
) as activity(action, summary, created_at)
where not exists (
  select 1 from public.audit_logs a
  where a.entity_type = 'system_activity'
    and a.after_data ->> 'summary' = activity.summary
);

comment on column public.businesses.appointment_count is 'Initial platform aggregate copied from the dashboard mockup; replace with a maintained aggregate when booking ingestion is connected.';
comment on column public.customers.visits is 'Initial visit count copied from the dashboard mockup.';
comment on column public.customers.joined_at is 'Original customer join date shown in the dashboard mockup.';
comment on column public.appointments.appointment_code is 'Human-readable booking reference shown in the admin dashboard.';
comment on column public.support_tickets.ticket_code is 'Human-readable support reference shown in the admin dashboard.';
