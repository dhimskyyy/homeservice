import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { UsersClient } from './UsersClient'

export default async function UsersPage() {
  const supabase = await createClient()

  // Fetch all profiles
  const { data: users, error } = await supabase
    .from('profiles')
    .select(`
      id,
      email,
      full_name,
      phone,
      is_customer,
      is_tukang,
      is_admin,
      is_suspended,
      is_online,
      created_at,
      tukang_profiles (
        bio,
        rating_avg,
        job_count
      )
    `)
    .order('created_at', { ascending: false })

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data pengguna: {error.message}
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Manajemen Pengguna Platform
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Kelola akun pelanggan dan mitra tukang, pantau status operasional, serta suspend akun bermasalah.
        </p>
      </div>

      <UsersClient initialUsers={users || []} />
    </div>
  )
}
