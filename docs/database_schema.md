# Database Schema — Beres

Database: PostgreSQL via Supabase. Menggunakan `auth.users` bawaan sebagai sumber identitas, `public.profiles` sebagai data profil aplikasi. Dokumentasi ini adalah **sumber kebenaran implementasi** — agent wajib mengikuti DDL di bawah.

## 1. Prinsip Desain

- **1 akun = 1 identitas**: `profiles.id` = `auth.users.id`, unik per user.
- **Role** disimpan di kolom profil (`is_customer`, `is_tukang`, `is_admin`), bukan di `user_metadata` (user-editable → tidak aman untuk otorisasi).
- **RLS aktif di semua tabel**, semua policy memakai pola `to authenticated` + predikat kepemilikan.
- **Alur status** di-enforce lewat `CHECK` constraint + trigger, bukan hanya aplikasi.
- **Realtime** di-enable untuk tabel `messages` dan `locations`.

## 2. Extensions

```sql
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "postgis";    -- geo query radius 50 km
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

## 4. Helper Functions (otorisasi, SECURITY INVOKER)

Tanpa `SECURITY DEFINER` — aman, berjalan dengan privilege pemanggil.

```sql
create or replace function public.current_profile_id()
returns uuid
language sql
stable
as $$
  select auth.uid();
$$;

create or replace function public.is_customer()
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_customer = true
  );
$$;

create or replace function public.is_tukang()
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_tukang = true
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security invoker
as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and is_admin = true
  );
$$;
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
  geography(point(lng, lat))
);

alter table public.jobs enable row level security;
```

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
  id             uuid primary key default gen_random_uuid(),
  job_id         uuid not null references public.jobs(id) on delete cascade,
  customer_id    uuid not null references public.profiles(id),
  provider_id    uuid not null references public.profiles(id),
  amount         integer not null check (amount > 0),
  payment_method public.payment_method not null,
  status         public.payment_status not null default 'pending',
  voided         boolean not null default false,
  created_at     timestamptz not null default now(),
  paid_at        timestamptz,
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
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index messages_job_created_idx on public.messages (job_id, created_at);

alter table public.messages enable row level security;

alter publication supabase_realtime add table public.messages;
```

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

Insert hanya oleh service role (Edge Function), bukan client.

## 6. Row Level Security (RLS) — lengkap

Pola dasar mengikuti security checklist Supabase: `to authenticated` + predikat kepemilikan, `UPDATE` selalu menyertakan `with check`.

### 6.1 profiles

```sql
-- baca profil sendiri + admin baca semua
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  to authenticated
  using ( id = auth.uid() or public.is_admin() );

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
  using ( profile_id = auth.uid() or public.is_admin() );

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
create policy "service_categories_select"
  on public.service_categories for select
  to authenticated
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

-- tukang yang sudah merespon job boleh buat nota saat job masih open
create policy "price_agreements_insert_responded_tukang"
  on public.price_agreements for insert
  to authenticated
  with check (
    provider_id = auth.uid()
    and exists (
      select 1 from public.job_applications a
      join public.jobs j on j.id = a.job_id
      where a.job_id = job_id
        and a.provider_id = auth.uid()
        and a.status <> 'locked_out'
        and j.status in ('open')
    )
  );

-- update: tukang bisa set paid hanya saat job done
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
```

### 6.7 messages

```sql
create policy "messages_select_involved"
  on public.messages for select
  to authenticated
  using (
    sender_id = auth.uid()
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.customer_id = auth.uid()
    )
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.selected_provider_id = auth.uid()
    )
    or public.is_admin()
  );

create policy "messages_insert_involved"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (j.customer_id = auth.uid() or j.selected_provider_id = auth.uid())
    )
  );
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

create policy "complaints_insert_customer"
  on public.complaints for insert
  to authenticated
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and j.customer_id = auth.uid()
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

create policy "reviews_insert_customer"
  on public.reviews for insert
  to authenticated
  with check (
    customer_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and j.customer_id = auth.uid()
        and j.status in ('done', 'paid')
    )
  );
```

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
create or replace function public.jobs_lock_applications()
returns trigger language plpgsql as $$
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

```sql
create or replace function public.reviews_update_rating()
returns trigger language plpgsql as $$
begin
  update public.tukang_profiles
     set rating_avg = (
       select round(avg(rating)::numeric, 1) from public.reviews
       where provider_id = new.provider_id
     ),
     job_count = job_count + 1
   where profile_id = new.provider_id;
  return new;
end;
$$;

create trigger reviews_update_rating after insert on public.reviews
  for each row execute function public.reviews_update_rating();
```

## 8. RPC & Fungsi Khusus

### 8.1 Kenaikan role tukang (lewat RPC yang divalidasi)

```sql
create or replace function public.become_tukang(
  p_bio text,
  p_service_type_ids uuid[],
  p_payment_methods public.payment_method[]
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

  insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods)
  values (auth.uid(), p_bio, p_service_type_ids, p_payment_methods)
  on conflict (profile_id) do update
     set bio = excluded.bio,
         service_type_ids = excluded.service_type_ids,
         payment_methods = excluded.payment_methods;
end;
$$;
```

### 8.2 Pencarian tukang radius 50 km (PostGIS)

```sql
create or replace function public.find_providers_nearby(
  p_job_id uuid,
  p_radius_meters integer default 50000
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
    and st_dwithin(
      geography(point(p.lng, p.lat)),
      geography(point(j.lng, j.lat)),
      p_radius_meters
    );
$$;
```

### 8.3 Admin: suspend / aktifkan

```sql
create or replace function public.admin_set_suspended(p_user_id uuid, p_suspended boolean)
returns void
language plpgsql
security invoker
as $$
begin
  if not public.is_admin() then
    raise exception 'Forbidden';
  end if;
  update public.profiles
     set is_suspended = p_suspended,
         updated_at = now()
   where id = p_user_id;
end;
$$;
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
```

> Insert hanya oleh Edge Function (service role), bukan client langsung.

## 9. Akses Data API

Tabel baru di `public` perlu di-expose ke Data API. Grant untuk role `authenticated` (RLS tetap mengatur baris mana yang bisa diakses):

```sql
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
```

## 10. Seed Data (dummy)

```sql
-- Kategori jasa
insert into public.service_categories (name, slug, icon, sort_order) values
  ('AC', 'ac', 'ac_unit', 1),
  ('Cleaning', 'cleaning', 'cleaning_services', 2),
  ('Plumbing', 'plumbing', 'plumbing', 3),
  ('Listrik', 'listrik', 'electric_bolt', 4),
  ('Handyman', 'handyman', 'build', 5);
```

Seed customer & tukang dibuat via script terpisah di `supabase/seed.sql` saat implementasi, mencakup beberapa tukang dengan koordinat tersebar (mis. sekitar Jakarta) untuk menguji query radius 50 km.