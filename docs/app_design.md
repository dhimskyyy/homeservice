# App Design (Flutter) — Beres

Aplikasi Flutter single codebase untuk Android & iOS, satu app dengan dua role (customer & tukang), Bahasa Indonesia.

## 1. Arsitektur Flutter

- State management: Riverpod.
- Routing: go_router (navigasi deklaratif, dukung deep link ke chat/job).
- Database: supabase_flutter (Auth, PostgREST, Realtime, Storage).
- Peta: flutter_map + latlong2 (OpenStreetMap tile).

Struktur folder (feature-first):

```
lib/
├── main.dart
├── core/            # tema, konstanta, util, error handling
├── auth/            # login, register, switch role
├── profile/         # profil, form tukang, switch role
├── jobs/            # post job, daftar job, detail job
├── chat/            # chat realtime
├── agreement/       # price agreement (nota)
├── tracking/        # peta live GPS
├── review/          # rating & komplain
└── shared/          # widget & model bersama
```

## 2. Navigasi & Layar

### Auth
- **Register** — pilih role (customer/tukang), input email/password → isi profil.
- **Login** — email/password.
- **Onboarding** — intro singkat (opsional).

### Customer
- **Home** — daftar kategori jasa + tombol "Buat Permintaan".
- **Buat Permintaan** — pilih kategori, deskripsi, lokasi (peta/alamat), jadwal.
- **Daftar Permintaan Saya** — status job (open/locked/in_progress/done/paid).
- **Detail Job** — daftar tukang yang merespon, tombol "Pilih Tukang" (lock).
- **Chat** — realtime, lihat nota (price agreement), tombol bayar & konfirmasi.
- **Tracking** — peta live posisi tukang.
- **Rating & Komplain** — setelah selesai.

### Tukang
- **Beranda Tukang** — permintaan masuk dalam radius 50 km, status online/offline.
- **Detail Permintaan** — tombol "Respond" + chat.
- **Chat** — negosiasi, isi harga, buat nota.
- **Kerja** — tombol "Mulai Kerja" (mulai GPS), "Selesai".
- **Konfirmasi Pembayaran** — approve pembayaran diterima.

### Profil & Switch Role
- **Profil** — data diri, pengaturan.
- Tombol **Switch Role** hanya muncul jika akun punya dua role (`is_customer` & `is_tukang`).
- Switch role tanpa logout; UI berubah sesuai role aktif.

## 3. Alur Role

1. User baru: Register (role customer) → Home customer.
2. Jadi tukang: logout → Register pilih "jadi tukang" → login email sama → form tukang (jasa, metode bayar, lokasi) → profil punya 2 role.
3. Setelah 2 role: tombol switch role muncul di Profil.

## 4. Realtime & Tracking

- Chat: subscribe `messages` dengan filter `job_id`.
- Notifikasi job baru: subscribe pada notifikasi yang dikirim RPC `find_providers_nearby`.
- Tracking: subscribe `locations` dengan filter `job_id`; peta menampilkan marker bergerak.

## 5. Desain Visual (ringkas)

- Bahasa Indonesia penuh.
- Warna utama: biru teal (clean, home-service), kontras baik.
- Icon per kategori jasa (AC, cleaning, plumbing, listrik, handyman).
- Bottom navigation sesuai role.