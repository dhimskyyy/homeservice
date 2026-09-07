-- ============================================================
-- Migration 20260903000024: Supabase Webhook http_request Function
-- ============================================================

create or replace function supabase_functions.http_request()
returns trigger
language plpgsql
security definer
set search_path = extensions, public
as $$
declare
  request_id bigint;
  payload jsonb;
  url text := TG_ARGV[0];
  method text := TG_ARGV[1];
  headers jsonb := TG_ARGV[2]::jsonb;
  params jsonb := TG_ARGV[3]::jsonb;
  timeout_ms integer := TG_ARGV[4]::integer;
begin
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', case when TG_OP = 'DELETE' then null else row_to_json(NEW)::jsonb end,
    'old_record', case when TG_OP = 'INSERT' then null else row_to_json(OLD)::jsonb end
  );

  select net.http_post(
    url := url,
    body := payload,
    headers := headers,
    timeout_milliseconds := timeout_ms
  ) into request_id;

  return null;
end;
$$;

grant execute on function supabase_functions.http_request() to postgres, anon, authenticated, service_role;
