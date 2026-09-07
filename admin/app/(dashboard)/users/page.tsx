import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { UsersClient } from './UsersClient'
import { Pagination } from '@/components/ui/Pagination'

export const dynamic = 'force-dynamic'

interface PageProps {
  searchParams: Promise<{ page?: string; tab?: string; q?: string }>
}

const PAGE_SIZE = 15

export default async function UsersPage({ searchParams }: PageProps) {
  const params = await searchParams
  const currentPage = Math.max(1, parseInt(params.page || '1', 10))
  const from = (currentPage - 1) * PAGE_SIZE
  const to = from + PAGE_SIZE - 1

  const supabase = await createClient()

  // Count total profiles
  const { count: totalUsers } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })

  // Fetch paginated profiles
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
    .range(from, to)

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data pengguna: {error.message}
      </div>
    )
  }

  const total = totalUsers ?? 0
  const totalPages = Math.ceil(total / PAGE_SIZE)

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

      <div className="space-y-4">
        <UsersClient initialUsers={users || []} />
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={total}
          pageSize={PAGE_SIZE}
          baseUrl="/users"
          searchParams={{ page: params.page }}
        />
      </div>
    </div>
  )
}
