-- ============================================================
-- Migration 20260903000021: FCM Device Tokens Table
-- ============================================================

create table if not exists public.user_fcm_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  device_type text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_fcm_tokens_user_token_key unique (user_id, token)
);

create index if not exists user_fcm_tokens_user_idx on public.user_fcm_tokens(user_id);

alter table public.user_fcm_tokens enable row level security;

-- Policy: User hanya bisa baca, insert, dan hapus token milik sendiri
drop policy if exists "user_fcm_tokens_select_own" on public.user_fcm_tokens;
create policy "user_fcm_tokens_select_own"
  on public.user_fcm_tokens for select
  to authenticated
  using ( user_id = auth.uid() );

drop policy if exists "user_fcm_tokens_insert_own" on public.user_fcm_tokens;
create policy "user_fcm_tokens_insert_own"
  on public.user_fcm_tokens for insert
  to authenticated
  with check ( user_id = auth.uid() );

drop policy if exists "user_fcm_tokens_update_own" on public.user_fcm_tokens;
create policy "user_fcm_tokens_update_own"
  on public.user_fcm_tokens for update
  to authenticated
  using ( user_id = auth.uid() )
  with check ( user_id = auth.uid() );

drop policy if exists "user_fcm_tokens_delete_own" on public.user_fcm_tokens;
create policy "user_fcm_tokens_delete_own"
  on public.user_fcm_tokens for delete
  to authenticated
  using ( user_id = auth.uid() );

-- Grant permissions ke role authenticated
grant select, insert, update, delete on public.user_fcm_tokens to authenticated;
