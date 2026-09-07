-- ============================================================
-- Migration 20260903000022: Webhook Trigger for Push Notifications
-- ============================================================

-- Trigger otomatis ke Edge Function send-push-notification via pg_net jika tersedia,
-- atau disiapkan hook publik yang dipanggil otomatis.
create or replace function internal.trigger_push_on_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Trigger push notification di-handle via Supabase Webhook / Database Webhook
  -- yang dikonfigurasi pada tabel app_notifications event INSERT.
  return new;
end;
$$;
