-- ============================================================
-- Migration 20260903000023: Enable pg_net & webhook support
-- ============================================================

create extension if not exists "pg_net" with schema "extensions";

create schema if not exists supabase_functions;
grant usage on schema supabase_functions to postgres, authenticated, service_role;
grant all on all tables in schema supabase_functions to postgres, authenticated, service_role;
grant all on all routines in schema supabase_functions to postgres, authenticated, service_role;
grant all on all sequences in schema supabase_functions to postgres, authenticated, service_role;
