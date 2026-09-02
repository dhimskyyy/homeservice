# API Design — Beres

Supabase menyediakan akses data lewat **PostgREST (Data API)**, **RPC (Postgres functions)**, dan **Realtime**. Tidak ada REST backend custom; seluruh logika bisnis di database (RLS + trigger + fungsi).

## 1. Prinsip

- Client (Flutter & admin) memakai Supabase client, bukan fetch manual.
- Semua akses lewat RLS (lihat `security.md`) — endpoint yang sama, hasil berbeda per role.
- Operasi sensitif lewat RPC yang divalidasi, bukan update tabel langsung.
- Naming: tabel `snake_case` (PostgREST otomatis).

## 2. Autentikasi (Supabase Auth)

| Operasi | Metode client |
|---------|---------------|
| Registrasi | `supabase.auth.signUp({ email, password })` |
| Login | `supabase.auth.signInWithPassword({ email, password })` |
| Logout | `supabase.auth.signOut()` |
| Session | `supabase.auth.getSession()` / `onAuthStateChange` |
| User aktif | `supabase.auth.getUser()` |

Alur registrasi:
1. `signUp` → buat `auth.users`.
2. Insert ke `public.profiles` (via policy `profiles_insert_own`).
3. Role tukang ditambah via RPC `become_tukang` (bukan update langsung).

## 3. Data API (PostgREST)

### 3.1 Pola endpoint

```
GET    /rest/v1/<table>?select=...&filters
POST   /rest/v1/<table>
PATCH  /rest/v1/<table>?id=eq.<uuid>
DELETE /rest/v1/<table>?id=eq.<uuid>
```

### 3.2 Endpoint per tabel

**profiles**
```
POST   /profiles                       -- insert profil sendiri (registrasi)
GET    /profiles?id=eq.<uuid>          -- profil sendiri / admin
PATCH  /profiles?id=eq.<uuid>          -- update data diri sendiri
```

**service_categories**
```
GET    /service_categories?order=sort_order.asc
```

**jobs**
```
POST   /jobs                            -- customer buat job
GET    /jobs?customer_id=eq.<uuid>      -- daftar job saya
GET    /jobs?status=eq.open             -- tukang lihat job terbuka (direspon)
PATCH  /jobs?id=eq.<uuid>               -- update status / selected_provider_id (via trigger guard)
```

**job_applications**
```
POST   /job_applications                -- tukang respond job
GET    /job_applications?job_id=eq.<uuid>
```

**price_agreements**
```
POST   /price_agreements                -- tukang yang merespon buat nota (saat job open)
GET    /price_agreements?job_id=eq.<uuid>
PATCH  /price_agreements?id=eq.<uuid>   -- approve pembayaran (saat done)
```

**messages**
```
POST   /messages                        -- kirim chat
GET    /messages?job_id=eq.<uuid>&order=created_at.asc
```

**locations**
```
POST   /locations                       -- tukang kirim posisi (in_progress)
GET    /locations?job_id=eq.<uuid>&order=created_at.desc
```

**complaints**
```
POST   /complaints                      -- customer buat komplain
GET    /complaints?job_id=eq.<uuid>
PATCH  /complaints?id=eq.<uuid>         -- admin resolve
```

**reviews**
```
POST   /reviews                         -- customer rating
GET    /reviews?provider_id=eq.<uuid>
```

## 4. RPC (Postgres Functions)

### 4.1 become_tukang

```sql
select public.become_tukang(
  p_bio := '...',
  p_service_type_ids := array[...]::uuid[],
  p_payment_methods := array['cash','ewallet']::public.payment_method[]
);
```

- Menambah role tukang + membuat/memperbarui `tukang_profiles`.
- Hanya user yang sudah punya `profiles`.

### 4.2 find_providers_nearby

```sql
select * from public.find_providers_nearby(p_job_id := '<uuid>', p_radius_meters := 50000);
```

- Mengembalikan daftar `uuid` tukang aktif dalam radius (PostGIS `ST_DWithin`).
- Dipakai untuk menentukan penerima notifikasi job baru.

### 4.3 admin_set_suspended

```sql
select public.admin_set_suspended('<uuid>', true);
```

- Hanya `is_admin`; menandai user suspend (tidak bisa buat/terima job).

## 5. Realtime

Channel subscribe via Supabase client:

| Tabel | Event | Filter |
|-------|-------|--------|
| `messages` | INSERT | `job_id=eq.<id>` |
| `locations` | INSERT | `job_id=eq.<id>` |
| `jobs` | UPDATE | `customer_id=eq.<id>` (customer) / `selected_provider_id=eq.<id>` (tukang) |
| `job_applications` | INSERT/UPDATE | `job_id=eq.<id>` |

Notifikasi in-app (MVP):
- Job baru → tukang subscribe ke `jobs` yang di-insert? Tidak: karena RLS. Gunakan pola: Edge Function `notify-providers` memanggil `find_providers_nearby`, lalu broadcast ke topik/tabel notifikasi. Lihat §6.

## 6. Edge Functions

### 6.1 notify-providers

Dipicu saat job baru dibuat (database webhook atau dipanggil dari client setelah insert job).

```ts
// supabase/functions/notify-providers/index.ts
// 1. panggil rpc find_providers_nearby(job_id)
// 2. broadcast ke channel realtime per provider atau insert ke tabel notifications
```

### 6.2 Alur notifikasi (MVP)

1. Customer insert `jobs`.
2. Client memanggil Edge Function `notify-providers` (dengan `job_id`).
3. Function memakai `service_role` untuk query tukang dalam radius.
4. Kirim ke `app_notifications` (tabel baru, realtime) — setiap tukang subscribe ke `app_notifications` miliknya.

> Alternatif tanpa tabel baru: broadcast langsung lewat Realtime `broadcast` channel ke semua tukang, masing-masing filter jarak client-side (kurang efisien, tidak disarankan untuk produksi).

### 6.3 Tabel `app_notifications` (untuk notifikasi in-app)

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

alter table public.app_notifications enable row level security;

create policy "app_notifications_select_own"
  on public.app_notifications for select
  to authenticated
  using ( user_id = auth.uid() );

alter publication supabase_realtime add table public.app_notifications;
```

Insert hanya oleh service role (Edge Function), bukan client.

## 7. Storage

| Bucket | Path | Kebijakan |
|--------|------|-----------|
| `avatars` | `/<user_id>/avatar.jpg` | pemilik upload/update/delete; baca publik |
| `payments` | `/<job_id>/<user_id>/bukti.jpg` | customer upload; tukang terkait + admin baca |

Operasi via `supabase.storage.from('avatars').upload(...)`.

## 8. Auth Admin (web)

- Next.js pakai `@supabase/ssr` (cookie session) + middleware guard.
- Setelah `getUser()`, baca `profiles.is_admin`; non-admin redirect `/login`.

## 9. Konvensi Query

- Selalu `select` eksplisit (hindari `select: '*'` kecuali perlu).
- Filter sisi server (`eq`, `in`, `gte`) — bukan filter client.
- Pagination pakai `range` + `order`.
- Error dari PostgREST: periksa `error.code` (mis. `PGRST116` RLS) dan tampilkan pesan ramah.