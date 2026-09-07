import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { ComplaintsClient } from './ComplaintsClient'
import { Pagination } from '@/components/ui/Pagination'

export const dynamic = 'force-dynamic'

interface PageProps {
  searchParams: Promise<{ page?: string; status?: string; q?: string }>
}

const PAGE_SIZE = 15

export default async function ComplaintsPage({ searchParams }: PageProps) {
  const params = await searchParams
  const currentPage = Math.max(1, parseInt(params.page || '1', 10))
  const from = (currentPage - 1) * PAGE_SIZE
  const to = from + PAGE_SIZE - 1

  const supabase = await createClient()

  const { count: totalComplaints } = await supabase
    .from('complaints')
    .select('id', { count: 'exact', head: true })

  const { data: complaints, error } = await supabase
    .from('complaints')
    .select(`
      id,
      reason,
      status,
      created_at,
      resolved_at,
      jobs (id, title),
      customer_profile:customer_id (full_name),
      provider_profile:provider_id (full_name)
    `)
    .order('created_at', { ascending: false })
    .range(from, to)

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data komplain: {error.message}
      </div>
    )
  }

  const total = totalComplaints ?? 0
  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Manajemen & Penyelesaian Komplain
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Tinjau aduan kendala dari customer terhadap mitra tukang dan selesaikan masalah layanan.
        </p>
      </div>

      <div className="space-y-4">
        <ComplaintsClient initialComplaints={complaints ?? []} />
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={total}
          pageSize={PAGE_SIZE}
          baseUrl="/complaints"
          searchParams={{ page: params.page }}
        />
      </div>
    </div>
  )
}
