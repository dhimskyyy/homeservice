import React from 'react'
import Link from 'next/link'
import {
  Users,
  Briefcase,
  CheckCircle,
  AlertTriangle,
  ArrowUpRight,
  Receipt,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { StatCard } from '@/components/ui/StatCard'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatRupiah, formatDate } from '@/lib/utils'

export const dynamic = 'force-dynamic'


export default async function DashboardPage() {
  const supabase = await createClient()

  // 1. Fetch Metriks Statistik
  const [
    customersCountRes,
    tukangsCountRes,
    activeJobsRes,
    paidAgreementsRes,
    openComplaintsRes,
    recentJobsRes,
    recentComplaintsRes,
  ] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('is_customer', true),
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('is_tukang', true),
    supabase.from('jobs').select('id', { count: 'exact', head: true }).eq('status', 'in_progress'),
    supabase.from('price_agreements').select('amount').eq('status', 'paid').eq('voided', false),
    supabase.from('complaints').select('id', { count: 'exact', head: true }).eq('status', 'open'),
    supabase
      .from('jobs')
      .select('id, title, status, created_at, customer_profile:customer_id(full_name), service_categories(name)')
      .order('created_at', { ascending: false })
      .limit(5),
    supabase
      .from('complaints')
      .select('id, reason, status, created_at, customer_profile:customer_id(full_name)')
      .eq('status', 'open')
      .order('created_at', { ascending: false })
      .limit(5),
  ])

  const totalCustomers = customersCountRes.count ?? 0
  const totalTukangs = tukangsCountRes.count ?? 0
  const activeJobsCount = activeJobsRes.count ?? 0
  const openComplaintsCount = openComplaintsRes.count ?? 0

  const totalPaidRevenue = (paidAgreementsRes.data ?? []).reduce(
    (acc, curr) => acc + (curr.amount || 0),
    0
  )
  const totalPaidTransactions = paidAgreementsRes.data?.length ?? 0

  const recentJobs = recentJobsRes.data ?? []
  const recentComplaints = recentComplaintsRes.data ?? []

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      {/* Page Title */}
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Ringkasan Operasional Platform
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Pantau aktivitas customer, mitra tukang, pengerjaan aktif, dan transaksi jasa Beres.
        </p>
      </div>

      {/* Metriks Stat Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total Customer"
          value={totalCustomers}
          icon={Users}
          colorScheme="blue"
          subtitle="Pengguna terdaftar"
        />
        <StatCard
          title="Mitra Tukang"
          value={totalTukangs}
          icon={Users}
          colorScheme="teal"
          subtitle="Penyedia jasa aktif"
        />
        <StatCard
          title="Pekerjaan Berjalan"
          value={activeJobsCount}
          icon={Briefcase}
          colorScheme="purple"
          subtitle="Status in_progress (live GPS)"
        />
        <StatCard
          title="Volume Nota Lunas"
          value={formatRupiah(totalPaidRevenue)}
          icon={Receipt}
          colorScheme="amber"
          subtitle={`${totalPaidTransactions} transaksi deal`}
        />
      </div>

      {/* Two Column Layout: Recent Jobs & Active Complaints */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Jobs (2 Cols) */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
          <div className="p-5 border-b border-slate-100 flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-slate-900 font-[family-name:var(--font-heading)]">
                Permintaan Jasa Terbaru
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">5 tiket permintaan jasa terkini</p>
            </div>
            <Link
              href="/jobs"
              className="text-xs font-semibold text-teal-700 hover:text-teal-800 flex items-center gap-1"
            >
              <span>Lihat Semua</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-500 border-b border-slate-200/60 uppercase font-semibold">
                <tr>
                  <th className="px-5 py-3">Judul Pekerjaan</th>
                  <th className="px-4 py-3">Kategori</th>
                  <th className="px-4 py-3">Customer</th>
                  <th className="px-4 py-3">Status</th>
                  <th className="px-4 py-3">Waktu</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {recentJobs.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-5 py-8 text-center text-slate-400">
                      Belum ada data permintaan jasa
                    </td>
                  </tr>
                ) : (
                  recentJobs.map((j) => {
                    const category = Array.isArray(j.service_categories)
                      ? j.service_categories[0]?.name
                      : (j.service_categories as { name?: string })?.name
                    const customer = Array.isArray(j.customer_profile)
                      ? j.customer_profile[0]?.full_name
                      : (j.customer_profile as { full_name?: string })?.full_name

                    return (
                      <tr key={j.id} className="hover:bg-slate-50/70 transition-colors">
                        <td className="px-5 py-3.5 font-medium text-slate-800 max-w-[200px] truncate">
                          <Link href={`/jobs/${j.id}`} className="hover:text-teal-700 hover:underline">
                            {j.title}
                          </Link>
                        </td>
                        <td className="px-4 py-3.5 text-slate-600">{category || '-'}</td>
                        <td className="px-4 py-3.5 text-slate-600">{customer || 'Customer'}</td>
                        <td className="px-4 py-3.5">
                          <StatusBadge status={j.status} />
                        </td>
                        <td className="px-4 py-3.5 text-slate-400">{formatDate(j.created_at)}</td>
                      </tr>
                    )
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Complaints Requiring Action (1 Col) */}
        <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden flex flex-col justify-between">
          <div>
            <div className="p-5 border-b border-slate-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-rose-600" />
                <h3 className="text-base font-bold text-slate-900 font-[family-name:var(--font-heading)]">
                  Komplain Perlu Tindakan
                </h3>
              </div>
              <span className="px-2 py-0.5 rounded-full bg-rose-100 text-rose-700 font-bold text-xs">
                {openComplaintsCount}
              </span>
            </div>

            <div className="p-4 divide-y divide-slate-100">
              {recentComplaints.length === 0 ? (
                <div className="py-8 text-center text-slate-400 text-xs">
                  <CheckCircle className="w-8 h-8 text-emerald-500 mx-auto mb-2 opacity-80" />
                  Semua komplain telah terselesaikan!
                </div>
              ) : (
                recentComplaints.map((c) => {
                  const customer = Array.isArray(c.customer_profile)
                    ? c.customer_profile[0]?.full_name
                    : (c.customer_profile as { full_name?: string })?.full_name

                  return (
                    <div key={c.id} className="py-3 first:pt-0 last:pb-0">
                      <div className="flex items-center justify-between text-xs mb-1">
                        <span className="font-semibold text-slate-800">{customer || 'Customer'}</span>
                        <span className="text-[10px] text-slate-400">{formatDate(c.created_at)}</span>
                      </div>
                      <p className="text-xs text-slate-600 line-clamp-2">{c.reason}</p>
                    </div>
                  )
                })
              )}
            </div>
          </div>

          <div className="p-4 border-t border-slate-100 bg-slate-50/50">
            <Link
              href="/complaints"
              className="w-full inline-flex items-center justify-center py-2 px-3 rounded-lg text-xs font-semibold bg-white border border-slate-200 text-slate-700 hover:bg-slate-100 transition-colors"
            >
              Buka Manajemen Komplain
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
