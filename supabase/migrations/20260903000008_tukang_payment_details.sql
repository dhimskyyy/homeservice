-- Add payment_details JSONB to tukang_profiles for storing detailed e-wallet and bank account numbers
alter table public.tukang_profiles
  add column if not exists payment_details jsonb not null default '{}'::jsonb;

-- Overload / update become_tukang to accept payment_details
create or replace function public.become_tukang(
  p_bio text,
  p_service_type_ids uuid[],
  p_payment_methods public.payment_method[],
  p_payment_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security invoker
as $$
begin
  if not (select exists(select 1 from public.profiles where id = auth.uid())) then
    raise exception 'Profile not found';
  end if;

  update public.profiles
     set is_tukang = true,
         updated_at = now()
   where id = auth.uid();

  insert into public.tukang_profiles (profile_id, bio, service_type_ids, payment_methods, payment_details)
  values (auth.uid(), p_bio, p_service_type_ids, p_payment_methods, p_payment_details)
  on conflict (profile_id) do update
     set bio = excluded.bio,
         service_type_ids = excluded.service_type_ids,
         payment_methods = excluded.payment_methods,
         payment_details = excluded.payment_details;
end;
$$;
