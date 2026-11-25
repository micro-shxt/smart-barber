-- The production-safe mockup data is also defined in the migration so `supabase
-- db push` creates it on hosted projects. Local `supabase db reset` applies
-- migrations first and then reaches this file. These business rows are therefore
-- intentionally idempotent and remain the first mockup entries.
--
-- Do not create Auth users or grant platform_admin from this file. Auth identities
-- and administrator roles must be created deliberately by an operator.

do $$
declare
  item record;
begin
  for item in
    select *
    from jsonb_to_recordset($seed_businesses$
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
    $seed_businesses$::jsonb) as x(
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
  end loop;
end;
$$;
