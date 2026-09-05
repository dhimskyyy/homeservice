-- ============================================================
-- BUG-6: admin_set_suspended harus SECURITY DEFINER agar bisa
-- update profiles user lain (RLS profiles_update_own memblokir).
-- ============================================================
create or replace function public.admin_set_suspended(p_user_id uuid, p_suspended boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Forbidden: hanya admin';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'Tidak bisa suspend akun sendiri';
  end if;
  update public.profiles
     set is_suspended = p_suspended,
         updated_at = now()
   where id = p_user_id;
end;
$$;

-- ============================================================
-- BUG-3: jobs_lock_applications harus SECURITY DEFINER agar bisa
-- update job_applications & price_agreements milik provider lain
-- (locked_out, selected, void nota kalah tender).
-- ============================================================
create or replace function public.jobs_lock_applications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'locked' and old.status = 'open' then
    update public.job_applications
       set status = 'locked_out'
     where job_id = new.id
       and provider_id <> new.selected_provider_id;

    update public.job_applications
       set status = 'selected'
     where job_id = new.id
       and provider_id = new.selected_provider_id;

    update public.price_agreements
       set voided = true
     where job_id = new.id
       and provider_id <> new.selected_provider_id;

    update public.price_agreements
       set voided = false
     where job_id = new.id
       and provider_id = new.selected_provider_id;
  end if;
  return new;
end;
$$;

-- ============================================================
-- BUG-2: approve_payment_provider — RPC atomic 1 langkah:
-- nota pending->paid + job done->paid, validasi ketat.
-- ============================================================
create or replace function public.approve_payment_provider(
  p_agreement_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_provider uuid;
  v_job_id uuid;
  v_job_status public.job_status;
begin
  select provider_id, job_id into v_provider, v_job_id
    from public.price_agreements
   where id = p_agreement_id;

  if v_provider is null then
    raise exception 'Nota tidak ditemukan';
  end if;
  if v_provider <> auth.uid() then
    raise exception 'Forbidden: bukan nota Anda';
  end if;

  select status into v_job_status from public.jobs where id = v_job_id;
  if v_job_status <> 'done' then
    raise exception 'Pekerjaan harus selesai (done) sebelum approve pembayaran';
  end if;

  update public.price_agreements
     set status = 'paid',
         paid_at = now()
   where id = p_agreement_id
     and status = 'pending'
     and voided = false;

  if not found then
    raise exception 'Nota tidak valid untuk disetujui';
  end if;

  update public.jobs
     set status = 'paid',
         updated_at = now()
   where id = v_job_id
     and status = 'done';
end;
$$;

revoke execute on function public.approve_payment_provider(uuid) from public, anon;
grant execute on function public.approve_payment_provider(uuid) to authenticated;

-- ============================================================
-- BUG-4: messages hanya boleh update kolom read status.
-- Guard trigger: tolak jika kolom lain berubah.
-- ============================================================
create or replace function public.messages_read_guard()
returns trigger
language plpgsql
as $$
begin
  if new.body is distinct from old.body
     or new.media_url is distinct from old.media_url
     or new.sender_id is distinct from old.sender_id
     or new.job_id is distinct from old.job_id
     or new.created_at is distinct from old.created_at then
    raise exception 'Hanya status baca pesan yang boleh diubah';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_messages_read_guard on public.messages;
create trigger trg_messages_read_guard
  before update on public.messages
  for each row execute function public.messages_read_guard();

-- ============================================================
-- GAP: admin bisa baca app_notifications (audit)
-- ============================================================
drop policy if exists "app_notifications_admin_read" on public.app_notifications;
create policy "app_notifications_admin_read"
  on public.app_notifications for select
  to authenticated
  using ( public.is_admin() );

-- ============================================================
-- GAP-minor: customer tidak boleh hapus job berstatus paid
-- (mempertahankan jejak audit nota/review)
-- ============================================================
drop policy if exists "jobs_delete_customer" on public.jobs;
create policy "jobs_delete_customer"
  on public.jobs for delete
  to authenticated
  using ( customer_id = auth.uid() and status in ('open', 'cancelled') );
