'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { CheckCircle2, Search, Filter } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatDate } from '@/lib/utils'

interface ComplaintItem {
  id: string
  reason: string
  status: string
  created_at: string
  resolved_at: string | null
  jobs: { id: string; title: string }[] | { id: string; title: string } | null
  customer_profile: { full_name: string }[] | { full_name: string } | null
  provider_profile: { full_name: string }[] | { full_name: string } | null
}

interface ComplaintsClientProps {
  initialComplaints: ComplaintItem[]
}

export function ComplaintsClient({ initialComplaints }: ComplaintsClientProps) {
  const [complaints, setComplaints] = useState<ComplaintItem[]>(initialComplaints)
  const [statusFilter, setStatusFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [resolvingId, setResolvingId] = useState<string | null>(null)

  async function handleResolve(id: string) {
    if (!confirm('Apakah Anda yakin ingin menyelesaikan komplain ini?')) return

    setResolvingId(id)
    try {
      const supabase = createClient()
      const { error } = await supabase
        .from('complaints')
        .update({
          status: 'resolved',
          resolved_at: new Date().toISOString(),
        })
        .eq('id', id)

      if (error) throw error

      setComplaints((prev) =>
        prev.map((c) =>
          c.id === id
            ? { ...c, status: 'resolved', resolved_at: new Date().toISOString() }
            : c
        )
      )
    } catch (err: unknown) {
      alert(`Gagal menyelesaikan komplain: ${err instanceof Error ? err.message : 'Kesalahan jaringan'}`)
    } finally {
      setResolvingId(null)
    }
  }

  const filtered = complaints.filter((c) => {
    if (statusFilter !== 'all' && c.status.toLowerCase() !== statusFilter.toLowerCase()) {
      return false
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      const reasonMatch = c.reason.toLowerCase().includes(q)
      const job = Array.isArray(c.jobs) ? c.jobs[0] : c.jobs
      const jobMatch = job?.title.toLowerCase().includes(q) ?? false
      return reasonMatch || jobMatch
    }

    return true
  })

  return (
    <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
      {/* Filters */}
      <div className="p-4 border-b border-slate-200/80 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-50/50">
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-slate-400" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="text-xs bg-white border border-slate-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium text-slate-700"
          >
            <option value="all">Semua Status ({complaints.length})</option>
            <option value="open">Sedang Ditinjau (Open)</option>
            <option value="resolved">Terselesaikan (Resolved)</option>
          </select>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
          <input
            type="text"
            placeholder="Cari alasan, judul job..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 text-slate-500 border-b border-slate-200/60 uppercase font-semibold">
            <tr>
              <th className="px-5 py-3">Tiket Pekerjaan</th>
              <th className="px-4 py-3">Customer Pelapor</th>
              <th className="px-4 py-3">Tukang Terlapor</th>
              <th className="px-5 py-3">Alasan Komplain</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Waktu Lapor</th>
              <th className="px-5 py-3 text-right">Tindakan</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                  Tidak ada komplain yang sesuai filter
                </td>
              </tr>
            ) : (
              filtered.map((c) => {
                const job = Array.isArray(c.jobs) ? c.jobs[0] : c.jobs
                const customer = Array.isArray(c.customer_profile)
                  ? c.customer_profile[0]?.full_name
                  : c.customer_profile?.full_name
                const provider = Array.isArray(c.provider_profile)
                  ? c.provider_profile[0]?.full_name
                  : c.provider_profile?.full_name

                return (
                  <tr key={c.id} className="hover:bg-slate-50/70 transition-colors">
                    <td className="px-5 py-3.5 font-semibold text-slate-800 max-w-[180px]">
                      {job ? (
                        <Link href={`/jobs/${job.id}`} className="hover:text-teal-700 truncate block hover:underline">
                          {job.title}
                        </Link>
                      ) : (
                        '-'
                      )}
                    </td>
                    <td className="px-4 py-3.5 text-slate-700">{customer || 'Customer'}</td>
                    <td className="px-4 py-3.5 font-medium text-slate-800">{provider || 'Tukang'}</td>
                    <td className="px-5 py-3.5 text-slate-700 max-w-[260px]">
                      <p className="whitespace-pre-wrap leading-relaxed">{c.reason}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={c.status} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">{formatDate(c.created_at)}</td>
                    <td className="px-5 py-3.5 text-right">
                      {c.status === 'open' ? (
                        <button
                          onClick={() => handleResolve(c.id)}
                          disabled={resolvingId === c.id}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs transition-colors cursor-pointer disabled:opacity-50"
                        >
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>{resolvingId === c.id ? 'Memproses...' : 'Selesaikan'}</span>
                        </button>
                      ) : (
                        <span className="text-slate-400 text-[11px] italic">
                          Selesai ({formatDate(c.resolved_at)})
                        </span>
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
  )
}
