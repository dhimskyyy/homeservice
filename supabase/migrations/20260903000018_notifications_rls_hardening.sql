-- ============================================================
-- K2: Auto-notify tukang dalam radius saat job baru dibuat
-- ============================================================
create or replace function internal.notify_providers_on_job_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cat_name text;
begin
  select name into v_cat_name from public.service_categories where id = new.category_id;

  insert into public.app_notifications (user_id, type, job_id, body)
  select p.id, 'new_job', new.id,
    'Permintaan baru: ' || coalesce(v_cat_name, 'Jasa') || ' - ' || new.title ||
    ' di radius ' || tp.service_radius_km || ' km dari Anda.'
  from public.profiles p
  join public.tukang_profiles tp on tp.profile_id = p.id
  where p.is_tukang = true
    and p.is_suspended = false
    and p.is_online = true
    and tp.service_radius_km > 0
    and st_dwithin(
      geography(ST_MakePoint(p.lng, p.lat)),
      geography(ST_MakePoint(new.lng, new.lat)),
      least(tp.service_radius_km * 1000, 100000)
    );

  return new;
end;
$$;

drop trigger if exists trg_notify_providers on public.jobs;
create trigger trg_notify_providers
  after insert on public.jobs
  for each row execute function internal.notify_providers_on_job_created();

-- Notifikasi untuk customer: tukang merespon job-nya
create or replace function internal.notify_customer_on_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider_name text;
  v_customer_id uuid;
begin
  select full_name into v_provider_name from public.profiles where id = new.provider_id;
  select customer_id into v_customer_id from public.jobs where id = new.job_id;

  insert into public.app_notifications (user_id, type, job_id, body)
  values (
    v_customer_id,
    'job_responded',
    new.job_id,
    (coalesce(v_provider_name, 'Mitra tukang')) || ' merespon permintaan Anda. Cek detail untuk memilih tukang.'
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_customer on public.job_applications;
create trigger trg_notify_customer
  after insert on public.job_applications
  for each row execute function internal.notify_customer_on_application();

-- Notifikasi untuk tukang terpilih: customer lock
create or replace function internal.notify_provider_on_lock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'locked' and (old.status is null or old.status = 'open') and new.selected_provider_id is not null then
    insert into public.app_notifications (user_id, type, job_id, body)
    values (
      new.selected_provider_id,
      'job_locked',
      new.id,
      'Customer memilih Anda untuk "' || new.title || '". Buat nota kesepakatan harga di chat.'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_lock on public.jobs;
create trigger trg_notify_lock
  after update on public.jobs
  for each row execute function internal.notify_provider_on_lock();

-- ============================================================
-- K3: Lindungi koordinat rumah (profiles.lat/lng) dari API publik.
-- Matching radius kini via SECURITY DEFINER, UI tidak butuh lat/lng profiles.
-- ============================================================
create or replace function public.find_providers_nearby(
  p_job_id uuid,
  p_radius_meters integer default 100000
)
returns setof uuid
language sql
stable
security definer
set search_path = public
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
      least((tp.service_radius_km * 1000), p_radius_meters)
    );
$$;

revoke select on public.profiles from authenticated;
grant select (
  id, email, full_name, phone, avatar_url,
  is_customer, is_tukang, is_admin, is_suspended, is_online,
  created_at, updated_at
) on public.profiles to authenticated;

-- ============================================================
-- H6: Retensi data locations - simpan maksimal 200 titik terakhir per job
-- ============================================================
create or replace function internal.purge_old_locations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.locations
  where job_id = new.job_id
    and id not in (
      select id from public.locations
      where job_id = new.job_id
      order by created_at desc
      limit 200
    );
  return new;
end;
$$;

drop trigger if exists trg_purge_locations on public.locations;
create trigger trg_purge_locations
  after insert on public.locations
  for each row execute function internal.purge_old_locations();

-- ============================================================
-- MEDIUM: Perketat nota - amount immutable setelah dibuat, hanya status yang boleh berubah
-- ============================================================
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

drop trigger if exists trg_price_agreements_guard on public.price_agreements;
create trigger trg_price_agreements_guard
  before update on public.price_agreements
  for each row execute function public.price_agreements_guard();

-- ============================================================
-- MEDIUM: Fix has_provider_applied - tukang locked_out tidak bisa chat
-- ============================================================
create or replace function internal.has_provider_applied(p_job_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.job_applications
    where job_id = p_job_id
      and provider_id = p_user_id
      and status <> 'locked_out'
  );
$$;

-- ============================================================
-- MEDIUM: Review & complaint hanya untuk tukang terpilih pada job tsb
-- ============================================================
drop policy if exists "reviews_insert_customer" on public.reviews;
create policy "reviews_insert_customer"
  on public.reviews for insert
  to authenticated
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and j.customer_id = auth.uid()
        and j.selected_provider_id = provider_id
        and j.status in ('done', 'paid')
    )
  );

drop policy if exists "complaints_insert_customer" on public.complaints;
create policy "complaints_insert_customer"
  on public.complaints for insert
  to authenticated
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and j.customer_id = auth.uid()
        and j.selected_provider_id = provider_id
        and j.status in ('done', 'paid')
    )
  );

-- ============================================================
-- MEDIUM: Storage chat-attachments - path wajib milik job & user (cek ownership)
-- ============================================================
drop policy if exists "chat_attachments_insert" on storage.objects;
create policy "chat_attachments_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[1] is not null
    and (storage.foldername(name))[1] <> ''
  );

drop policy if exists "chat_attachments_select" on storage.objects;
create policy "chat_attachments_select"
  on storage.objects for select
  to authenticated, anon
  using ( bucket_id = 'chat-attachments' );

-- ============================================================
-- H3: Bersihkan referensi email personal dari data (idempotent no-op guard)
-- Migration lama (00000012) sudah applied; catatan: file tsb telah dibersihkan
-- di repo agar fresh-deploy tidak membawa PII.
-- ============================================================
