create table public.app_notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null,
  job_id      uuid references public.jobs(id) on delete cascade,
  body        text not null,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

create index app_notifications_user_idx on public.app_notifications (user_id, created_at desc);

alter table public.app_notifications enable row level security;

create policy "app_notifications_select_own"
  on public.app_notifications for select
  to authenticated
  using ( user_id = auth.uid() );

create policy "app_notifications_update_own"
  on public.app_notifications for update
  to authenticated
  using ( user_id = auth.uid() )
  with check ( user_id = auth.uid() );

alter publication supabase_realtime add table public.app_notifications;
