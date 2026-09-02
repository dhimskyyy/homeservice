# Agents — Beres

Panduan kerja untuk coding agent (Claude/Codex/o1) yang mengerjakan project ini. Ini adalah **kontrak kerja**: baca dulu, patuhi selama implementasi.

## 1. Urutan Baca Wajib

Sebelum mengerjakan apa pun, baca berurutan:

1. `prd.md` — apa yang dibangun, user story, acceptance criteria.
2. `business_rules.md` — aturan tak boleh dilanggar (prioritas P0/P1/P2).
3. `system_architecture.md` — struktur & alur data.
4. `database_schema.md` — DDL, RLS, trigger, RPC (sumber kebenaran SQL).
5. `api_design.md` — endpoint, RPC, Realtime, Edge Functions.
6. `security.md` — RLS & checklist keamanan.
7. `app_design.md` — Flutter (design tokens + layar).
8. `web_design.md` — Next.js admin.
9. `tech_stack.md` — stack & library terpilih.
10. `tdd.md` — seam & matriks test.
11. `roadmap.md` — urutan fase pengerjaan.

## 2. Konvensi Wajib

- **Bahasa UI**: Bahasa Indonesia penuh (label, pesan error, teks tombol).
- **Tanpa komentar kode** kecuali diminta.
- **Flutter**: Riverpod, go_router, struktur feature-first (lihat `app_design.md` §2). Font Poppins (heading) + Open Sans (body). Ikon SVG (bukan emoji).
- **Next.js**: App Router + TypeScript + `@supabase/ssr`.
- **Supabase**: migrations imperative di `supabase/migrations`, seed di `supabase/seed.sql`, Edge Functions di `supabase/functions`.
- **Jangan commit** kecuali diminta eksplisit.

## 3. Aturan Database (kritis)

- Sumber kebenaran SQL ada di `database_schema.md`. Jangan menyimpang dari nama kolom/tabel/policy.
- **RLS**: `to authenticated` + predikat kepemilikan; UPDATE selalu `using` + `with check`.
- **Jangan pakai `SECURITY DEFINER`** di schema `public`.
- **Jangan otorisasi dari `user_metadata`** (user-editable).
- Aksi sensitif (lock, set amount, paid) hanya lewat policy/trigger/RPC, bukan update client langsung.
- Verifikasi pakai `supabase db advisors` + security checklist di `security.md`.

## 4. Siklus Kerja (per fitur)

1. Baca dokumen terkait.
2. TDD: tulis test gagal di seam yang disepakati → implement minimal → lulus (lihat `tdd.md`).
3. Jalankan lint & typecheck (lihat §5).
4. Laporkan hasil + catatan deviasi (jika ada) ke user; jangan diam-diam memilih.

## 5. Perintah Verifikasi

```bash
# Supabase
supabase start
supabase db reset          # terapkan migrations + seed
supabase db test           # (cek --help; versi lama: supabase test db)
supabase db advisors       # (v2.81.3+)

# Flutter
flutter run
flutter analyze
flutter test

# Admin
cd admin && npm run dev
cd admin && npx next lint
cd admin && npx tsc --noEmit
```

## 6. Anti-Pattern yang Dilarang

- Horizontal slicing (tulis semua test dulu, baru semua implementasi). Kerjakan vertical slice.
- Test tautologis (expected value mengulang logika produksi).
- Menambah fitur spekulatif di luar PRD.
- Hardcode kunci rahasia (`service_role`, dll.) di client atau `NEXT_PUBLIC_*`.
- Mengubah skema DB tanpa memperbarui `database_schema.md`.

## 7. Jika Menemukan Konflik Dokumen

Jangan memilih sendiri. Laporkan ke user: "ditemukan ketidaksesuaian antara X dan Y terkait Z" dan tanyakan mana yang benar.