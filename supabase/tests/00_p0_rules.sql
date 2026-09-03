set search_path to public, extensions;

begin;
select plan(54);

-- 1. Tables (11)
select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'tukang_profiles', 'tukang_profiles table exists');
select has_table('public', 'service_categories', 'service_categories table exists');
select has_table('public', 'jobs', 'jobs table exists');
select has_table('public', 'job_applications', 'job_applications table exists');
select has_table('public', 'price_agreements', 'price_agreements table exists');
select has_table('public', 'messages', 'messages table exists');
select has_table('public', 'locations', 'locations table exists');
select has_table('public', 'complaints', 'complaints table exists');
select has_table('public', 'reviews', 'reviews table exists');
select has_table('public', 'app_notifications', 'app_notifications table exists');

-- 2. Extensions (2)
select has_extension('pgcrypto');
select has_extension('postgis');

-- 3. RLS enabled (11)
select is((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), true, 'RLS profiles');
select is((select relrowsecurity from pg_class where oid = 'public.tukang_profiles'::regclass), true, 'RLS tukang_profiles');
select is((select relrowsecurity from pg_class where oid = 'public.service_categories'::regclass), true, 'RLS service_categories');
select is((select relrowsecurity from pg_class where oid = 'public.jobs'::regclass), true, 'RLS jobs');
select is((select relrowsecurity from pg_class where oid = 'public.job_applications'::regclass), true, 'RLS job_applications');
select is((select relrowsecurity from pg_class where oid = 'public.price_agreements'::regclass), true, 'RLS price_agreements');
select is((select relrowsecurity from pg_class where oid = 'public.messages'::regclass), true, 'RLS messages');
select is((select relrowsecurity from pg_class where oid = 'public.locations'::regclass), true, 'RLS locations');
select is((select relrowsecurity from pg_class where oid = 'public.complaints'::regclass), true, 'RLS complaints');
select is((select relrowsecurity from pg_class where oid = 'public.reviews'::regclass), true, 'RLS reviews');
select is((select relrowsecurity from pg_class where oid = 'public.app_notifications'::regclass), true, 'RLS app_notifications');

-- 4. Unique constraints (4)
select has_index('public', 'profiles', 'profiles_email_key', 'unique email index');
select has_index('public', 'job_applications', 'job_applications_unique', 'applications unique');
select has_index('public', 'price_agreements', 'price_agreements_unique', 'price_agreements unique');
select has_index('public', 'reviews', 'reviews_unique', 'reviews unique');

-- 5. Functions / RPCs (6)
select has_function('public', 'become_tukang', array['text','uuid[]','payment_method[]'], 'become_tukang');
select has_function('public', 'find_providers_nearby', array['uuid','integer'], 'find_providers_nearby');
select has_function('public', 'admin_set_suspended', array['uuid','boolean'], 'admin_set_suspended');
select has_function('public', 'is_customer', array[]::text[], 'is_customer');
select has_function('public', 'is_tukang', array[]::text[], 'is_tukang');
select has_function('public', 'is_admin', array[]::text[], 'is_admin');

-- 6. Triggers (4)
select trigger_is('public', 'jobs', 'jobs_status_guard', 'public', 'jobs_status_guard');
select trigger_is('public', 'jobs', 'jobs_provider_guard', 'public', 'jobs_provider_guard');
select trigger_is('public', 'jobs', 'jobs_lock_applications', 'public', 'jobs_lock_applications');
select trigger_is('public', 'reviews', 'reviews_update_rating', 'public', 'reviews_update_rating');

-- 7. Valid status transitions (4)
do $$
declare v_cat_id uuid;
begin
  select id into v_cat_id from public.service_categories where slug = 'ac' limit 1;
  insert into public.jobs (id, customer_id, category_id, title, description, lat, lng, status)
  values ('d0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', v_cat_id, 'Test job', 'Test', -6.1754, 106.8272, 'open');
end $$;

prepare lock_job as update public.jobs set status = 'locked', selected_provider_id = 'b1000000-0000-0000-0000-000000000001' where id = 'd0000000-0000-0000-0000-000000000001';
select lives_ok('lock_job', 'open -> locked');
deallocate lock_job;

prepare start_job as update public.jobs set status = 'in_progress' where id = 'd0000000-0000-0000-0000-000000000001';
select lives_ok('start_job', 'locked -> in_progress');
deallocate start_job;

prepare done_job as update public.jobs set status = 'done' where id = 'd0000000-0000-0000-0000-000000000001';
select lives_ok('done_job', 'in_progress -> done');
deallocate done_job;

prepare pay_job as update public.jobs set status = 'paid' where id = 'd0000000-0000-0000-0000-000000000001';
select lives_ok('pay_job', 'done -> paid');
deallocate pay_job;

-- 8. Invalid status transitions (3)
do $$
declare v_cat_id uuid;
begin
  select id into v_cat_id from public.service_categories where slug = 'ac' limit 1;
  insert into public.jobs (id, customer_id, category_id, title, description, lat, lng, status)
  values ('d0000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', v_cat_id, 'Test job 2', 'Test', -6.1754, 106.8272, 'open');
end $$;

prepare invalid_pay as update public.jobs set status = 'paid' where id = 'd0000000-0000-0000-0000-000000000002';
select throws_ok('invalid_pay', 'P0001', null, 'open -> paid is rejected');
deallocate invalid_pay;

prepare invalid_done as update public.jobs set status = 'done' where id = 'd0000000-0000-0000-0000-000000000002';
select throws_ok('invalid_done', 'P0001', null, 'open -> done is rejected');
deallocate invalid_done;

prepare invalid_ip as update public.jobs set status = 'in_progress' where id = 'd0000000-0000-0000-0000-000000000002';
select throws_ok('invalid_ip', 'P0001', null, 'open -> in_progress is rejected');
deallocate invalid_ip;

-- 9. Lock applications trigger + provider guard (5)
do $$
declare v_cat_id uuid;
begin
  select id into v_cat_id from public.service_categories where slug = 'cleaning' limit 1;
  insert into public.jobs (id, customer_id, category_id, title, description, lat, lng, status)
  values ('d0000000-0000-0000-0000-000000000010', 'a1000000-0000-0000-0000-000000000001', v_cat_id, 'Lock test job', 'Test', -6.1754, 106.8272, 'open');
  insert into public.job_applications (job_id, provider_id, status)
  values ('d0000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000001', 'responded'),
         ('d0000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000002', 'responded');
  insert into public.price_agreements (job_id, customer_id, provider_id, amount, payment_method)
  values ('d0000000-0000-0000-0000-000000000010', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 150000, 'cash'),
         ('d0000000-0000-0000-0000-000000000010', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 200000, 'bank_transfer');
  update public.jobs set status = 'locked', selected_provider_id = 'b1000000-0000-0000-0000-000000000001'
   where id = 'd0000000-0000-0000-0000-000000000010';
end $$;

select is((select status from public.job_applications where job_id = 'd0000000-0000-0000-0000-000000000010' and provider_id = 'b1000000-0000-0000-0000-000000000001'), 'selected'::public.application_status, 'app selected');
select is((select status from public.job_applications where job_id = 'd0000000-0000-0000-0000-000000000010' and provider_id = 'b1000000-0000-0000-0000-000000000002'), 'locked_out'::public.application_status, 'app locked_out');
select is((select voided from public.price_agreements where job_id = 'd0000000-0000-0000-0000-000000000010' and provider_id = 'b1000000-0000-0000-0000-000000000002'), true, 'nota voided');
select is((select voided from public.price_agreements where job_id = 'd0000000-0000-0000-0000-000000000010' and provider_id = 'b1000000-0000-0000-0000-000000000001'), false, 'nota not voided');

do $$
declare v_cat_id uuid;
begin
  select id into v_cat_id from public.service_categories where slug = 'ac' limit 1;
  insert into public.jobs (id, customer_id, category_id, title, description, lat, lng, status)
  values ('d0000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001', v_cat_id, 'Test job 3', 'Test', -6.1754, 106.8272, 'open');
  update public.jobs set status = 'locked' where id = 'd0000000-0000-0000-0000-000000000003';
end $$;

prepare no_provider_ip as update public.jobs set status = 'in_progress' where id = 'd0000000-0000-0000-0000-000000000003';
select throws_ok('no_provider_ip', 'P0001', null, 'in_progress without provider is rejected');
deallocate no_provider_ip;

-- 10. Amount check constraint (2)
do $$
declare v_cat_id uuid;
begin
  select id into v_cat_id from public.service_categories where slug = 'plumbing' limit 1;
  insert into public.jobs (id, customer_id, category_id, title, description, lat, lng, status)
  values ('d0000000-0000-0000-0000-000000000011', 'a1000000-0000-0000-0000-000000000001', v_cat_id, 'Amount test', 'Test', -6.1754, 106.8272, 'open');
  insert into public.job_applications (job_id, provider_id)
  values ('d0000000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000001');
end $$;

prepare zero_amount as insert into public.price_agreements (job_id, customer_id, provider_id, amount, payment_method)
  values ('d0000000-0000-0000-0000-000000000011', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 0, 'cash');
select throws_ok('zero_amount', '23514', null, 'amount = 0 rejected');
deallocate zero_amount;

prepare neg_amount as insert into public.price_agreements (job_id, customer_id, provider_id, amount, payment_method)
  values ('d0000000-0000-0000-0000-000000000011', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', -100, 'cash');
select throws_ok('neg_amount', '23514', null, 'neg amount rejected');
deallocate neg_amount;

-- 11. Rating check constraint (2)
prepare bad_r0 as insert into public.reviews (job_id, customer_id, provider_id, rating)
  values ('d0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 0);
select throws_ok('bad_r0', '23514', null, 'rating 0 rejected');
deallocate bad_r0;

prepare bad_r6 as insert into public.reviews (job_id, customer_id, provider_id, rating)
  values ('d0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 6);
select throws_ok('bad_r6', '23514', null, 'rating 6 rejected');
deallocate bad_r6;

select * from finish();
rollback;
