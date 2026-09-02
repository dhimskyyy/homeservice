# Tech Stack — Beres

Keputusan stack lengkap beserta alasan dan library spesifik.

## 1. Ringkasan

| Lapisan | Teknologi | Versi/ref | Alasan |
|---------|-----------|-----------|--------|
| Mobile app | Flutter (Dart) | stable (3.x) | satu codebase Android + iOS |
| State mgmt | Riverpod | latest | testable, cocok 2 role |
| Routing | go_router | latest | deep link ke chat/job |
| DB client | supabase_flutter | latest | Auth, PostgREST, Realtime, Storage |
| Peta mobile | flutter_map + latlong2 | latest | OSM gratis tanpa API key |
| Lokasi | geolocator | latest | GPS posisi |
| Web admin | Next.js (App Router) + TS | 14/15 | integrasi @supabase/ssr, deploy Vercel |
| Admin auth | @supabase/ssr | latest | cookie session SSR |
| Peta admin | Leaflet + react-leaflet | latest | OSM gratis |
| Backend | Supabase | cloud | Postgres + Auth + Realtime + Edge Fn |
| Geo query | PostGIS (ST_DWithin) | supabase ext | radius 50 km akurat |
| Font | Poppins + Open Sans | Google Fonts | heading + body |

## 2. Alasan memilih Supabase (vs Firebase)

1. **Relasional** — booking, nota, negosiasi, komplain natural di Postgres; Firestore (NoSQL) repot untuk relasi banyak-ke-banyak.
2. **RLS** — kontrol akses per baris per role (customer/tukang/admin) di level database.
3. **Realtime** — chat & tracking tanpa layanan tambahan.
4. **PostGIS** — pencarian radius 50 km akurat (Firebase tak punya geospasial setara).
5. **Admin bisa query langsung** — Next.js SSR query Postgres lewat @supabase/ssr.

## 3. Alasan memilih OpenStreetMap (vs Google Maps / Mapbox)

- Gratis & tanpa API key/kartu kredit (Google Maps butuh billing; Mapbox butuh token).
- flutter_map (mobile) dan Leaflet (admin) sama-sama OSM.
- Trade-off: akurasi routing/geocode Indonesia lebih terbatas — untuk MVP cukup (tracking posisi, bukan navigasi turn-by-turn).

## 4. Flutter — library terpilih

| Kebutuhan | Paket |
|-----------|-------|
| State | flutter_riverpod |
| Routing | go_router |
| Supabase | supabase_flutter |
| Peta | flutter_map, latlong2 |
| GPS | geolocator |
| Ikon | lucide_icons (atau phosphor_flutter) — SVG, bukan emoji |
| Format uang | intl (NumberFormat Rupiah) |

## 5. Next.js admin — library terpilih

| Kebutuhan | Paket |
|-----------|-------|
| Supabase | @supabase/ssr, @supabase/supabase-js |
| Peta | leaflet, react-leaflet |
| Tabel/UI | komponen sendiri (DataTable custom) atau shadcn/ui |
| Grafik | recharts (opsional, dashboard) |
| Validasi | zod (form admin opsional) |

## 6. Keputusan yang Ditunda (pasca-MVP)

- **Push notification** (FCM/OneSignal) — MVP in-app Realtime.
- **Payment gateway** (Midtrans/Xendit) — menunggu konfirmasi pendaftaran; MVP P2P manual.
- **KYC tukang** & verifikasi dokumen.
- **Escrow** — menyusul jika perlu jaminan dana.

## 7. Prinsip Versi & Keamanan

- Pin versi dependency + commit lockfile (`pubspec.lock`, `package-lock.json`).
- Supabase packages selalu cek changelog sebelum upgrade (breaking change).
- `service_role` key hanya di server/Edge Function; `anon`/publishable key untuk client.
- Jangan pakai `NEXT_PUBLIC_` untuk kunci rahasia.
