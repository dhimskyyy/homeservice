# Roadmap — Beres

Fase pengerjaan, urutan, dan kriteria selesai tiap fase. Urutan disengaja: **database dulu** karena menjadi fondasi app & admin.

## Fase 0 — Fondasi & Setup

**Tujuan**: monorepo ter-scaffold dan Supabase local berjalan.

- [ ] Init monorepo: `app/` (Flutter), `admin/` (Next.js), `supabase/`.
- [ ] Install Supabase CLI, `supabase init`.
- [ ] Aktifkan extension PostGIS.
- [ ] Setup env `.env` (local) + `.gitignore`.
- [ ] Tulis `README.md` setup.

**Selesai saat**: `supabase start` berjalan, `flutter create app` & `create-next-app admin` ter-scaffold.

## Fase 1 — Database & Auth (paling kritis)

**Tujuan**: skema + RLS + trigger + RPC + seed, tertutup test.

- [ ] Migration DDL lengkap (lihat `database_schema.md`): profiles, tukang_profiles, service_categories, jobs, job_applications, price_agreements, messages, locations, complaints, reviews, app_notifications.
- [ ] Enums + extensions (pgcrypto, postgis).
- [ ] RLS policy semua tabel (lihat `security.md`).
- [ ] Trigger: status guard, provider guard, lock applications, update rating.
- [ ] RPC: `become_tukang`, `find_providers_nearby`, `admin_set_suspended`.
- [ ] Grant Data API ke `authenticated`.
- [ ] `seed.sql`: kategori + contoh customer/tukang (koordinat tersebar).
- [ ] pgTAP test untuk aturan P0 (lihat `tdd.md` matriks).

**Selesai saat**: semua test DB green + `supabase db advisors` bersih.

## Fase 2 — Flutter: Auth & Dasar

- [ ] Core: tema (design tokens dari `app_design.md`), supabase client, repository.
- [ ] Register (customer + pilih jadi tukang), login, logout.
- [ ] Form tukang + RPC `become_tukang`.
- [ ] Switch role (muncul hanya jika 2 role).
- [ ] Unit/widget test auth.

## Fase 3 — Flutter: Job & Chat

- [ ] Customer: home kategori, buat permintaan (peta pilih lokasi), daftar job, detail job.
- [ ] Tukang: beranda notifikasi permintaan (Realtime), respond job.
- [ ] Chat realtime (messages).
- [ ] Nota (price agreement): tukang isi harga, buat nota.
- [ ] Test repository + widget.

## Fase 4 — Flutter: Alur Kerja & Tracking

- [ ] Lock tukang (`select provider`, status).
- [ ] Status transisi: in_progress, done.
- [ ] Tracking GPS live (geolocator → locations → flutter_map marker).
- [ ] Pembayaran P2P: konfirmasi & approve.
- [ ] Integration test happy path.

## Fase 5 — Flutter: Rating, Komplain, Polish

- [ ] Rating (1–5) + komentar.
- [ ] Komplain.
- [ ] Empty/error/loading state, aksesibilitas (44px target, kontras), error handling ramah.
- [ ] `flutter analyze` bersih + semua test green.

## Fase 6 — Web Admin (Next.js)

- [ ] Auth admin + middleware guard.
- [ ] Dashboard ringkasan (stat card).
- [ ] Kelola customer & tukang (suspend/aktifkan via RPC).
- [ ] Pantau job, nota, komplain (DataTable + filter).
- [ ] Tracking peta Leaflet + Realtime.
- [ ] Test guard + component.

## Fase 7 — Deploy & Rilis

- [ ] Deploy admin ke Vercel (env config).
- [ ] Build APK/AAB (Android) + IPA (iOS) lokal.
- [ ] (Target lanjutan) Play Store / App Store.
- [ ] (Pasca-MVP) push notification FCM.
- [ ] (Pasca-MVP) payment gateway — menunggu konfirmasi pendaftaran.

## Urutan yang Disarankan

```
F0 → F1 (DB) → F2 (auth) → F3 (job/chat) → F4 (tracking/pay)
   → F5 (rating/polish) → F6 (admin) → F7 (deploy)
```

App dan admin bergantung pada F1; karena itu F1 paling awal dan paling ketat di-test.

## Milestone & Deliverable

| Milestone | Deliverable |
|-----------|-------------|
| M1 (F1 selesai) | Database ber-RLS + test green |
| M2 (F3 selesai) | MVP inti: post→chat→nota |
| M3 (F4 selesai) | Alur penuh + tracking + bayar |
| M4 (F6 selesai) | Web admin siap pantau |
| M5 (F7 selesai) | Admin live di Vercel, app build Android/iOS |