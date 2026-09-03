-- Seed data for Beres

insert into public.service_categories (name, slug, icon, sort_order) values
  ('AC', 'ac', 'ac_unit', 1),
  ('Cleaning', 'cleaning', 'cleaning_services', 2),
  ('Plumbing', 'plumbing', 'plumbing', 3),
  ('Listrik', 'listrik', 'electric_bolt', 4),
  ('Handyman', 'handyman', 'build', 5);

-- Seed users via auth.users → trigger internal.handle_new_user auto-creates profiles.
-- Password for all: 'password123'
-- Hashed with bcrypt (Supabase default).
insert into auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at,
  confirmation_token, recovery_token, is_super_admin
) values
  -- Customer 1: Jakarta Pusat
  (
    'a1000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'customer1@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Budi Santoso"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  ),
  -- Customer 2: Jakarta Selatan
  (
    'a1000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'customer2@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Siti Rahayu"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  ),
  -- Tukang 1: Jakarta Timur (~10 km dari pusat)
  (
    'b1000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'tukang1@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Agus Pratama"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  ),
  -- Tukang 2: Tangerang (~25 km dari pusat)
  (
    'b1000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'tukang2@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Dewi Lestari"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  ),
  -- Tukang 3: Bandung (~150 km, di luar radius 50 km)
  (
    'b1000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'tukang3@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Rina Wulandari"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  ),
  -- Admin
  (
    'c1000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'admin@beres.test',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Admin Beres"}',
    'authenticated', 'authenticated', now(), now(),
    '', '', false
  );

-- Identities (required by Supabase Auth)
insert into auth.identities (
  id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
) values
  ('a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', '{"sub":"a1000000-0000-0000-0000-000000000001","email":"customer1@beres.test"}', 'email', now(), now(), now()),
  ('a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002', '{"sub":"a1000000-0000-0000-0000-000000000002","email":"customer2@beres.test"}', 'email', now(), now(), now()),
  ('b1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', '{"sub":"b1000000-0000-0000-0000-000000000001","email":"tukang1@beres.test"}', 'email', now(), now(), now()),
  ('b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', '{"sub":"b1000000-0000-0000-0000-000000000002","email":"tukang2@beres.test"}', 'email', now(), now(), now()),
  ('b1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000003', '{"sub":"b1000000-0000-0000-0000-000000000003","email":"tukang3@beres.test"}', 'email', now(), now(), now()),
  ('c1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', '{"sub":"c1000000-0000-0000-0000-000000000001","email":"admin@beres.test"}', 'email', now(), now(), now());

-- handle_new_user trigger auto-creates profiles with is_customer=true.
-- Now update profiles with correct roles and coordinates.

-- Customer 1: Jakarta Pusat (-6.1754, 106.8272)
update public.profiles
  set lat = -6.1754, lng = 106.8272, full_name = 'Budi Santoso'
where id = 'a1000000-0000-0000-0000-000000000001';

-- Customer 2: Jakarta Selatan (-6.2615, 106.8106)
update public.profiles
  set lat = -6.2615, lng = 106.8106, full_name = 'Siti Rahayu'
where id = 'a1000000-0000-0000-0000-000000000002';

-- Tukang 1: Jakarta Timur (-6.2250, 106.9004)
update public.profiles
  set is_tukang = true, is_online = true,
      lat = -6.2250, lng = 106.9004, full_name = 'Agus Pratama'
where id = 'b1000000-0000-0000-0000-000000000001';

-- Tukang 2: Tangerang (-6.1781, 106.6319)
update public.profiles
  set is_tukang = true, is_online = true,
      lat = -6.1781, lng = 106.6319, full_name = 'Dewi Lestari'
where id = 'b1000000-0000-0000-0000-000000000002';

-- Tukang 3: Bandung (-6.9175, 107.6191) — di luar radius 50 km dari Jakarta
update public.profiles
  set is_tukang = true, is_online = true,
      lat = -6.9175, lng = 107.6191, full_name = 'Rina Wulandari'
where id = 'b1000000-0000-0000-0000-000000000003';

-- Admin
update public.profiles
  set is_admin = true, is_customer = false, full_name = 'Admin Beres'
where id = 'c1000000-0000-0000-0000-000000000001';

-- Tukang profiles
insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods)
select
  'b1000000-0000-0000-0000-000000000001',
  'Spesialis AC dan listrik, pengalaman 5 tahun.',
  array(select id from public.service_categories where slug in ('ac', 'listrik')),
  array['cash', 'ewallet']::public.payment_method[];

insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods)
select
  'b1000000-0000-0000-0000-000000000002',
  'Tukang cleaning dan handyman profesional.',
  array(select id from public.service_categories where slug in ('cleaning', 'handyman')),
  array['cash', 'bank_transfer']::public.payment_method[];

insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods)
select
  'b1000000-0000-0000-0000-000000000003',
  'Plumbing dan AC area Bandung.',
  array(select id from public.service_categories where slug in ('plumbing', 'ac')),
  array['cash', 'ewallet', 'bank_transfer']::public.payment_method[];
