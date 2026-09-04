-- Fix reviews_update_rating trigger to use SECURITY DEFINER so that
-- customer review insertions can update tukang_profiles (rating_avg and job_count)
create or replace function public.reviews_update_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tukang_profiles
     set rating_avg = coalesce((
       select round(avg(rating)::numeric, 1) from public.reviews
       where provider_id = new.provider_id
     ), 0.0),
     job_count = coalesce((
       select count(*) from public.reviews
       where provider_id = new.provider_id
     ), 0)
   where profile_id = new.provider_id;
  return new;
end;
$$;

-- Trigger ulang untuk mengkalkulasi ulang data tukang saat ini jika ada review lama
do $$
declare
  r record;
begin
  for r in (select distinct provider_id from public.reviews) loop
    update public.tukang_profiles
       set rating_avg = coalesce((
         select round(avg(rating)::numeric, 1) from public.reviews
         where provider_id = r.provider_id
       ), 0.0),
       job_count = coalesce((
         select count(*) from public.reviews
         where provider_id = r.provider_id
       ), 0)
     where profile_id = r.provider_id;
  end loop;
end $$;
