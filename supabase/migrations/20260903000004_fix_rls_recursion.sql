-- Fix infinite recursion (42P17) between jobs and job_applications RLS policies

create or replace function internal.is_job_customer(p_job_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.jobs
    where id = p_job_id and customer_id = p_user_id
  );
$$;

create or replace function internal.has_provider_applied(p_job_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.job_applications
    where job_id = p_job_id and provider_id = p_user_id
  );
$$;

drop policy if exists "jobs_select_involved" on public.jobs;
drop policy if exists "job_applications_select" on public.job_applications;

create policy "jobs_select_involved"
  on public.jobs for select
  to authenticated
  using (
    customer_id = auth.uid()
    or status = 'open'
    or selected_provider_id = auth.uid()
    or internal.has_provider_applied(id, auth.uid())
    or public.is_admin()
  );

create policy "job_applications_select"
  on public.job_applications for select
  to authenticated
  using (
    provider_id = auth.uid()
    or internal.is_job_customer(job_id, auth.uid())
    or public.is_admin()
  );
