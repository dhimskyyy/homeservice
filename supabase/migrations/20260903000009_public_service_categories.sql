-- Allow anonymous and authenticated users to read service categories catalogue
grant usage on schema public to anon;
grant select on public.service_categories to anon;

drop policy if exists "service_categories_select" on public.service_categories;

create policy "service_categories_select"
  on public.service_categories for select
  to anon, authenticated
  using ( true );
