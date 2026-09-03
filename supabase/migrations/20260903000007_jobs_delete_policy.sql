-- Allow customers to delete their own cancelled, open, or paid jobs from history
create policy "jobs_delete_customer"
  on public.jobs for delete
  to authenticated
  using ( customer_id = auth.uid() and status in ('open', 'cancelled', 'paid') );
