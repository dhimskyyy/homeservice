-- Seed data for Beres

insert into public.service_categories (name, slug, icon, sort_order) values
  ('AC', 'ac', 'ac_unit', 1),
  ('Cleaning', 'cleaning', 'cleaning_services', 2),
  ('Plumbing', 'plumbing', 'plumbing', 3),
  ('Listrik', 'listrik', 'electric_bolt', 4),
  ('Handyman', 'handyman', 'build', 5);

-- Example tukang and customer profiles can be added later via script.