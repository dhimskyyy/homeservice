# Web Admin Design — Beres

Web admin dibangun dengan Next.js (App Router) + TypeScript, deploy ke Vercel, autentikasi role `admin` via `@supabase/ssr`, peta Leaflet + OpenStreetMap.

## 1. Design System (konsisten dengan app)

| Role | Hex | Pemakaian |
|------|-----|-----------|
| Primary | `#1E40AF` | sidebar aktif, header |
| Secondary | `#3B82F6` | link, tombol sekunder |
| Accent/CTA | `#EA580C` | aksi penting (suspend, resolve) |
| Background | `#F8FAFC` | latar konten |
| Card | `#FFFFFF` | kartu, tabel |
| Border | `#BFDBFE` | garis tabel |
| Muted | `#64748B` | teks sekunder |
| Destructive | `#DC2626` | suspend, blokir |
| Success | `#16A34A` | status paid, resolved |

Tipografi: Poppins (heading) + Open Sans (body). Status badge mengikuti warna yang sama dengan app.

## 2. Struktur Project

```
admin/
├── app/
│   ├── login/page.tsx
│   ├── (dashboard)/
│   │   ├── layout.tsx          # sidebar + guard admin
│   │   ├── page.tsx            # dashboard
│   │   ├── users/page.tsx      # kelola customer & tukang
│   │   ├── jobs/page.tsx       # pantau job
│   │   ├── jobs/[id]/page.tsx  # detail job
│   │   ├── agreements/page.tsx # nota / price agreement
│   │   ├── complaints/page.tsx # komplain
│   │   └── tracking/page.tsx   # peta live tukang
│   └── ...
├── components/
│   ├── ui/                     # Button, Badge, Table, Card, Input
│   ├── layout/Sidebar.tsx
│   └── map/TrackingMap.tsx     # Leaflet
├── lib/
│   ├── supabase/server.ts      # server client
│   ├── supabase/middleware.ts
│   └── auth.ts
├── middleware.ts               # guard admin
└── .env.local                  # env (tidak di-commit)
```

## 3. Autentikasi & Guard

- `middleware.ts`: cek session (cookie via `@supabase/ssr`). Belum login → redirect `/login`.
- Setelah `getUser()`, query `profiles.is_admin`. Non-admin → redirect `/login` + revoke.
- Server components pakai supabase server client untuk fetch data; client components (peta) pakai browser client.

## 4. Halaman — lengkap

### 4.1 Dashboard
- Kartu ringkasan: total customer, total tukang, job aktif (`in_progress`), nota `paid`, komplain `open`.
- Tabel job terbaru (5) + komplain terbaru (5).
- Grafik opsional (recharts): job per hari (7 hari terakhir).

### 4.2 Pengguna (`/users`)
- Tab: Customer | Tukang.
- Kolom: nama, email, telepon, status (aktif/suspend), tanggal daftar.
- Pencarian nama/email, filter status.
- Aksi: `Suspend` / `Aktifkan` → RPC `admin_set_suspended`.

### 4.3 Pekerjaan (`/jobs`)
- Tabel semua job: id, judul, kategori, customer, status, tanggal.
- Filter status + pencarian.
- Klik → Detail job: customer, tukang terpilih, daftar tukang merespon, timeline status.

### 4.4 Nota (`/agreements`)
- Tabel nota: job, customer, tukang, jumlah (format Rupiah), metode bayar, status (pending/paid), tanggal bayar.
- Filter status.

### 4.5 Komplain (`/complaints`)
- Tabel komplain: job, customer, tukang, alasan, status.
- Aksi `Resolve` → update status ke `resolved`.

### 4.6 Tracking (`/tracking`)
- Client component dengan Leaflet.
- Menampilkan marker semua tukang dengan job `in_progress`.
- Subscribe Realtime `locations` (service role di server, atau browser client dengan policy admin).
- Klik marker → popup info job + posisi terakhir + waktu.

## 5. Komponen Reusable

- `DataTable` — sort, filter, pagination, loading, empty state.
- `StatusBadge` — warna sesuai status (open/locked/in_progress/done/paid/cancelled; pending/paid; open/resolved).
- `ConfirmDialog` — konfirmasi aksi berbahaya (suspend, resolve).
- `StatCard` — kartu ringkasan.
- `TrackingMap` — wrapper Leaflet + realtime.

## 6. Data Fetching

- Server components: fetch SSR via supabase server client (role admin, RLS allows all read).
- Admin read semua tabel; hanya `service_role` untuk insert `app_notifications` (via Edge Function), bukan dari web admin.

## 7. Aksesibilitas & Responsif

- Kontras 4.5:1; fokus terlihat; tabel ada label header; tombol ≥ 40px.
- Responsif: sidebar collapse di layar sempit; tabel scroll horizontal bila perlu.
- Loading/empty/error state di semua halaman.

## 8. Deployment (Vercel)

- Env di Vercel: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (server only, tidak `NEXT_PUBLIC`).
- `SUPABASE_SERVICE_ROLE_KEY` hanya dipakai di server code / route handlers.
- Build: `npm run build`; lint: `next lint`; typecheck: `tsc --noEmit`.