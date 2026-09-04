'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { Search, Eye, Filter } from 'lucide-react'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatDate } from '@/lib/utils'

interface JobItem {
  id: string
  title: string
  description: string
  status: string
  lat: number
  lng: number
  created_at: string
  service_categories: { name: string }[] | { name: string } | null
  customer_profile: { full_name: string; email: string; phone: string | null }[] | { full_name: string; email: string; phone: string | null } | null
  provider_profile: { full_name: string; email: string; phone: string | null }[] | { full_name: string; email: string; phone: string | null } | null
}

interface JobsClientProps {
  initialJobs: JobItem[]
}

export function JobsClient({ initialJobs }: JobsClientProps) {
  const [jobs] = useState<JobItem[]>(initialJobs)
  const [statusFilter, setStatusFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  const filteredJobs = jobs.filter((j) => {
    if (statusFilter !== 'all' && j.status.toLowerCase() !== statusFilter.toLowerCase()) {
      return false
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      const titleMatch = j.title.toLowerCase().includes(q)
      const descMatch = j.description.toLowerCase().includes(q)
      const custName = Array.isArray(j.customer_profile)
        ? j.customer_profile[0]?.full_name
        : j.customer_profile?.full_name
      const provName = Array.isArray(j.provider_profile)
        ? j.provider_profile[0]?.full_name
        : j.provider_profile?.full_name

      const custMatch = custName?.toLowerCase().includes(q) ?? false
      const provMatch = provName?.toLowerCase().includes(q) ?? false

      return titleMatch || descMatch || custMatch || provMatch
    }

    return true
  })

  return (
    <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
      {/* Control Filters */}
      <div className="p-4 border-b border-slate-200/80 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-50/50">
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-slate-400" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="text-xs bg-white border border-slate-200 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium text-slate-700"
          >
            <option value="all">Semua Status ({jobs.length})</option>
            <option value="open">Terbuka (Open)</option>
            <option value="locked">Tukang Terpilih (Locked)</option>
            <option value="in_progress">Sedang Dikerjakan (In Progress)</option>
            <option value="done">Selesai (Done)</option>
            <option value="paid">Lunas (Paid)</option>
            <option value="cancelled">Dibatalkan (Cancelled)</option>
          </select>
        </div>

        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
          <input
            type="text"
            placeholder="Cari judul, customer, tukang..."
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
              <th className="px-5 py-3">Permintaan Jasa</th>
              <th className="px-4 py-3">Kategori</th>
              <th className="px-4 py-3">Customer</th>
              <th className="px-4 py-3">Tukang Terpilih</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Waktu</th>
              <th className="px-5 py-3 text-right">Detail</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredJobs.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                  Tidak ada tiket pekerjaan yang sesuai filter
                </td>
              </tr>
            ) : (
              filteredJobs.map((j) => {
                const category = Array.isArray(j.service_categories)
                  ? j.service_categories[0]?.name
                  : j.service_categories?.name
                const customer = Array.isArray(j.customer_profile)
                  ? j.customer_profile[0]?.full_name
                  : j.customer_profile?.full_name
                const provider = Array.isArray(j.provider_profile)
                  ? j.provider_profile[0]?.full_name
                  : j.provider_profile?.full_name

                return (
                  <tr key={j.id} className="hover:bg-slate-50/70 transition-colors">
                    <td className="px-5 py-3.5 max-w-[240px]">
                      <p className="font-semibold text-slate-800 truncate">{j.title}</p>
                      <p className="text-[11px] text-slate-500 truncate">{j.description}</p>
                    </td>
                    <td className="px-4 py-3.5 text-slate-600 font-medium">
                      {category || 'Jasa Umum'}
                    </td>
                    <td className="px-4 py-3.5 text-slate-700">
                      {customer || 'Customer'}
                    </td>
                    <td className="px-4 py-3.5">
                      {provider ? (
                        <span className="font-medium text-slate-800">{provider}</span>
                      ) : (
                        <span className="text-slate-400 italic">Belum dipilih</span>
                      )}
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={j.status} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">{formatDate(j.created_at)}</td>
                    <td className="px-5 py-3.5 text-right">
                      <Link
                        href={`/jobs/${j.id}`}
                        className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700 hover:bg-slate-200 transition-colors"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Lihat</span>
                      </Link>
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
