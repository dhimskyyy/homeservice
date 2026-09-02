# Beres

Platform layanan jasa rumah (AC, cleaning, plumbing, listrik, handyman) yang mempertemukan customer dan tukang, dengan negosiasi harga via chat, nota (Price Agreement), tracking GPS realtime, dan pembayaran P2P.

## Stack

- **App mobile**: Flutter (Android & iOS, satu app dua role: customer & tukang)
- **Web admin**: Next.js (App Router), deploy ke Vercel
- **Backend**: Supabase (Postgres + Auth + Realtime + Edge Functions)
- **Peta**: OpenStreetMap (flutter_map di app, Leaflet di admin)

## Struktur

```
homeservice/
├── app/          # Flutter app
├── admin/        # Next.js web admin
├── supabase/     # migrations, seed, edge functions
└── docs/         # blueprint & dokumentasi
```

## Dokumentasi

Semua dokumen blueprint ada di `docs/`:

- `prd.md` — visi, masalah, fitur, scope, user stories
- `system_architecture.md` — struktur monorepo & alur data
- `database_schema.md` — skema Supabase + relasi + dummy data
- `business_rules.md` — aturan yang tidak boleh dilanggar
- `api_design.md` — endpoint/query/RPC/Edge Functions
- `security.md` — auth, RLS, proteksi data
- `app_design.md` — desain Flutter
- `web_design.md` — desain web admin
- `tech_stack.md` — keputusan stack & alasan
- `tdd.md` — rencana testing
- `roadmap.md` — fase pengerjaan
- `agents.md` — panduan untuk coding agent

## Mulai cepat

```bash
# Supabase (perlu CLI terpasang)
supabase start
supabase db reset

# Flutter app
cd app && flutter run

# Web admin
cd admin && npm install && npm run dev
```

## Status

Dalam tahap blueprint/perencanaan. Implementasi dimulai dari Supabase → Flutter → Web Admin (lihat `docs/roadmap.md`).