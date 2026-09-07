-- ============================================================
-- Migration 20260903000020: Feed Radius PostGIS & Payment Bucket
-- ============================================================

-- 1. Setup storage bucket payments untuk bukti transfer P2P customer
insert into storage.buckets (id, name, public)
values ('payments', 'payments', true)
on conflict (id) do update set public = true;

drop policy if exists "payments_select_all" on storage.objects;
create policy "payments_select_all"
  on storage.objects for select
  to public, anon, authenticated
  using ( bucket_id = 'payments' );

drop policy if exists "payments_insert_authenticated" on storage.objects;
create policy "payments_insert_authenticated"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'payments'
    and (storage.foldername(name))[1] is not null
    and (storage.foldername(name))[1] <> ''
  );

-- 2. Tambah kolom payment_proof_url di price_agreements jika belum ada
alter table public.price_agreements
  add column if not exists payment_proof_url text;

-- 3. Policy agar customer pemilik job boleh upload/update payment_proof_url di nota pending
drop policy if exists "price_agreements_customer_proof" on public.price_agreements;
create policy "price_agreements_customer_proof"
  on public.price_agreements for update
  to authenticated
  using (
    customer_id = auth.uid()
    and status = 'pending'
    and voided = false
  )
  with check (
    customer_id = auth.uid()
    and status = 'pending'
    and voided = false
  );

-- Perbarui trigger guard agar perubahan payment_proof_url diizinkan
create or replace function public.price_agreements_guard()
returns trigger
language plpgsql
as $$
begin
  if new.amount <> old.amount
     or new.payment_method <> old.payment_method
     or new.customer_id <> old.customer_id
     or new.provider_id <> old.provider_id then
    raise exception 'Nota tidak dapat diubah setelah dibuat (harga & metode tetap)';
  end if;

  -- Izinkan update payment_proof_url saat pending
  if old.status = 'pending' and new.status = 'pending' then
    return new;
  end if;

  -- status hanya boleh pending -> paid
  if not (old.status = 'pending' and new.status in ('pending', 'paid')) then
    raise exception 'Transisi status nota tidak valid';
  end if;

  -- paid_at wajib terisi saat paid
  if new.status = 'paid' and new.paid_at is null then
    new.paid_at := now();
  end if;

  return new;
end;
$$;

-- 4. RPC get_open_jobs_for_tukang:
-- Filter jobs berstatus open berdasarkan:
-- - Posisi tukang & jangkauan service_radius_km miliknya (PostGIS)
-- - Kategori keahlian (service_type_ids) milik tukang
-- - Tukang belum merespon job tsb
create or replace function public.get_open_jobs_for_tukang(
  p_provider_id uuid default auth.uid()
)
returns table (
  id uuid,
  customer_id uuid,
  category_id uuid,
  title text,
  description text,
  lat double precision,
  lng double precision,
  status public.job_status,
  selected_provider_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  category_name text,
  distance_meters double precision
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_prov_lat double precision;
  v_prov_lng double precision;
  v_radius_km integer;
  v_service_ids uuid[];
  v_is_online boolean;
  v_is_suspended boolean;
begin
  -- Ambil data tukang
  select p.lat, p.lng, p.is_online, p.is_suspended,
         tp.service_radius_km, tp.service_type_ids
    into v_prov_lat, v_prov_lng, v_is_online, v_is_suspended,
         v_radius_km, v_service_ids
    from public.profiles p
    join public.tukang_profiles tp on tp.profile_id = p.id
   where p.id = coalesce(p_provider_id, auth.uid());

  if v_is_suspended = true then
    return;
  end if;

  -- Jika koordinat belum terisi atau radius 0, fallback: jika radius 0 tidak ada job
  if v_radius_km is not null and v_radius_km <= 0 then
    return;
  end if;

  return query
  select
    j.id,
    j.customer_id,
    j.category_id,
    j.title,
    j.description,
    j.lat,
    j.lng,
    j.status,
    j.selected_provider_id,
    j.created_at,
    j.updated_at,
    c.name as category_name,
    case
      when v_prov_lat is not null and v_prov_lng is not null then
        st_distance(
          geography(ST_MakePoint(v_prov_lng, v_prov_lat)),
          geography(ST_MakePoint(j.lng, j.lat))
        )
      else 0.0
    end as distance_meters
  from public.jobs j
  left join public.service_categories c on c.id = j.category_id
  where j.status = 'open'
    -- Belum pernah di-apply oleh provider ini
    and not exists (
      select 1 from public.job_applications ja
      where ja.job_id = j.id and ja.provider_id = coalesce(p_provider_id, auth.uid())
    )
    -- Filter kategori keahlian jika provider memiliki spesialisasi terdaftar
    and (
      v_service_ids is null
      or cardinality(v_service_ids) = 0
      or j.category_id = any(v_service_ids)
    )
    -- Filter jarak radius jika tukang memiliki lokasi GPS
    and (
      v_prov_lat is null
      or v_prov_lng is null
      or st_dwithin(
        geography(ST_MakePoint(v_prov_lng, v_prov_lat)),
        geography(ST_MakePoint(j.lng, j.lat)),
        coalesce(v_radius_km, 50) * 1000
      )
    )
  order by j.created_at desc
  limit 50;
end;
$$;

grant execute on function public.get_open_jobs_for_tukang(uuid) to authenticated;
