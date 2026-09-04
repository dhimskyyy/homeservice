import React from 'react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatRupiah, formatDate } from '@/lib/utils'

interface AgreementRecord {
  id: string
  amount: number
  payment_method: string
  status: string
  voided: boolean
  created_at: string
  paid_at: string | null
  jobs: { id: string; title: string }[] | { id: string; title: string } | null
  customer_profile: { full_name: string }[] | { full_name: string } | null
  provider_profile: { full_name: string }[] | { full_name: string } | null
}

export default async function AgreementsPage() {
  const supabase = await createClient()

  const { data: agreements, error } = await supabase
    .from('price_agreements')
    .select(`
      id,
      amount,
      payment_method,
      status,
      voided,
      created_at,
      paid_at,
      jobs (id, title),
      customer_profile:customer_id (full_name),
      provider_profile:provider_id (full_name)
    `)
    .order('created_at', { ascending: false })

  if (error) {
    return (
      <div className="p-8 text-center text-rose-600 bg-white rounded-xl border border-rose-200">
        Gagal memuat data nota: {error.message}
      </div>
    )
  }

  const list = agreements ?? []

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Pemantauan Nota Kesepakatan (Price Agreements)
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Daftar seluruh nota harga yang diterbitkan oleh mitra tukang dan status pembayarannya.
        </p>
      </div>

      <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 text-slate-500 border-b border-slate-200/60 uppercase font-semibold">
              <tr>
                <th className="px-5 py-3">Pekerjaan</th>
                <th className="px-4 py-3">Customer</th>
                <th className="px-4 py-3">Tukang</th>
                <th className="px-4 py-3">Nominal Kesepakatan</th>
                <th className="px-4 py-3">Metode</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Waktu Terbit</th>
                <th className="px-4 py-3">Waktu Bayar</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {list.length === 0 ? (
                <tr>
                  <td colSpan={8} className="px-5 py-12 text-center text-slate-400">
                    Belum ada data nota kesepakatan harga
                  </td>
                </tr>
              ) : (
                list.map((item) => {
                  const a = item as unknown as AgreementRecord
                  const job = Array.isArray(a.jobs) ? a.jobs[0] : a.jobs
                  const customer = Array.isArray(a.customer_profile)
                    ? a.customer_profile[0]?.full_name
                    : a.customer_profile?.full_name
                  const provider = Array.isArray(a.provider_profile)
                    ? a.provider_profile[0]?.full_name
                    : a.provider_profile?.full_name

                  return (
                    <tr key={a.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="px-5 py-3.5 max-w-[200px]">
                        {job ? (
                          <Link href={`/jobs/${job.id}`} className="font-semibold text-slate-800 hover:text-teal-700 truncate block">
                            {job.title}
                          </Link>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                      <td className="px-4 py-3.5 text-slate-700">{customer || 'Customer'}</td>
                      <td className="px-4 py-3.5 font-medium text-slate-800">{provider || 'Tukang'}</td>
                      <td className="px-4 py-3.5 font-bold text-slate-900 font-[family-name:var(--font-heading)]">
                        <span className={a.voided ? 'line-through text-slate-400' : ''}>
                          {formatRupiah(a.amount)}
                        </span>
                        {a.voided && (
                          <span className="ml-2 px-1.5 py-0.5 rounded-sm bg-slate-100 text-slate-500 text-[10px]">
                            Batal
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3.5 text-slate-600 uppercase font-mono">{a.payment_method}</td>
                      <td className="px-4 py-3.5">
                        <StatusBadge status={a.status} />
                      </td>
                      <td className="px-4 py-3.5 text-slate-400">{formatDate(a.created_at)}</td>
                      <td className="px-4 py-3.5 text-slate-500 font-medium">
                        {a.paid_at ? (
                          <span className="text-emerald-600">{formatDate(a.paid_at)}</span>
                        ) : (
                          <span className="text-slate-400">-</span>
                        )}
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
