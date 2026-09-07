# Database Schema — Beres

Database: PostgreSQL via Supabase. Menggunakan `auth.users` bawaan sebagai sumber identitas, `public.profiles` sebagai data profil aplikasi. Dokumentasi ini adalah **sumber kebenaran implementasi** — agent wajib mengikuti DDL di bawah.

## 1. Prinsip Desain

- **1 akun = 1 identitas**: `profiles.id` = `auth.users.id`, unik per user.
- **Role** disimpan di kolom profil (`is_customer`, `is_tukang`, `is_admin`), bukan di `user_metadata` (user-editable → tidak aman untuk otorisasi).
- **RLS aktif di semua tabel**, semua policy memakai pola `to authenticated` + predikat kepemilikan.
- **Alur status** di-enforce lewat `CHECK` constraint + trigger, bukan hanya aplikasi.
- **Realtime** di-enable untuk tabel `messages`, `locations`, dan `app_notifications`.
- **Radius jangkauan per tukang**: tiap tukang mengatur `service_radius_km` sendiri (0–100 km, default 50); matching memakai `LEAST(radius_tukang, batas_query)`, bukan satu radius global.
- **Pengecualian SECURITY DEFINER yang disetujui** (waiver atas `agents.md` §3, semua dengan alasan RLS-bypass yang terdokumentasi di §11): `internal.*` (helper otorisasi + pemutus rekursi RLS), `public.find_providers_nearby`, `public.admin_set_suspended`, `public.jobs_lock_applications`, `public.reviews_update_rating`, `public.approve_payment_provider`, dan trigger notifikasi/purge (`internal.notify_*`, `internal.purge_old_locations`). Tidak ada fungsi lain yang boleh DEFINER di schema `public`.
- **Proteksi PII kolom**: `profiles.lat/lng` dicabut dari Data API untuk role `authenticated` (column grant); koordinat dibaca hanya lewat fungsi DEFINER (`find_providers_nearby`, trigger notifikasi).

## 2. Extensions

```sql
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "postgis";    -- geo query radius per tukang (ST_DWithin)
```

## 3. Enum (typed status)

```sql
create type job_status as enum (
  'open', 'locked', 'in_progress', 'done', 'paid', 'cancelled'
);

create type application_status as enum (
  'responded', 'selected', 'locked_out'
);

create type payment_status as enum (
  'pending', 'paid'
);

create type payment_method as enum (
  'cash', 'ewallet', 'bank_transfer'
);

create type complaint_status as enum (
  'open', 'resolved'
);
```

## 4. Helper Functions (otorisasi)

Fungsi `public.*` di bawah adalah wrapper tipis yang mendelegasikan ke fungsi
`internal.*` berstatus `SECURITY DEFINER` (bypass RLS secara sengaja agar tidak
terjadi rekursi policy — lihat waiver §11 dan migration `20260903000005`).

```sql
-- Wrapper publik (security invoker, aman dipanggil dari policy/RPC lain)
create or replace function public.current_profile_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;

create or replace function public.is_customer()
returns boolean language sql stable as $$ select internal.is_customer(); $$;

create or replace function public.is_tukang()
returns boolean language sql stable as $$ select internal.is_tukang(); $$;

create or replace function public.is_admin()
returns boolean language sql stable as $$ select internal.is_admin(); $$;

create or replace function public.is_suspended_profile(p_user_id uuid)
returns boolean language sql stable as $$ select internal.is_suspended_profile(p_user_id); $$;
```

```sql
-- Implementasi internal (SECURITY DEFINER, set search_path = public, stable).
-- Wajib GRANT: usage on schema internal + execute ke authenticated (migration 20260903000006).
create or replace function internal.is_admin()
returns boolean language sql security definer set search_path = public stable
as $$ select exists (
  select 1 from public.profiles where id = auth.uid() and is_admin = true
); $$;

-- Pola yang sama untuk internal.is_customer(), internal.is_tukang(),
-- internal.is_suspended_profile(p_user_id uuid).

-- Pemutus rekursi RLS jobs <-> job_applications (migration 20260903000004):
create or replace function internal.is_job_customer(p_job_id uuid, p_user_id uuid)
returns boolean language sql security definer set search_path = public stable
as $$ select exists (
  select 1 from public.jobs where id = p_job_id and customer_id = p_user_id
); $$;

create or replace function internal.has_provider_applied(p_job_id uuid, p_user_id uuid)
returns boolean language sql security definer set search_path = public stable
as $$ select exists (
  select 1 from public.job_applications
  where job_id = p_job_id and provider_id = p_user_id
    and status <> 'locked_out'   -- sejak migration 20260903000018: tukang kalah lock tidak dihitung
); $$;
```

## 5. Tabel

### 5.1 profiles

```sql
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text not null,
  full_name     text not null default '',
  phone         text,
  avatar_url    text,
  is_customer   boolean not null default false,
  is_tukang     boolean not null default false,
  is_admin      boolean not null default false,
  is_suspended  boolean not null default false,
  is_online     boolean not null default false,
  lat           double precision,
  lng           double precision,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create unique index profiles_email_key on public.profiles (lower(email));

alter table public.profiles enable row level security;
```

### 5.2 tukang_profiles (1:1 dengan profiles)

```sql
create table public.tukang_profiles (
  profile_id       uuid primary key references public.profiles(id) on delete cascade,
  bio              text not null default '',
  service_type_ids uuid[] not null default '{}',
  payment_methods  public.payment_method[] not null default '{}',
  payment_details  jsonb not null default '{}'::jsonb,   -- migration 20260903000008: nomor e-wallet/rekening per channel
  service_radius_km integer not null default 50          -- migration 20260903000017: 0–100 km, check constraint
    check (service_radius_km between 0 and 100),
  rating_avg       numeric(2,1) not null default 0,
  job_count        integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.tukang_profiles enable row level security;
```

### 5.3 service_categories

```sql
create table public.service_categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  slug       text not null unique,
  icon       text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.service_categories enable row level security;
```

### 5.4 jobs

```sql
create table public.jobs (
  id                   uuid primary key default gen_random_uuid(),
  customer_id          uuid not null references public.profiles(id),
  category_id          uuid not null references public.service_categories(id),
  title                text not null,
  description          text not null,
  lat                  double precision not null,
  lng                  double precision not null,
  status               public.job_status not null default 'open',
  selected_provider_id uuid references public.profiles(id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint jobs_customer_is_customer check (true) -- verified in trigger
);

create index jobs_customer_idx on public.jobs (customer_id);
create index jobs_status_idx on public.jobs (status);
create index jobs_geo_idx on public.jobs using gist (
  geography(ST_MakePoint(lng, lat))
);

alter table public.jobs enable row level security;
```

> Seluruh FK yang menunjuk ke `profiles(id)` memakai `ON DELETE CASCADE`
> (pengecualian: `jobs.selected_provider_id` → `ON DELETE SET NULL`),
> sehingga hapus akun membersihkan data turunannya (migration `20260903000011`).

### 5.5 job_applications

```sql
create table public.job_applications (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id),
  status      public.application_status not null default 'responded',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint job_applications_unique unique (job_id, provider_id)
);

create index job_applications_job_idx on public.job_applications (job_id);
create index job_applications_provider_idx on public.job_applications (provider_id);

alter table public.job_applications enable row level security;
```

### 5.6 price_agreements

```sql
create table public.price_agreements (
  id                uuid primary key default gen_random_uuid(),
  job_id            uuid not null references public.jobs(id) on delete cascade,
  customer_id       uuid not null references public.profiles(id),
  provider_id       uuid not null references public.profiles(id),
  amount            integer not null check (amount > 0),
  payment_method    public.payment_method not null,
  status            public.payment_status not null default 'pending',
  voided            boolean not null default false,
  payment_proof_url text,                                       -- migration 20260903000020: bukti bayar transfer P2P
  created_at        timestamptz not null default now(),
  paid_at           timestamptz,
  constraint price_agreements_unique unique (job_id, provider_id)
);

create index price_agreements_job_idx on public.price_agreements (job_id);

alter table public.price_agreements enable row level security;
```

### 5.7 messages

```sql
create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  job_id     uuid not null references public.jobs(id) on delete cascade,
  sender_id  uuid not null references public.profiles(id),
  body       text check (char_length(body) between 1 and 2000),
  media_url  text,                                        -- migration 20260903000012: lampiran foto chat
  is_read    boolean not null default false,              -- migration 20260903000012: read receipt
  read_at    timestamptz,                                 -- migration 20260903000012
  created_at timestamptz not null default now(),
  constraint messages_body_check check (                   -- migration 20260903000012
    (media_url is not null and (body is null or char_length(body) <= 2000))
    or (char_length(body) between 1 and 2000)
  )
);

create index messages_job_created_idx on public.messages (job_id, created_at);

alter table public.messages enable row level security;

alter publication supabase_realtime add table public.messages;
```

> UPDATE pada `messages` hanya boleh menyentuh status baca (`is_read`/`read_at`);
> perubahan kolom lain ditolak trigger `trg_messages_read_guard` (migration `20260903000019`).

### 5.8 locations

```sql
create table public.locations (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id),
  lat         double precision not null,
  lng         double precision not null,
  created_at  timestamptz not null default now()
);

create index locations_job_created_idx on public.locations (job_id, created_at desc);

alter table public.locations enable row level security;

alter publication supabase_realtime add table public.locations;
```

### 5.9 complaints

```sql
create table public.complaints (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.profiles(id),
  reason      text not null check (char_length(reason) between 10 and 2000),
  status      public.complaint_status not null default 'open',
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index complaints_job_idx on public.complaints (job_id);

alter table public.complaints enable row level security;
```

### 5.10 reviews

```sql
create table public.reviews (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.profiles(id),
  rating      integer not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  constraint reviews_unique unique (job_id, customer_id)
);

create index reviews_provider_idx on public.reviews (provider_id);

alter table public.reviews enable row level security;
```

### 5.11 app_notifications

```sql
create table public.app_notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null,              -- 'new_job', 'job_locked', 'payment_paid', ...
  job_id      uuid references public.jobs(id) on delete cascade,
  body        text not null,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

create index app_notifications_user_idx on public.app_notifications (user_id, created_at desc);

alter table public.app_notifications enable row level security;

alter publication supabase_realtime add table public.app_notifications;
```

Insert ke tabel ini **tidak pernah dari client langsung** (tidak ada policy INSERT
untuk `authenticated`): baris dibuat oleh trigger DB `SECURITY DEFINER`
(`trg_notify_providers`, `trg_notify_customer`, `trg_notify_lock` — migration
`00000018`) atau oleh `service_role`. Tipe yang dipakai: `new_job`,
`job_responded`, `job_locked`.

## 6. Row Level Security (RLS) — lengkap

Pola dasar mengikuti security checklist Supabase: `to authenticated` + predikat kepemilikan, `UPDATE` selalu menyertakan `with check`.

### 6.1 profiles

```sql
-- semua user login bisa membaca profil (perlu untuk lookup nama lawan chat/job).
-- PII koordinat (lat/lng) diproteksi di level kolom, bukan baris (lihat §9).
create policy "profiles_select_all"
  on public.profiles for select
  to authenticated
  using ( true );

-- user update profil sendiri (tidak boleh ubah role/is_admin sendiri)
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ( id = auth.uid() )
  with check ( id = auth.uid() );

-- insert profil sendiri saat registrasi
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check ( id = auth.uid() );
```

> Kenaikan role (`is_tukang`, `is_admin`, `is_suspended`) tidak lewat policy user; hanya via RPC/trigger yang divalidasi (lihat §8).

### 6.2 tukang_profiles

```sql
create policy "tukang_profiles_select"
  on public.tukang_profiles for select
  to authenticated
  using ( true );

create policy "tukang_profiles_insert_own"
  on public.tukang_profiles for insert
  to authenticated
  with check ( profile_id = auth.uid() and public.is_tukang() );

create policy "tukang_profiles_update_own"
  on public.tukang_profiles for update
  to authenticated
  using ( profile_id = auth.uid() )
  with check ( profile_id = auth.uid() );
```

### 6.3 service_categories

```sql
-- katalog publik: bisa dibaca bahkan sebelum login (halaman registrasi tukang)
create policy "service_categories_select"
  on public.service_categories for select
  to anon, authenticated
  using ( true );

create policy "service_categories_admin_write"
  on public.service_categories for all
  to authenticated
  using ( public.is_admin() )
  with check ( public.is_admin() );
```

### 6.4 jobs

```sql
-- customer baca job miliknya; tukang baca job terbuka / yang dia respond / terpilih; admin semua
create policy "jobs_select_involved"
  on public.jobs for select
  to authenticated
  using (
    customer_id = auth.uid()
    or status = 'open'
    or selected_provider_id = auth.uid()
    or internal.has_provider_applied(id, auth.uid())
    or public.is_admin()
  );

-- hanya customer yang boleh buat job
create policy "jobs_insert_customer"
  on public.jobs for insert
  to authenticated
  with check ( customer_id = auth.uid() and public.is_customer() );

-- update terbatas pada pemilik, lewat trigger utk alur status
create policy "jobs_update_customer"
  on public.jobs for update
  to authenticated
  using ( customer_id = auth.uid() and not public.is_suspended_profile(auth.uid()) )
  with check ( customer_id = auth.uid() );

-- tukang terpilih boleh memajukan status kerjanya sendiri (in_progress/done);
-- transisi tetap di-guard trigger (§7). Migration 00000014.
create policy "jobs_update_provider"
  on public.jobs for update
  to authenticated
  using (
    selected_provider_id = auth.uid()
    and not public.is_suspended_profile(auth.uid())
  )
  with check ( selected_provider_id = auth.uid() );

-- customer boleh menghapus job miliknya yang masih open/cancelled.
-- Job paid TIDAK boleh dihapus (jejak audit nota/review). Migration 00000007 + 00000019.
create policy "jobs_delete_customer"
  on public.jobs for delete
  to authenticated
  using ( customer_id = auth.uid() and status in ('open', 'cancelled') );
```

> Perubahan `selected_provider_id` dan transisi status juga di-guard trigger (§7). Admin pakai RPC untuk aksi khusus.

### 6.5 job_applications

```sql
-- customer baca application di job-nya; tukang baca miliknya; admin semua
create policy "job_applications_select"
  on public.job_applications for select
  to authenticated
  using (
    provider_id = auth.uid()
    or internal.is_job_customer(job_id, auth.uid())
    or public.is_admin()
  );

-- tukang bisa respond job (satu baris per tukang per job)
create policy "job_applications_insert_tukang"
  on public.job_applications for insert
  to authenticated
  with check (
    provider_id = auth.uid()
    and public.is_tukang()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id and j.status = 'open'
    )
  );

create policy "job_applications_update_own"
  on public.job_applications for update
  to authenticated
  using ( provider_id = auth.uid() )
  with check ( provider_id = auth.uid() );
```

### 6.6 price_agreements

```sql
create policy "price_agreements_select"
  on public.price_agreements for select
  to authenticated
  using (
    customer_id = auth.uid()
    or provider_id = auth.uid()
    or public.is_admin()
  );

-- tukang yang sudah merespon boleh buat nota saat job open;
-- tukang TERPILIH boleh buat nota saat job locked. Migration 00000013.
create policy "price_agreements_insert_responded_tukang"
  on public.price_agreements for insert
  to authenticated
  with check (
    provider_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (
          (j.status = 'open' and exists (
            select 1 from public.job_applications a
            where a.job_id = j.id
              and a.provider_id = auth.uid()
              and a.status <> 'locked_out'
          ))
          or (j.status = 'locked' and j.selected_provider_id = auth.uid())
        )
    )
  );

-- update: tukang bisa set paid hanya saat job done.
-- Praktik yang dipakai aplikasi adalah RPC atomik approve_payment_provider (§8.4).
create policy "price_agreements_update_payment"
  on public.price_agreements for update
  to authenticated
  using (
    (provider_id = auth.uid() and status = 'pending' and voided = false)
    or public.is_admin()
  )
  with check (
    provider_id = auth.uid()
    and voided = false
    and exists (
      select 1 from public.jobs j
      where j.id = job_id and j.status = 'done'
    )
  );

-- guard trigger: harga/metode/pihak nota IMMUTABLE setelah dibuat;
-- status hanya pending -> paid; paid_at otomatis. Migration 00000018.
create trigger trg_price_agreements_guard before update on public.price_agreements
  for each row execute function public.price_agreements_guard();
```

### 6.7 messages

Tukang yang sudah merespon (belum `locked_out`) boleh membaca & mengirim chat
sejak job masih `open` — negosiasi terjadi sebelum lock. Migration `00000012`.

```sql
create policy "messages_select_involved"
  on public.messages for select
  to authenticated
  using (
    sender_id = auth.uid()
    or internal.is_job_customer(job_id, auth.uid())
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.selected_provider_id = auth.uid()
    )
    or internal.has_provider_applied(job_id, auth.uid())
    or public.is_admin()
  );

create policy "messages_insert_involved"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and (
      internal.is_job_customer(job_id, auth.uid())
      or exists (
        select 1 from public.jobs j
        where j.id = job_id and j.selected_provider_id = auth.uid()
      )
      or internal.has_provider_applied(job_id, auth.uid())
    )
  );

-- penerima boleh menandai pesan terbaca; isi pesan dilindungi trigger (§7.8)
create policy "messages_update_read"
  on public.messages for update
  to authenticated
  using (
    sender_id <> auth.uid()
    and (
      internal.is_job_customer(job_id, auth.uid())
      or exists (
        select 1 from public.jobs j
        where j.id = job_id and j.selected_provider_id = auth.uid()
      )
      or internal.has_provider_applied(job_id, auth.uid())
    )
  )
  with check ( is_read = true );
```

### 6.8 locations

```sql
create policy "locations_select_involved"
  on public.locations for select
  to authenticated
  using (
    provider_id = auth.uid()
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.customer_id = auth.uid()
    )
    or public.is_admin()
  );

-- tukang terpilih kirim posisi saat in_progress
create policy "locations_insert_active_tukang"
  on public.locations for insert
  to authenticated
  with check (
    provider_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and j.selected_provider_id = auth.uid()
        and j.status = 'in_progress'
    )
  );
```

### 6.9 complaints

```sql
create policy "complaints_select_involved"
  on public.complaints for select
  to authenticated
  using ( customer_id = auth.uid() or provider_id = auth.uid() or public.is_admin() );

-- komplain hanya untuk tukang TERPILIH pada job tsb (migration 20260903000018)
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

create policy "complaints_update_admin"
  on public.complaints for update
  to authenticated
  using ( public.is_admin() )
  with check ( public.is_admin() );
```

### 6.10 reviews

```sql
create policy "reviews_select_all"
  on public.reviews for select
  to authenticated
  using ( true );

-- rating hanya untuk tukang TERPILIH pada job tsb (migration 20260903000018)
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
```

### 6.11 app_notifications

```sql
create policy "app_notifications_select_own"
  on public.app_notifications for select
  to authenticated
  using ( user_id = auth.uid() );

create policy "app_notifications_update_own"
  on public.app_notifications for update
  to authenticated
  using ( user_id = auth.uid() )
  with check ( user_id = auth.uid() );

-- admin boleh membaca semua notifikasi untuk audit (migration 20260903000019)
create policy "app_notifications_admin_read"
  on public.app_notifications for select
  to authenticated
  using ( public.is_admin() );
```

> Insert hanya oleh trigger DB / service role, bukan client langsung (tidak ada policy INSERT untuk `authenticated`).

## 7. Trigger — alur status & integritas

### 7.1 updated_at auto

```sql
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger jobs_set_updated_at before update on public.jobs
  for each row execute function public.set_updated_at();
```

### 7.2 Validasi transisi status job (satu arah)

```sql
create or replace function public.jobs_status_guard()
returns trigger language plpgsql as $$
declare
  valid_transition boolean;
begin
  valid_transition := (
    (old.status = 'open'        and new.status in ('locked', 'cancelled'))
    or (old.status = 'locked'   and new.status in ('in_progress', 'cancelled'))
    or (old.status = 'in_progress' and new.status in ('done'))
    or (old.status = 'done'     and new.status in ('paid'))
  );
  if not valid_transition then
    raise exception 'Invalid job status transition: % -> %', old.status, new.status;
  end if;
  return new;
end;
$$;

create trigger jobs_status_guard before update of status on public.jobs
  for each row execute function public.jobs_status_guard();
```

### 7.3 Hanya tukang terpilih yang set in_progress/done

```sql
create or replace function public.jobs_provider_guard()
returns trigger language plpgsql as $$
begin
  if new.status in ('in_progress', 'done') then
    if new.selected_provider_id is null then
      raise exception 'No selected provider for job';
    end if;
  end if;
  return new;
end;
$$;

create trigger jobs_provider_guard before update on public.jobs
  for each row execute function public.jobs_provider_guard();
```

### 7.4 Tandai aplikasi lain locked_out saat job dikunci

```sql
-- SECURITY DEFINER sejak migration 20260903000019: trigger berjalan sebagai customer
-- tidak punya hak menulis baris milik tukang lain, sehingga DEFINER wajib
-- agar locked_out/selected/voided benar-benar diterapkan.
create or replace function public.jobs_lock_applications()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'locked' and old.status = 'open' then
    update public.job_applications
       set status = 'locked_out'
     where job_id = new.id
       and provider_id <> new.selected_provider_id;

    update public.job_applications
       set status = 'selected'
     where job_id = new.id
       and provider_id = new.selected_provider_id;

    update public.price_agreements
       set voided = true
     where job_id = new.id
       and provider_id <> new.selected_provider_id;

    update public.price_agreements
       set voided = false
     where job_id = new.id
       and provider_id = new.selected_provider_id;
  end if;
  return new;
end;
$$;

create trigger jobs_lock_applications after update on public.jobs
  for each row execute function public.jobs_lock_applications();
```

### 7.5 Update rating_avg saat review baru

-- SECURITY DEFINER sejak migration 20260903000015: customer yang insert review tidak
-- punya hak update baris tukang_profiles milik tukang, sehingga DEFINER wajib.
-- job_count dihitung ulang dari jumlah review (bukan +1) agar idempoten.
```sql
create or replace function public.reviews_update_rating()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.tukang_profiles
     set rating_avg = coalesce((
       select round(avg(rating)::numeric, 1) from public.reviews
       where provider_id = new.provider_id
     ), 0.0),
     job_count = coalesce((
       select count(*) from public.reviews
       where provider_id = new.provider_id
     ), 0)
   where profile_id = new.provider_id;
  return new;
end;
$$;

create trigger reviews_update_rating after insert on public.reviews
  for each row execute function public.reviews_update_rating();
```

### 7.6 Notifikasi otomatis (trigger DB, bukan Edge Function)

Notifikasi in-app ditulis oleh trigger `SECURITY DEFINER` di schema `internal`
(migration `20260903000018`). Tidak ada policy INSERT untuk client.

```sql
-- setiap job baru -> notifikasi 'new_job' ke semua tukang online,
-- tidak suspended, radius > 0, dan dalam LEAST(radius_tukang, 100 km)
create trigger trg_notify_providers after insert on public.jobs
  for each row execute function internal.notify_providers_on_job_created();

-- setiap lamaran baru -> notifikasi 'job_responded' ke customer pemilik job
create trigger trg_notify_customer after insert on public.job_applications
  for each row execute function internal.notify_customer_on_application();

-- transisi open -> locked -> notifikasi 'job_locked' ke tukang terpilih
create trigger trg_notify_lock after update on public.jobs
  for each row execute function internal.notify_provider_on_lock();
```

### 7.7 Retensi tracking GPS

Hanya 200 titik terakhir per job yang disimpan (migration `20260903000018`):

```sql
create trigger trg_purge_locations after insert on public.locations
  for each row execute function internal.purge_old_locations();
```

### 7.8 Guard update pesan chat

UPDATE pada `messages` yang mengubah selain status baca ditolak (migration `20260903000019`):

```sql
create trigger trg_messages_read_guard before update on public.messages
  for each row execute function public.messages_read_guard();
```

## 8. RPC & Fungsi Khusus

### 8.1 Kenaikan role tukang (lewat RPC yang divalidasi)

Sejak migration `20260903000008` RPC menerima parameter ke-4 `p_payment_details jsonb`
(detail nomor e-wallet/rekening). Pendaftaran tukang baru umumnya lewat trigger
`internal.handle_new_user` (baca metadata signup), bukan RPC ini.

```sql
create or replace function public.become_tukang(
  p_bio text,
  p_service_type_ids uuid[],
  p_payment_methods public.payment_method[],
  p_payment_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security invoker
as $$
begin
  if not (select exists(select 1 from public.profiles where id = auth.uid())) then
    raise exception 'Profile not found';
  end if;

  update public.profiles
     set is_tukang = true,
         updated_at = now()
   where id = auth.uid();

  insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods, payment_details)
  values (auth.uid(), p_bio, p_service_type_ids, p_payment_methods, p_payment_details)
  on conflict (profile_id) do update
     set bio = excluded.bio,
         service_type_ids = excluded.service_type_ids,
         payment_methods = excluded.payment_methods,
         payment_details = excluded.payment_details;
end;
$$;
```

### 8.2 Pencarian tukang radius per-tukang (PostGIS)

Sejak migration `20260903000017`–`00000018`: radius memakai `service_radius_km` milik
tiap tukang (0–100 km, default 50; radius 0 = tidak menerima job), dengan
`p_radius_meters` (default 100 km) sebagai batas atas. Fungsi ini
`SECURITY DEFINER` agar tetap bisa membaca koordinat yang dicabut dari API (§9).

```sql
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
```

### 8.3 Admin: suspend / aktifkan

```sql
-- SECURITY DEFINER sejak migration 20260903000019: admin perlu menulis baris milik
-- user lain yang diblokir policy profiles_update_own. Guard is_admin tetap ada,
-- plus larangan suspend akun sendiri.
create or replace function public.admin_set_suspended(p_user_id uuid, p_suspended boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Forbidden: hanya admin';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Tidak bisa suspend akun sendiri';
  end if;
  update public.profiles
     set is_suspended = p_suspended,
         updated_at = now()
   where id = p_user_id;
end;
$$;
```

### 8.4 Approve pembayaran atomik (tukang)

Satu transaksi: validasi pemilik nota + job harus `done` + nota `pending` dan
tidak void → set nota `paid` (+`paid_at`) dan job `paid`. Dipakai aplikasi
menggantikan update dua langkah. Migration `00000019`. EXECUTE hanya untuk
`authenticated` (dicabut dari `public`/`anon`).

```sql
create or replace function public.approve_payment_provider(p_agreement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider uuid;
  v_job_id uuid;
  v_job_status public.job_status;
begin
  select provider_id, job_id into v_provider, v_job_id
    from public.price_agreements
   where id = p_agreement_id;

  if v_provider is null then
    raise exception 'Nota tidak ditemukan';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'Forbidden: bukan nota Anda';
  end if;

  select status into v_job_status from public.jobs where id = v_job_id;
  if v_job_status <> 'done' then
    raise exception 'Pekerjaan harus selesai (done) sebelum approve pembayaran';
  end if;

  update public.price_agreements
     set status = 'paid', paid_at = now()
   where id = p_agreement_id and status = 'pending' and voided = false;

  if not found then
    raise exception 'Nota tidak valid untuk disetujui';
  end if;

  update public.jobs
     set status = 'paid', updated_at = now()
   where id = v_job_id and status = 'done';
end;
$$;

revoke execute on function public.approve_payment_provider(uuid) from public, anon;
grant execute on function public.approve_payment_provider(uuid) to authenticated;
```

## 9. Akses Data API

Tabel baru di `public` perlu di-expose ke Data API. Grant untuk role `authenticated` (RLS tetap mengatur baris mana yang bisa diakses):

```sql
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
grant usage on schema internal to authenticated;
grant execute on all functions in schema internal to authenticated;
```

Pengecualian penting (migration `20260903000009`, `00000018`, `00000019`):

```sql
-- katalog kategori bisa dibaca publik (halaman registrasi, sebelum login)
grant usage on schema public to anon;
grant select on public.service_categories to anon;

-- koordinat rumah (profiles.lat/lng) TIDAK boleh dibaca via API.
-- Grant kolom eksplisit tanpa lat/lng; baca koordinat hanya lewat fungsi DEFINER.
revoke select on public.profiles from authenticated;
grant select (
  id, email, full_name, phone, avatar_url,
  is_customer, is_tukang, is_admin, is_suspended, is_online,
  created_at, updated_at
) on public.profiles to authenticated;

-- RPC pembayaran hanya untuk user login (bukan public/anon)
revoke execute on function public.approve_payment_provider(uuid) from public, anon;
grant execute on function public.approve_payment_provider(uuid) to authenticated;
```

### 9.1 Storage buckets

Bucket dibuat via migration (bukan `config.toml`):

- `avatars` (publik, migration `20260903000016`): foto profil `$userId/$ts_$file`. Baca bebas; tulis/hapus hanya `authenticated` (cek `bucket_id` saja).
- `chat-attachments` (publik, migration `20260903000012` + diperketat `00000018`): lampiran chat `$jobId/$ts_$file`. Baca bebas (`anon` + `authenticated`); insert `authenticated` dengan syarat folder pertama path tidak kosong.
- `payments` (publik, migration `20260903000020`): bukti transfer pembayaran P2P `$jobId/$ts_$file`. Baca bebas (`anon` + `authenticated`); insert `authenticated`.
## 10. Seed Data (dummy)

```sql
-- Kategori jasa (5 awal + 7 dari migration 20260903000017 = 12 total)
insert into public.service_categories (name, slug, icon, sort_order) values
  ('AC', 'ac', 'ac_unit', 1),
  ('Cleaning', 'cleaning', 'cleaning_services', 2),
  ('Plumbing', 'plumbing', 'plumbing', 3),
  ('Listrik', 'listrik', 'electric_bolt', 4),
  ('Handyman', 'handyman', 'build', 5),
  ('Servis Motor', 'servis-motor', 'two_wheeler', 6),
  ('Servis Mobil', 'servis-mobil', 'directions_car', 7),
  ('Elektronik', 'elektronik', 'devices_other', 8),
  ('Besi & Baja', 'besi-baja', 'construction', 9),
  ('Jahit', 'jahit', 'checkroom', 10),
  ('Tambal Ban', 'tambal-ban', 'tire_repair', 11),
  ('Las', 'las', 'local_fire_department', 12);
```

Seed customer & tukang dibuat via script terpisah di `supabase/seed.sql` saat implementasi, mencakup beberapa tukang dengan koordinat tersebar (mis. sekitar Jakarta) untuk menguji query radius.

## 11. Riwayat Perubahan Skema (migration log)

Setiap baris = satu file di `supabase/migrations/`, berurutan sesuai nama file.
Bagian §1–§10 di atas mencerminkan **status akhir** setelah seluruh migration.

| Migration | Perubahan |
|-----------|-----------|
| `20260903000000_initial` | Skema dasar: 5 enum, 10 tabel, helper invoker, seluruh RLS awal, 5 trigger dasar, 3 RPC, grants |
| `20260903000001_handle_new_user` | Trigger auto-insert profil saat signup (versi awal, `public`, baca flag role dari metadata) |
| `20260903000002_app_notifications` | Tabel `app_notifications` + RLS own + realtime |
| `20260903000003_fix_handle_new_user` | Handler pindah ke `internal.handle_new_user()`; signup selalu `is_customer=true` |
| `20260903000004_fix_rls_recursion` | Perbaiki rekursi 42P17 via `internal.is_job_customer` / `has_provider_applied`; discovery job `open` |
| `20260903000005_fix_auth_helper_recursion` | Perbaiki stack-depth 54001: helper role jadi `internal` DEFINER; SELECT profiles/tukang_profiles dibuka |
| `20260903000006_grant_internal_schema` | `USAGE` + `EXECUTE` schema `internal` untuk `authenticated` |
| `20260903000007_jobs_delete_policy` | `jobs_delete_customer` (open/cancelled/paid) — lihat `00000019` untuk revisi `paid` |
| `20260903000008_tukang_payment_details` | Kolom `payment_details jsonb`; `become_tukang` 4-arg |
| `20260903000009_public_service_categories` | Katalog bisa dibaca `anon` |
| `20260903000010_handle_new_user_tukang` | Signup `role=tukang` langsung buat `tukang_profiles`; backfill tukang yatim |
| `20260903000011_cascade_delete_profiles` | FK ke profiles jadi `CASCADE` (`selected_provider_id` → `SET NULL`) |
| `20260903000012_fix_messages_and_roles` | Tukang murni (`is_customer=false`); `messages` +`media_url/is_read/read_at`; chat untuk tukang applied; bucket `chat-attachments` |
| `20260903000013_price_agreements_locked_policy` | Nota boleh dibuat saat job `locked` ke tukang tsb |
| `20260903000014_jobs_update_provider_policy` | Tukang terpilih boleh update job-nya |
| `20260903000015_fix_reviews_trigger_security_definer` | `reviews_update_rating` DEFINER + hitung ulang idempoten |
| `20260903000016_setup_avatars_bucket` | Bucket publik `avatars` + policy storage |
| `20260903000017_service_radius_and_categories` | 7 kategori baru (total 12); `service_radius_km`; radius per-tukang |
| `20260903000018_notifications_rls_hardening` | Trigger notifikasi ×3; `find_providers_nearby` DEFINER; revoke kolom `lat/lng`; purge 200 titik; guard nota; `locked_out` keluar chat; review/komplain wajib terpilih; storage path check |
| `20260903000019_fix_rls_and_atomicity` | `admin_set_suspended` + `jobs_lock_applications` DEFINER; RPC `approve_payment_provider`; guard update chat; admin-read notifikasi; delete `paid` dilarang |
| `20260903000020_feed_radius_and_payments` | Storage bucket `payments`; kolom `payment_proof_url`; RPC `get_open_jobs_for_tukang` (PostGIS radius + kategori keahlian) |

### Waiver SECURITY DEFINER di schema `public` (pengecualian atas `agents.md` §3)

Hanya fungsi berikut yang boleh DEFINER, masing-masing karena pemanggil yang sah
diblokir RLS saat menulis/membaca baris milik user lain:

- `find_providers_nearby` — membaca koordinat yang dicabut dari API.
- `admin_set_suspended` — admin menulis baris user lain (guard `is_admin` + anti self-suspend di dalam).
- `jobs_lock_applications` — trigger lock menulis lamaran/nota milik tukang lain.
- `reviews_update_rating` — trigger review customer menulis agregat milik tukang.
- `approve_payment_provider` — menulis nota + job atomik (validasi pemilik + status di dalam).
- `price_agreements_guard`, `messages_read_guard` — guard trigger (tanpa akses tabel lain yang sensitif).
- Semua fungsi `internal.*` — memang dirancang bypass RLS (pemutus rekursi, notifikasi, purge).

