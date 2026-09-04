-- Allow tukang to create price agreement when job is open OR locked to that tukang
drop policy if exists "price_agreements_insert_responded_tukang" on public.price_agreements;

create policy "price_agreements_insert_responded_tukang"
  on public.price_agreements for insert
  to authenticated
  with check (
    provider_id = auth.uid()
    and exists (
      select 1 from public.jobs j
      where j.id = job_id
        and (
          -- Saat open: tukang yang sudah apply dan belum di-lockout
          (j.status = 'open' and exists (
            select 1 from public.job_applications a
            where a.job_id = j.id and a.provider_id = auth.uid() and a.status <> 'locked_out'
          ))
          -- Saat locked: tukang yang terpilih
          or (j.status = 'locked' and j.selected_provider_id = auth.uid())
        )
    )
  );
