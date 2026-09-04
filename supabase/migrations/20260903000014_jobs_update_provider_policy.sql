-- Allow selected tukang to update job status (in_progress, done, paid) as enforced by triggers
create policy "jobs_update_provider"
  on public.jobs for update
  to authenticated
  using (
    selected_provider_id = auth.uid()
    and not public.is_suspended_profile(auth.uid())
  )
  with check (
    selected_provider_id = auth.uid()
  );
