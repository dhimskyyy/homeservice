-- Update handle_new_user trigger to properly register tukang directly from signup metadata
create or replace function internal.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public, internal
as $$
declare
  v_is_tukang boolean;
  v_bio text;
  v_service_ids text[];
  v_uuid_services uuid[] := '{}';
  v_payment_methods text[];
  v_enum_methods public.payment_method[] := '{}';
  v_payment_details jsonb;
  v_item text;
begin
  v_is_tukang := coalesce((new.raw_user_meta_data ->> 'role') = 'tukang', false);
  v_bio := coalesce(new.raw_user_meta_data ->> 'bio', '');
  v_payment_details := coalesce(new.raw_user_meta_data -> 'payment_details', '{}'::jsonb);

  -- 1. Insert into public.profiles
  insert into public.profiles (
    id, email, full_name, is_customer, is_tukang, is_online
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    true,
    v_is_tukang,
    v_is_tukang -- otomatis online saat daftar jadi tukang
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    is_tukang = excluded.is_tukang,
    is_online = excluded.is_online;

  -- 2. Jika mendaftar sebagai tukang, langsung buatkan tukang_profiles
  if v_is_tukang then
    -- Convert JSON array of string UUIDs to uuid[]
    if (new.raw_user_meta_data -> 'service_type_ids') is not null then
      select coalesce(array_agg(value::text::uuid), '{}'::uuid[])
        into v_uuid_services
        from jsonb_array_elements_text(new.raw_user_meta_data -> 'service_type_ids');
    end if;

    -- If no services selected, default to all available categories
    if cardinality(v_uuid_services) = 0 then
      select array_agg(id) into v_uuid_services from public.service_categories;
    end if;

    -- Convert JSON array of payment methods to public.payment_method[]
    if (new.raw_user_meta_data -> 'payment_methods') is not null then
      select coalesce(array_agg(value::text::public.payment_method), '{}'::public.payment_method[])
        into v_enum_methods
        from jsonb_array_elements_text(new.raw_user_meta_data -> 'payment_methods');
    end if;

    if cardinality(v_enum_methods) = 0 then
      v_enum_methods := array['cash']::public.payment_method[];
    end if;

    insert into public.tukang_profiles (
      profile_id, bio, service_type_ids, payment_methods, payment_details
    ) values (
      new.id,
      case when length(v_bio) > 0 then v_bio else 'Mitra Tukang Beres Profesional' end,
      coalesce(v_uuid_services, '{}'::uuid[]),
      v_enum_methods,
      v_payment_details
    )
    on conflict (profile_id) do update set
      bio = excluded.bio,
      service_type_ids = excluded.service_type_ids,
      payment_methods = excluded.payment_methods,
      payment_details = excluded.payment_details;
  end if;

  return new;
end;
$$;

-- Langsung aktifkan role tukang untuk akun Anda yang sudah terdaftar
do $$
declare
  v_rec record;
  v_services uuid[];
begin
  select array_agg(id) into v_services from public.service_categories;

  for v_rec in (
    select id from public.profiles
    where email in ('dhmsafrzl@gmail.com', 'mdhimas25@gmail.com')
  ) loop
    update public.profiles
       set is_tukang = true, is_online = true
     where id = v_rec.id;

    insert into public.tukang_profiles (
      profile_id, bio, service_type_ids, payment_methods, payment_details
    ) values (
      v_rec.id,
      'Mitra Tukang Beres Profesional',
      v_services,
      array['cash', 'ewallet']::public.payment_method[],
      '{"cash": true}'::jsonb
    )
    on conflict (profile_id) do update set
      service_type_ids = excluded.service_type_ids;
  end loop;
end $$;
