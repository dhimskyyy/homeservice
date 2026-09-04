import { createBrowserClient } from '@supabase/ssr'

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  'https://vouqqkeiemasqyiywzsr.supabase.co'

const SUPABASE_ANON_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdXFxa2VpZW1hc3F5aXl3enNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NTg3MDAsImV4cCI6MjEwNDAzNDcwMH0._zdF5JUBtsGJu-YlBBC2fmN83o_1xPzQhLZG0UreUT0'

export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY)
}
