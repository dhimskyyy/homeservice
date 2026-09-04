-- Add ON DELETE CASCADE to foreign keys referencing profiles so users can be deleted cleanly

-- 1. jobs
alter table public.jobs
  drop constraint if exists jobs_customer_id_fkey,
  add constraint jobs_customer_id_fkey
    foreign key (customer_id) references public.profiles(id) on delete cascade;

alter table public.jobs
  drop constraint if exists jobs_selected_provider_id_fkey,
  add constraint jobs_selected_provider_id_fkey
    foreign key (selected_provider_id) references public.profiles(id) on delete set null;

-- 2. job_applications
alter table public.job_applications
  drop constraint if exists job_applications_provider_id_fkey,
  add constraint job_applications_provider_id_fkey
    foreign key (provider_id) references public.profiles(id) on delete cascade;

-- 3. price_agreements
alter table public.price_agreements
  drop constraint if exists price_agreements_customer_id_fkey,
  add constraint price_agreements_customer_id_fkey
    foreign key (customer_id) references public.profiles(id) on delete cascade;

alter table public.price_agreements
  drop constraint if exists price_agreements_provider_id_fkey,
  add constraint price_agreements_provider_id_fkey
    foreign key (provider_id) references public.profiles(id) on delete cascade;

-- 4. messages
alter table public.messages
  drop constraint if exists messages_sender_id_fkey,
  add constraint messages_sender_id_fkey
    foreign key (sender_id) references public.profiles(id) on delete cascade;

-- 5. locations
alter table public.locations
  drop constraint if exists locations_provider_id_fkey,
  add constraint locations_provider_id_fkey
    foreign key (provider_id) references public.profiles(id) on delete cascade;

-- 6. complaints
alter table public.complaints
  drop constraint if exists complaints_customer_id_fkey,
  add constraint complaints_customer_id_fkey
    foreign key (customer_id) references public.profiles(id) on delete cascade;

alter table public.complaints
  drop constraint if exists complaints_provider_id_fkey,
  add constraint complaints_provider_id_fkey
    foreign key (provider_id) references public.profiles(id) on delete cascade;

-- 7. reviews
alter table public.reviews
  drop constraint if exists reviews_customer_id_fkey,
  add constraint reviews_customer_id_fkey
    foreign key (customer_id) references public.profiles(id) on delete cascade;

alter table public.reviews
  drop constraint if exists reviews_provider_id_fkey,
  add constraint reviews_provider_id_fkey
    foreign key (provider_id) references public.profiles(id) on delete cascade;
