# System Architecture — Beres

Arsitektur end-to-end untuk platform Beres: Flutter app (2 role), Next.js admin, Supabase sebagai backend tunggal, OpenStreetMap untuk peta.

## 1. Monorepo

```
homeservice/
├── README.md
├── docs/                    # blueprint & dokumentasi
├── app/                     # Flutter (customer + tukang)
├── admin/                   # Next.js web admin
└── supabase/
    ├── config.toml
    ├── migrations/          # SQL migrations (imperative)
    ├── seed.sql             # dummy data
    └── functions/           # Edge Functions
```

## 2. Komponen & Tanggung Jawab

| Komponen | Teknologi | Tanggung jawab |
|----------|-----------|----------------|
| Mobile app | Flutter (Riverpod, go_router, supabase_flutter, flutter_map) | UI customer & tukang, chat, tracking, pembayaran konfirmasi |
| Web admin | Next.js (App Router, @supabase/ssr, Leaflet) | Monitoring, kelola user, job, nota, komplain, tracking |
| Backend | Supabase | Auth, Postgres (data), RLS, Realtime, Storage, Edge Functions |
| Geo | PostGIS + OpenStreetMap | Pencarian radius 50 km, peta tile gratis |

## 3. Diagram Arsitektur

```
┌──────────────┐          ┌────────────────────────────┐          ┌──────────────┐
│  Flutter App  │────────▶│          Supabase          │◀────────│  Next.js Admin│
│  customer +   │  HTTPS  │ ┌────────────────────────┐ │  HTTPS   │  (Vercel)     │
│  tukang       │◀────────│ │ Auth (JWT/session)     │ │◀────────│              │
└──────────────┘  realtime│ ├────────────────────────┤ │          └──────────────┘
                          │ │ Postgres + PostGIS     │ │
                          │ │  - RLS policies        │ │
                          │ │  - triggers/status     │ │
                          │ ├────────────────────────┤ │
                          │ │ Realtime (messages,    │ │
                          │ │  locations, notif)     │ │
                          │ ├────────────────────────┤ │
                          │ │ Storage (avatars,      │ │
                          │ │  bukti transfer)       │ │
                          │ ├────────────────────────┤ │
                          │ │ Edge Functions         │ │
                          │ │  (notify-providers)    │ │
                          │ └────────────────────────┘ │
                          └────────────────────────────┘
                                      │
                                      ▼
                          ┌────────────────────────┐
                          │  OpenStreetMap tiles    │
                          │  (flutter_map / Leaflet)│
                          └────────────────────────┘
```

## 4. Alur Data — detail per fitur

### 4.1 Registrasi & role
1. Flutter `signUp` → `auth.users` dibuat.
2. Flutter insert `profiles` (policy `profiles_insert_own`).
3. (Customer) `is_customer = true` set saat registrasi.
4. (Tukang) user logout → daftar sebagai tukang → login email sama → panggil RPC `become_tukang`.

### 4.2 Posting job & notifikasi radius
1. Customer insert `jobs` (status `open`, lat/lng).
2. Flutter panggil Edge Function `notify-providers`.
3. Function pakai `service_role` → RPC `find_providers_nearby(job_id, 50000)`.
4. Function insert ke `app_notifications` untuk tiap tukang hasil.
5. Tukang subscribe Realtime `app_notifications` (filter `user_id`) → muncul notifikasi.

### 4.3 Respond & chat
1. Tukang klik "Respond" → insert `job_applications` (policy cek status `open`).
2. Chat via `messages` (Realtime INSERT, filter `job_id`).

### 4.4 Deal & nota
1. Tukang yang sudah deal mengisi harga di chat → insert `price_agreements` (policy `price_agreements_insert_responded_tukang`: tukang sudah merespon + job `open`).
2. Saat customer lock tukang (`status=locked`), trigger `jobs_lock_applications` menandai nota tukang lain `voided`, nota tukang terpilih berlaku.

### 4.5 Lock tukang
1. Customer PATCH `jobs` → `status=locked`, `selected_provider_id`.
2. Trigger `jobs_lock_applications` menandai aplikasi lain `locked_out`.
3. Tukang lain lihat status "terkunci" via Realtime `jobs` / `job_applications`.

### 4.6 Mulai kerja & tracking
1. Tukang PATCH `jobs` → `status=in_progress` (trigger `jobs_provider_guard`).
2. Flutter mulai kirim `locations` periodik (policy: hanya saat `in_progress`).
3. Customer subscribe `locations` → marker bergerak di flutter_map.

### 4.7 Selesai & pembayaran P2P
1. Tukang PATCH `jobs` → `status=done`.
2. Customer transfer (cash/e-wallet/bank) sesuai `payment_methods` tukang.
3. Tukang PATCH `price_agreements` → `status=paid` (policy cek job `done`).
4. (Opsional) customer upload bukti transfer ke Storage `payments/`.

### 4.8 Rating & komplain
1. Setelah `done`/`paid`, customer insert `reviews` (trigger update `rating_avg`) atau `complaints`.

## 5. Diagram Urutan (contoh: happy path)

```
Customer                Supabase                Tukang
   │ insert jobs           │                      │
   │──▶ notify-providers ─▶│                      │
   │                       │── app_notifications ─▶│ (Realtime)
   │                       │◀── insert application │
   │◀── jobs (Realtime) ───│                      │
   │         (chat realtime messages)             │
   │ PATCH jobs locked ───▶│── trigger lock ──────▶│ (lihat "terkunci")
   │                       │◀── PATCH in_progress  │
   │◀── locations Realtime ────────────────────────│ (kirim GPS)
   │                       │◀── PATCH done         │
   │ transfer dana ───────────────────────────────▶│
   │                       │◀── PATCH paid         │
```

## 6. Data Flow & Source of Truth

- **Database = sumber kebenaran** (RLS + trigger + constraint).
- Client (Flutter/Next) tidak memegang logika aturan; hanya memanggil query/RPC.
- Realtime hanya untuk *push* perubahan; fetch awal selalu dari PostgREST (query), bukan cache Realtime.

## 7. Error Handling & Failover

| Skenario | Penanganan |
|----------|-----------|
| PostgREST error (RLS) | tampilkan pesan ramah; jangan retry tanpa perubahan |
| Trigger menolak transisi status | kembalikan error `raise exception` → client tampilkan |
| Realtime putus | indikator "menyambungkan…", auto-reconnect Supabase client |
| GPS gagal | fallback lokasi statis + toast |
| Edge Function timeout | retry sekali, lalu fallback notify in-app langsung (jika radius kecil) |
| Vercel cold start | server components fetch SSR; halaman tracking client-side |

## 8. Deployment Topology

- **Supabase**: managed cloud (free tier untuk dev, upgrade saat launch).
- **Next.js admin**: Vercel (env `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` server-only).
- **Flutter app**: build APK/AAB (Android) & IPA (iOS) lokal; distribusi Play Store (target lanjutan).
