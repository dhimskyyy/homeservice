-- Auto-create profile row when a new user signs up.
-- This runs as security definer (bypasses RLS), fixing the
-- "new row violates row-level security policy" error that occurs
-- when the client tries to insert into profiles before the
-- user session is confirmed.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, is_customer, is_tukang)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce((new.raw_user_meta_data ->> 'is_customer')::boolean, false),
    coalesce((new.raw_user_meta_data ->> 'is_tukang')::boolean, false)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();