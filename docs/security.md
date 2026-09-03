# Security — Beres

Dokumen keamanan menyeluruh untuk project Beres. Mengikuti security checklist Supabase. **Wajib dibaca agent sebelum menyentuh auth, RLS, storage, atau fungsi database.**

## 1. Model Otorisasi

### 1.1 Sumber kebenaran role

- Role (`is_customer`, `is_tukang`, `is_admin`) disimpan di **kolom tabel `public.profiles`**, BUKAN di `user_metadata`.
- **Alasan**: `raw_user_meta_data` adalah user-editable dan bisa muncul di `auth.jwt()` — tidak aman untuk keputusan otorisasi. Jangan pernah pakai `auth.jwt() ->> 'user_metadata'` untuk otorisasi.
- Helper `public.is_customer()`, `public.is_tukang()`, `public.is_admin()` membaca `profiles` dengan `security invoker` (bukan definer).

### 1.2 Prinsip defense-in-depth

- RLS adalah lapisan pertama; trigger + RPC validasi lapisan kedua; UI hanya untuk UX.
- Aturan bisnis yang mutlak (alur status, kepemilikan) di-enforce di database, bukan hanya client.

## 2. Autentikasi

- Supabase Auth (email + password), JWT short-lived.
- Session mobile: `supabase_flutter`; admin web: `@supabase/ssr` (cookie).
- **Deleting user tidak otomatis invalidate token**. Untuk aksi suspend, selain set `is_suspended`, pertimbangkan `auth.admin.deleteUser`/revoke session bila perlu.
- Password ditangani Supabase (tidak pernah disimpan sendiri).

## 3. RLS — Aturan & Pola Wajib

Lihat `database_schema.md` §6 untuk SQL lengkap. Pola yang harus diikuti:

### 3.1 Selalu gunakan `to authenticated` + predikat

```sql
-- BENAR
create policy "x" on t for select
  to authenticated
  using ( user_id = (select auth.uid()) );
```

Jangan pakai `auth.role() = 'authenticated'` (deprecated, dan rusak saat anonymous sign-in aktif).

### 3.2 UPDATE wajib `USING` + `WITH CHECK`

```sql
create policy "x" on t for update
  to authenticated
  using ( user_id = auth.uid() )
  with check ( user_id = auth.uid() );
```

Tanpa `WITH CHECK`, user bisa reassign `user_id` ke user lain (IDOR).

### 3.3 UPDATE butuh SELECT policy

Postgres RLS: UPDATE harus SELECT dulu. Tanpa SELECT policy, update silent return 0 rows (tanpa error).

### 3.4 Enumerasi akses per tabel

| Tabel | Siapa yang boleh | Catatan |
|-------|------------------|---------|
| profiles | baca sendiri + admin | user tidak boleh ubah role sendiri |
| tukang_profiles | baca sendiri + admin; tulis sendiri | insert di-guard `is_tukang` |
| service_categories | baca semua login; tulis admin | katalog publik |
| jobs | customer baca miliknya; tukang baca yang direspond; admin semua | insert hanya customer; update via trigger |
| job_applications | tukang tulis miliknya; customer baca job-nya | respond hanya saat `open` |
| price_agreements | customer & tukang terkait | insert hanya tukang yang merespon saat job `open`; `voided` saat tukang lain dipilih; paid hanya saat `done` |
| messages | customer & tukang terlibat di job | |
| locations | customer pemilik job & admin baca; tukang terpilih insert saat `in_progress` | |
| complaints | customer insert; admin resolve | hanya setelah done/paid |
| reviews | customer insert; semua baca | unik per (job, customer) |
| app_notifications | baca & update sendiri; insert hanya service role (Edge Function) | realtime enabled |

## 4. Aksi Sensitif (di-enforce di DB)

| Aksi | Guard |
|------|-------|
| Lock tukang (`status = locked`) | hanya customer pemilik; trigger menandai aplikasi lain `locked_out` |
| Mulai kerja (`in_progress`) | hanya untuk `selected_provider_id`; trigger `jobs_provider_guard` |
| Selesai (`done`) | hanya `selected_provider_id` |
| Set `paid` | hanya tukang; hanya saat job `done`; `price_agreements_update_payment` |
| Kenaikan role tukang | via RPC `become_tukang` (bukan update langsung `profiles`) |
| Suspend user | via RPC `admin_set_suspended`, hanya `is_admin` |

## 5. Fungsi Database

- **Selalu `SECURITY INVOKER`**, bukan `SECURITY DEFINER`.
- `SECURITY DEFINER` di `public` adalah endpoint publik (grant EXECUTE ke PUBLIC default) — berbahaya. Jika terpaksa, taruh di schema non-exposed + cek `auth.uid()` di dalam.
- Helper otorisasi (`is_admin`, dll.) ditandai `security invoker` dan `stable`.

## 6. Storage

- Bucket: `avatars` (profil), `payments` (bukti transfer opsional).
- Policy Storage harus menyertakan ketiganya bila butuh upsert: **INSERT + SELECT + UPDATE** (kalau cuma INSERT, replacement file gagal diam-diam).
- `avatars`: hanya pemilik yang upload/update/delete; baca publik (atau logged-in).
- `payments`: hanya customer upload, hanya tukang terkait + admin yang baca.

## 7. Kunci API & Environment

- **Frontend hanya pakai `anon`/publishable key** (aman dengan RLS).
- **`service_role` key RAHASIA**: hanya di Edge Functions / server side; tidak pernah di `NEXT_PUBLIC_*` (Next.js mengirim `NEXT_PUBLIC_` ke browser) dan tidak pernah di app Flutter.
- Semua kunci via environment variables; `.env` di-gitignore.

## 8. Data API Exposure

- Tabel baru di `public` belum tentu otomatis ter-expose ke Data API (tergantung project settings).
- Grant `usage on schema public` + privileges tabel ke `authenticated` (RLS tetap mengatur baris).
- `service_role` punya akses bypass RLS — jaga ketat.

## 9. Keamanan Data Khusus

- Lokasi customer hanya tampil ke tukang yang terlibat di job aktif (`jobs_select_involved` + `locations_select_involved`).
- Data tracking (`locations`) hanya aktif saat `in_progress`; berhenti saat `done`.
- Nomor telepon tukang hanya terlihat setelah job `locked` (kalau perlu, tambah policy/kolom khusus — default: hanya profile sendiri + admin).

## 10. Checklist Pra-Rilis

- [ ] RLS enabled di semua tabel `public`.
- [ ] Semua policy `to authenticated` + predikat, update ada `WITH CHECK`.
- [ ] Tidak ada `SECURITY DEFINER` di schema `public`.
- [ ] Tidak ada otorisasi dari `user_metadata`.
- [ ] `service_role` tidak bocor ke client.
- [ ] Storage policy lengkap (INSERT+SELECT+UPDATE untuk upsert).
- [ ] Trigger status job aktif.
- [ ] `supabase db advisors` dijalankan & bersih.