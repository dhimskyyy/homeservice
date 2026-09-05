-- 1. Fix handle_new_user: Tukang murni is_customer = false, is_tukang = true
create or replace function internal.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public, internal
as $$
declare
  v_is_tukang boolean;
  v_bio text;
  v_uuid_services uuid[] := '{}';
  v_enum_methods public.payment_method[] := '{}';
  v_payment_details jsonb;
begin
  v_is_tukang := coalesce((new.raw_user_meta_data ->> 'role') = 'tukang', false);
  v_bio := coalesce(new.raw_user_meta_data ->> 'bio', '');
  v_payment_details := coalesce(new.raw_user_meta_data -> 'payment_details', '{}'::jsonb);

  -- Insert profile: jika tukang, is_customer = false
  insert into public.profiles (
    id, email, full_name, is_customer, is_tukang, is_online
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    not v_is_tukang, -- Customer HANYA jika bukan tukang
    v_is_tukang,
    v_is_tukang
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    is_customer = excluded.is_customer,
    is_tukang = excluded.is_tukang,
    is_online = excluded.is_online;

  -- Jika mendaftar sebagai tukang, buatkan tukang_profiles
  if v_is_tukang then
    if (new.raw_user_meta_data -> 'service_type_ids') is not null then
      select coalesce(array_agg(value::text::uuid), '{}'::uuid[])
        into v_uuid_services
        from jsonb_array_elements_text(new.raw_user_meta_data -> 'service_type_ids');
    end if;

    if cardinality(v_uuid_services) = 0 then
      select array_agg(id) into v_uuid_services from public.service_categories;
    end if;

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

-- Perbaiki akun tukang yang baru mendaftar agar is_customer = false (hanya 1 role tukang)
-- CATATAN: data-fix email personal dihapus dari repo (PII). Untuk data produksi,
-- gunakan SQL Editor secara manual bila diperlukan.
update public.profiles
   set is_customer = false
 where is_tukang = true
   and is_customer = true
   and not exists (
     select 1 from public.tukang_profiles tp where tp.profile_id = profiles.id
   );

-- 2. Tambah kolom media_url dan status read di tabel messages
alter table public.messages
  add column if not exists media_url text,
  add column if not exists is_read boolean not null default false,
  add column if not exists read_at timestamptz;

-- Mengizinkan body kosong jika ada media_url
alter table public.messages
  drop constraint if exists messages_body_check;

alter table public.messages
  add constraint messages_body_check
    check (
      (media_url is not null and (body is null or char_length(body) <= 2000))
      or (char_length(body) between 1 and 2000)
    );

-- 3. Perbaiki RLS policies untuk messages: tukang yang sudah merespon (apply) boleh membaca & mengirim chat
drop policy if exists "messages_select_involved" on public.messages;
drop policy if exists "messages_insert_involved" on public.messages;
drop policy if exists "messages_update_read" on public.messages;

create policy "messages_select_involved"
  on public.messages for select
  to authenticated
  using (
    sender_id = auth.uid()
    or internal.is_job_customer(job_id, auth.uid())
    or exists (
      select 1 from public.jobs j
      where j.id = job_id and j.selected_provider_id = auth.uid()
    )
    or internal.has_provider_applied(job_id, auth.uid())
    or public.is_admin()
  );

create policy "messages_insert_involved"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and (
      internal.is_job_customer(job_id, auth.uid())
      or exists (
        select 1 from public.jobs j
        where j.id = job_id and j.selected_provider_id = auth.uid()
      )
      or internal.has_provider_applied(job_id, auth.uid())
    )
  );

-- Update read status oleh penerima pesan
create policy "messages_update_read"
  on public.messages for update
  to authenticated
  using (
    sender_id <> auth.uid()
    and (
      internal.is_job_customer(job_id, auth.uid())
      or exists (
        select 1 from public.jobs j
        where j.id = job_id and j.selected_provider_id = auth.uid()
      )
      or internal.has_provider_applied(job_id, auth.uid())
    )
  )
  with check (
    is_read = true
  );

-- 4. Setup storage bucket 'chat-attachments' jika belum ada
insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', true)
on conflict (id) do update set public = true;

-- Storage policies for chat attachments
drop policy if exists "chat_attachments_select" on storage.objects;
drop policy if exists "chat_attachments_insert" on storage.objects;

create policy "chat_attachments_select"
  on storage.objects for select
  to authenticated, anon
  using ( bucket_id = 'chat-attachments' );

create policy "chat_attachments_insert"
  on storage.objects for insert
  to authenticated
  with check ( bucket_id = 'chat-attachments' );
