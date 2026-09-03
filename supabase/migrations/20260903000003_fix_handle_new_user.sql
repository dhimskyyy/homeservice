create schema if not exists internal;

create or replace function internal.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = internal
as $$
begin
  insert into public.profiles (id, email, full_name, is_customer)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    true
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function internal.handle_new_user();
