# Business Rules — Beres

Aturan bisnis yang **tidak boleh dilanggar**. Di-enforce di lapisan database (RLS + trigger + constraint) sebagai sumber kebenaran, diduplikasi di app untuk UX. Prioritas: **P0 wajib di DB**, P1 di DB+app, P2 minimal di app.

## 1. Akun & Role

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-1.1 | 1 akun = 1 email = 1 identitas (`profiles.id` = `auth.users.id`). Tidak boleh ada dua profil untuk email sama. | unique index `profiles_email_key` | P0 |
| BR-1.2 | Maksimal 2 role per akun: `customer` dan `tukang` (boolean terpisah). | app + trigger | P0 |
| BR-1.3 | User tidak bisa mengubah role/`is_admin`/`is_suspended` miliknya sendiri lewat update langsung. | policy (tidak ada kolom yang bisa diubah tanpa guard) + RPC | P0 |
| BR-1.4 | Kenaikan role tukang hanya lewat RPC `become_tukang` (bukan update `profiles` langsung). | RPC `security invoker` | P0 |
| BR-1.5 | `is_admin` hanya bisa di-set oleh admin lain (di luar scope app; via dashboard/SQL admin). | tidak ada policy/RPC publik | P0 |
| BR-1.6 | Tombol switch role di UI hanya muncul jika `is_customer` & `is_tukang` sama-sama `true`. | app | P1 |
| BR-1.7 | Alur jadi tukang: logout → halaman registrasi → pilih "daftar jadi tukang" → login email sama → `become_tukang`. Tanpa logout tidak ada jalur daftar tukang. | app | P1 |

## 2. Job & Penguncian

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-2.1 | Hanya akun `is_customer` yang boleh buat `jobs`. | policy `jobs_insert_customer` | P0 |
| BR-2.2 | Alur status satu arah: `open → locked → in_progress → done → paid`, atau `cancelled` dari `open`/`locked`. Transisi lain ditolak. | trigger `jobs_status_guard` | P0 |
| BR-2.3 | Hanya customer pemilik job yang boleh mengunci tukang (set `selected_provider_id` + `status=locked`). | policy + trigger | P0 |
| BR-2.4 | Setelah `locked`, tukang lain tidak bisa respond; `job_applications` mereka jadi `locked_out`. | trigger `jobs_lock_applications` | P0 |
| BR-2.5 | Hanya `selected_provider_id` yang bisa set `in_progress` dan `done`. | trigger `jobs_provider_guard` | P0 |
| BR-2.6 | Job tidak bisa `paid` sebelum `done`. | trigger `jobs_status_guard` | P0 |
| BR-2.7 | Tukang yang di-`suspend` tidak bisa buat application (respond). | policy + check `is_suspended` | P1 |

## 3. Harga & Nota (Price Agreement)

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-3.1 | Harga tidak ditampilkan seperti marketplace; hanya muncul setelah deal via chat. | app | P2 |
| BR-3.2 | Satu nota per (job, provider) — unique constraint; boleh banyak nota per job (satu per tukang yang berunding). | `price_agreements_unique` | P0 |
| BR-3.3 | Nota dibuat tukang yang sudah merespon job (`job_applications`) saat job `open`. Saat customer lock tukang, nota tukang lain otomatis `voided`, nota tukang terpilih berlaku. | policy `price_agreements_insert_responded_tukang` + trigger `jobs_lock_applications` | P0 |
| BR-3.4 | `amount > 0`. | check constraint | P0 |
| BR-3.5 | Nota tidak bisa diubah setelah `paid`. | policy (update hanya saat `pending`) | P0 |
| BR-3.6 | Metode bayar harus salah satu yang diisi tukang saat registrasi (`payment_methods[]`). | app + validasi | P1 |

## 4. Pembayaran (P2P manual)

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-4.1 | Pembayaran langsung customer → tukang, tanpa gateway/escrow. | desain | P0 |
| BR-4.2 | `price_agreements.status = paid` hanya bisa di-set tukang (approve), dan hanya saat job `done`. | policy `price_agreements_update_payment` | P0 |
| BR-4.3 | Job harus `done` dulu sebelum `paid`. | policy (refer ke `jobs.status`) | P0 |
| BR-4.4 | Tidak ada perubahan otomatis saldo/platform (tidak ada komisi MVP). | desain | P2 |

## 5. Tracking GPS

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-5.1 | Lokasi hanya dikirim tukang terpilih, dan hanya saat `in_progress`. | policy `locations_insert_active_tukang` | P0 |
| BR-5.2 | Lokasi hanya dibaca customer pemilik job & admin (dan tukang itu sendiri). | policy `locations_select_involved` | P0 |
| BR-5.3 | Tracking berhenti saat job `done`. | policy (cek status) | P0 |
| BR-5.4 | Lokasi customer hanya terlihat ke tukang yang terlibat di job aktif. | policy jobs/locations | P1 |

## 6. Komplain & Rating

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-6.1 | Komplain hanya oleh customer pemilik job, hanya setelah `done`/`paid`. | policy `complaints_insert_customer` | P0 |
| BR-6.2 | Rating hanya oleh customer pemilik job, hanya setelah `done`/`paid`. | policy `reviews_insert_customer` | P0 |
| BR-6.3 | Satu rating per customer per job. | `reviews_unique` | P0 |
| BR-6.4 | `rating_avg` tukang di-update otomatis saat review baru. | trigger `reviews_update_rating` | P1 |

## 7. Akses Admin

| # | Aturan | Lapisan | Prioritas |
|---|--------|---------|-----------|
| BR-7.1 | Admin (`is_admin`) bisa baca semua data. | policy per tabel (`or is_admin()`) | P0 |
| BR-7.2 | Hanya admin yang bisa resolve komplain & suspend user. | policy + RPC `admin_set_suspended` | P0 |
| BR-7.3 | User suspend tidak bisa buat job / respond job. | policy + RPC | P1 |

## 8. Enforce Map (ringkasan)

- **Unik/constraint**: email unik, (job, provider) unik di application & nota, (job, customer) unik di review, `amount > 0`, rating 1–5.
- **Trigger**: `jobs_status_guard` (alur status), `jobs_provider_guard` (provider valid), `jobs_lock_applications` (lock massal), `reviews_update_rating`.
- **Policy**: kepemilikan + role di semua tabel (lihat `security.md`, `database_schema.md`).
- **RPC**: `become_tukang`, `find_providers_nearby`, `admin_set_suspended`.

## 9. Edge Cases

1. Dua tukang deal bersamaan → hanya satu yang di-`lock`; aplikasi lain otomatis `locked_out`.
2. Customer cancel setelah locked → hanya dari status `locked`/`open`, trigger menolak dari status lain.
3. Tukang approve payment padahal belum `done` → policy menolak (harus `done` dulu).
4. User suspend mencoba buat job → policy `is_suspended` menolak.
5. Tukang kirim GPS saat job sudah `done` → policy `locations_insert_active_tukang` menolak.
6. User daftar tukang tapi belum punya `profiles` → `become_tukang` raise "Profile not found".