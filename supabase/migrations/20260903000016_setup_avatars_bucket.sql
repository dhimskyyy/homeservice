-- Setup public storage bucket for user avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

-- Storage policies for avatars
drop policy if exists "avatars_select_public" on storage.objects;
drop policy if exists "avatars_insert_authenticated" on storage.objects;
drop policy if exists "avatars_update_authenticated" on storage.objects;
drop policy if exists "avatars_delete_authenticated" on storage.objects;

create policy "avatars_select_public"
  on storage.objects for select
  to public, anon, authenticated
  using ( bucket_id = 'avatars' );

create policy "avatars_insert_authenticated"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'avatars' );

create policy "avatars_update_authenticated"
  on storage.objects for update
  to authenticated
  using ( bucket_id = 'avatars' );

create policy "avatars_delete_authenticated"
  on storage.objects for delete
  to authenticated
  using ( bucket_id = 'avatars' );
