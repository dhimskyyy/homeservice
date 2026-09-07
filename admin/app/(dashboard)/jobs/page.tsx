import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { JobsClient } from './JobsClient'
import { Pagination } from '@/components/ui/Pagination'

export const dynamic = 'force-dynamic'

interface PageProps {
  searchParams: Promise<{ page?: string; status?: string; q?: string }>
}

const PAGE_SIZE = 15

export default async function JobsPage({ searchParams }: PageProps) {
  const params = await searchParams
  const currentPage = Math.max(1, parseInt(params.page || '1', 10))
  const from = (currentPage - 1) * PAGE_SIZE
  const to = from + PAGE_SIZE - 1

  const supabase = await createClient()

  const { count: totalJobs } = await supabase
    .from('jobs')
    .select('id', { count: 'exact', head: true })

  const { data: jobs, error } = await supabase
    .from('jobs')
    .select(`
      id,
      title,
      description,
      status,
      lat,
      lng,
      created_at,
      service_categories (name),
      customer_profile:customer_id (full_name, email, phone),
      provider_profile:selected_provider_id (full_name, email, phone)
    `)
    .order('created_at', { ascending: false })
    .range(from, to)

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data pekerjaan: {error.message}
      </div>
    )
  }

  const total = totalJobs ?? 0
  const totalPages = Math.ceil(total / PAGE_SIZE)

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Pemantauan Tiket Permintaan Jasa
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Pantau seluruh alur permintaan jasa mulai dari tiket terbuka, pemilihan tukang, proses kerja live, hingga lunas.
        </p>
      </div>

      <div className="space-y-4">
        <JobsClient initialJobs={jobs || []} />
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={total}
          pageSize={PAGE_SIZE}
          baseUrl="/jobs"
          searchParams={{ page: params.page }}
        />
      </div>
    </div>
  )
}
