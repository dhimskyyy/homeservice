# Rencana Testing (TDD) — Beres

Pendekatan test-first di tiap fase, dengan sumber kebenaran aturan bisnis di database.

## 1. Prinsip

- Tulis test yang memvalidasi aturan bisnis (`business_rules.md`) sebelum/saat implementasi.
- Tingkatan: unit test (logika) → integration test (Supabase/DB) → widget/component test (UI).
- Database jadi lapisan pertahanan utama; test DB fokus pada RLS & alur status.

## 2. Fase & Test

### Fase 1 — Database & Auth (Supabase)
- Test migrasi & seed berjalan.
- Test RLS: customer tidak bisa baca profil orang lain secara penuh; tukang tidak bisa update job customer lain.
- Test RPC `find_providers_nearby` mengembalikan tukang dalam radius 50 km (pakai seed koordinat).
- Test trigger alur status: `open → locked → in_progress → done → paid`, dan larangan `paid` sebelum `done`.
- Test rule "1 akun 1 profil" (unique constraint).
- Test nota: tukang yang merespon bisa insert `price_agreements` saat job `open` (policy `price_agreements_insert_responded_tukang`).
- Test nota: tukang yang belum merespon / sudah `locked_out` tidak bisa buat nota.
- Test nota: saat customer lock tukang, nota tukang lain jadi `voided`, nota tukang terpilih tetap berlaku (trigger `jobs_lock_applications`).
- Test nota: nota `voided` tidak bisa di-approve (`price_agreements_update_payment`).

### Fase 2 — Flutter App
- Unit test model & state Riverpod (misal: state job, state switch role).
- Widget test layar kunci: form registrasi, switch role muncul hanya jika punya 2 role.
- Integration test alur: register → post job → respond → lock → tracking → bayar → approve.

### Fase 3 — Web Admin
- Unit test komponen DataTable & badge status.
- Integration test guard admin (non-admin ditolak).
- Test halaman dashboard & tracking menampilkan data.

## 3. Tooling

- Flutter: `flutter test` (unit & widget), integration_test untuk alur end-to-end.
- Supabase: `supabase db test` / pgTAP untuk test fungsi & policy SQL.
- Next.js: Vitest + React Testing Library (unit/component), Playwright untuk e2e admin (opsional).

## 4. Definisi Selesai (per fitur)

- Test terkait lolos.
- Aturan bisnis yang relevan tertutup oleh test.
- Lint & typecheck bersih (`flutter analyze`, `next lint`, `tsc --noEmit`).
