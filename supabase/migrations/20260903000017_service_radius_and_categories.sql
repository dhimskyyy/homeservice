-- 1. Tambah 7 kategori jasa baru
insert into public.service_categories (name, slug, icon, sort_order) values
  ('Servis Motor', 'servis-motor', 'two_wheeler', 6),
  ('Servis Mobil', 'servis-mobil', 'directions_car', 7),
  ('Elektronik', 'elektronik', 'devices_other', 8),
  ('Besi & Baja', 'besi-baja', 'construction', 9),
  ('Jahit', 'jahit', 'checkroom', 10),
  ('Tambal Ban', 'tambal-ban', 'tire_repair', 11),
  ('Las', 'las', 'local_fire_department', 12)
on conflict (slug) do nothing;

-- 2. Tambah kolom radius jangkauan custom per tukang (0-100 km, default 50)
alter table public.tukang_profiles
  add column if not exists service_radius_km integer not null default 50
    check (service_radius_km between 0 and 100);

-- 3. RPC find_providers_nearby: radius kini custom per tukang
-- Tukang ditemukan jika jarak customer dari posisi tukang <= service_radius_km miliknya.
-- Parameter p_radius_meters masih didukung sebagai batas maksimum (opsional).
create or replace function public.find_providers_nearby(
  p_job_id uuid,
  p_radius_meters integer default 100000
)
returns setof uuid
language sql
stable
security invoker
as $$
  select p.id
  from public.profiles p
  join public.jobs j on j.id = p_job_id
  join public.tukang_profiles tp on tp.profile_id = p.id
  where p.is_tukang = true
    and p.is_suspended = false
    and p.is_online = true
    and tp.service_radius_km > 0
    and st_dwithin(
      geography(ST_MakePoint(p.lng, p.lat)),
      geography(ST_MakePoint(j.lng, j.lat)),
      least(
        (tp.service_radius_km * 1000),
        p_radius_meters
      )
    );
$$;
