import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { JobsClient } from './JobsClient'

export default async function JobsPage() {
  const supabase = await createClient()

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

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data pekerjaan: {error.message}
      </div>
    )
  }

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

      <JobsClient initialJobs={jobs || []} />
    </div>
  )
}
