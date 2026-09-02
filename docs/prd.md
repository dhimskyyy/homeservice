# PRD — Beres

## 1. Ringkasan

**Beres** adalah platform layanan jasa rumah (AC, cleaning, plumbing, listrik, handyman, dll.) yang mempertemukan customer dengan tukang secara langsung. Customer memposting kebutuhan, tukang dalam radius 50 km menerima notifikasi, keduanya bernegosiasi harga lewat chat, kesepakatan dicatat dalam nota (Price Agreement), lalu pembayaran dilakukan langsung P2P tanpa gateway.

## 2. Visi

Menjadi penghubung jasa rumah yang transparan: harga jelas terdokumentasi, tukang terpercaya, dan proses termonitor — dari permintaan, negosiasi, pelaksanaan (tracking GPS), hingga pembayaran.

## 3. Masalah

1. Customer kesulitan menemukan tukang terpercaya di sekitar (radius 50 km).
2. Harga jasa tidak jelas dan tidak terdokumentasi → rawan sengketa.
3. Tidak ada jejak kesepakatan (nota) antara customer dan tukang.
4. Admin tidak punya alat memantau pengguna, booking, nota, komplain, pembayaran, dan aktivitas platform.

## 4. Tujuan & Non-Tujuan

### Tujuan (MVP)
- Alur lengkap: post permintaan → respond → chat → deal → nota → lock → kerja → tracking → selesai → bayar → approve.
- Satu app Flutter (Android & iOS) dengan 2 role (customer & tukang).
- Web admin untuk monitoring & moderasi.
- Pembayaran P2P manual (cash/e-wallet/transfer bank).
- UI Bahasa Indonesia penuh.

### Non-Tujuan (pasca-MVP)
- Payment gateway (Midtrans/Xendit) — menunggu konfirmasi pendaftaran.
- Push notification (FCM) — MVP in-app Realtime.
- Escrow / penahanan dana.
- KYC/verifikasi dokumen tukang.

## 5. Persona & Peran

| Peran | Kebutuhan utama |
|-------|-----------------|
| Customer | memposting kebutuhan, negosiasi, lock tukang, melacak, membayar |
| Tukang | menerima notifikasi, merespon, bernegosiasi, membuat nota, kerja, konfirmasi bayar |
| Admin | memantau, moderasi (suspend/resolve), memastikan platform sehat |

**Model akun**: 1 akun = 1 email = 1 identitas, maksimal 2 role (`customer` + `tukang`). Aturan detail di `business_rules.md`.

## 6. Fitur (dengan prioritas)

### P0 (wajib MVP)
- Registrasi & login (customer & tukang), switch role.
- Posting permintaan jasa (kategori, deskripsi, lokasi).
- Notifikasi in-app ke tukang radius 50 km (Realtime).
- Respond + chat realtime.
- Price Agreement (nota) — tukang isi harga.
- Lock tukang (pilih tukang).
- Tracking GPS realtime (flutter_map + OSM).
- Konfirmasi pembayaran P2P (approve).
- Rating & komplain.

### P1 (penting)
- Web admin: dashboard, kelola user, pantau job/nota/komplain, tracking peta.

### P2 (nice-to-have)
- Reset password, avatar upload, bukti transfer upload.

## 7. User Stories + Acceptance Criteria

### Customer
| # | User story | Acceptance criteria |
|---|-----------|---------------------|
| US-C1 | Sebagai customer, saya bisa daftar & login | Input email+password valid → profil dibuat, `is_customer=true` |
| US-C2 | Sebagai customer, saya bisa posting permintaan | Pilih kategori + deskripsi + lokasi → `jobs` status `open` |
| US-C3 | Sebagai customer, saya menerima notifikasi ada tukang respond | Respond → muncul di daftar/detail job via Realtime |
| US-C4 | Sebagai customer, saya bisa chat dengan tukang | Pesan tampil realtime dua arah |
| US-C5 | Sebagai customer, saya bisa lock tukang setelah deal | Pilih tukang → job `locked`, tukang lain `locked_out` |
| US-C6 | Sebagai customer, saya lihat nota kesepakatan | Nota tampil: harga, metode bayar, status |
| US-C7 | Sebagai customer, saya bisa melacak tukang | Marker bergerak di peta saat `in_progress` |
| US-C8 | Sebagai customer, saya bisa bayar & beri rating/komplain | Setelah `done`/`paid`, rating 1-5 + komentar / komplain |

### Tukang
| # | User story | Acceptance criteria |
|---|-----------|---------------------|
| US-T1 | Sebagai tukang, saya daftar dengan jasa & metode bayar | Form jasa + payment_methods tersimpan via `become_tukang` |
| US-T2 | Sebagai tukang, saya menerima notifikasi permintaan | `app_notifications` muncul untuk job radius 50 km |
| US-T3 | Sebagai tukang, saya bisa respond & chat | Insert `job_applications` saat job `open` |
| US-T4 | Sebagai tukang, saya buat nota harga | Insert `price_agreements` saat job `open` (setelah merespon) |
| US-T5 | Sebagai tukang, saya mulai kerja & tracking | `in_progress` + kirim `locations` |
| US-T6 | Sebagai tukang, saya tandai selesai & konfirmasi bayar | `done` lalu `price_agreements.status = paid` |

### Admin
| # | User story | Acceptance criteria |
|---|-----------|---------------------|
| US-A1 | Sebagai admin, saya lihat dashboard | Statistik: total customer/tukang, job aktif, nota paid |
| US-A2 | Sebagai admin, saya suspend/aktifkan user | `admin_set_suspended` → user tak bisa buat/terima job |
| US-A3 | Sebagai admin, saya pantau job/nota/komplain | Tabel + filter status |
| US-A4 | Sebagai admin, saya lihat tracking tukang | Peta Leaflet menampilkan tukang `in_progress` |

## 8. Alur Bisnis Utama (happy path)

```
Customer post job (open)
  → Edge Function notify-providers → notifikasi tukang radius 50km
  → Tukang respond (job_applications) + chat
  → Deal harga di chat
  → Customer lock tukang (selected_provider_id, status locked)
  → Tukang buat nota (price_agreements, pending)
  → Tukang mulai kerja (in_progress) + kirim GPS (locations)
  → Customer track live
  → Tukang selesai (done)
  → Customer bayar P2P (cash/e-wallet/transfer)
  → Tukang approve (price_agreements paid, job paid)
  → Customer rating/komplain
```

## 9. Kebutuhan Non-Fungsional

- **Keamanan**: RLS per role di semua tabel; `service_role` tidak bocor ke client (lihat `security.md`).
- **Realtime**: chat & tracking via Supabase Realtime.
- **Aksesibilitas**: kontras 4.5:1, target sentuh 44px, fokus terlihat.
- **Performa**: fetch paginasi, index di kolom query utama, Realtime untuk push (bukan polling).
- **Akurasi lokasi**: PostGIS `ST_DWithin` untuk radius 50 km.

## 10. Kriteria Sukses (MVP)

- Customer dapat menyelesaikan siklus lengkap (post → bayar) tanpa perantara.
- Tukang menerima notifikasi & bisa melacak pekerjaannya.
- Admin dapat memantau dan memoderasi platform.
- App berjalan di Android & iOS; web admin live di Vercel.
- Aturan bisnis P0 tertutup test (lihat `tdd.md`).