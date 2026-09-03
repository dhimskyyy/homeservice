-- Fix stack depth limit exceeded (54001) caused by recursive RLS on profiles and is_admin helper

create schema if not exists internal;

-- Internal security definer functions to bypass RLS when checking roles
create or replace function internal.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  );
$$;

create or replace function internal.is_customer()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_customer = true
  );
$$;

create or replace function internal.is_tukang()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_tukang = true
  );
$$;

create or replace function internal.is_suspended_profile(p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = p_user_id and is_suspended = true
  );
$$;

-- Delegate public helpers to internal security definer functions
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select internal.is_admin();
$$;

create or replace function public.is_customer()
returns boolean
language sql
stable
as $$
  select internal.is_customer();
$$;

create or replace function public.is_tukang()
returns boolean
language sql
stable
as $$
  select internal.is_tukang();
$$;

create or replace function public.is_suspended_profile(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select internal.is_suspended_profile(p_user_id);
$$;

-- Allow authenticated users to view profiles (needed for mutual lookup between customer & tukang)
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
drop policy if exists "profiles_select_all" on public.profiles;

create policy "profiles_select_all"
  on public.profiles for select
  to authenticated
  using ( true );

-- Allow authenticated users to view tukang profiles
drop policy if exists "tukang_profiles_select" on public.tukang_profiles;

create policy "tukang_profiles_select"
  on public.tukang_profiles for select
  to authenticated
  using ( true );
