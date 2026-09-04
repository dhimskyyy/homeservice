import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { ComplaintsClient } from './ComplaintsClient'

export default async function ComplaintsPage() {
  const supabase = await createClient()

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

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data komplain: {error.message}
      </div>
    )
  }

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

      <ComplaintsClient initialComplaints={complaints ?? []} />
    </div>
  )
}
