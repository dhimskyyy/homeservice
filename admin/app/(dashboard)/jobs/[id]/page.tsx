import React from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import {
  ArrowLeft,
  User,
  MapPin,
  Calendar,
  Receipt,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatRupiah, formatDate } from '@/lib/utils'

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function JobDetailPage({ params }: PageProps) {
  const { id } = await params
  const supabase = await createClient()

  // 1. Fetch Job Detail
  const { data: job, error } = await supabase
    .from('jobs')
    .select(`
      *,
      service_categories (name),
      customer_profile:customer_id (id, full_name, email, phone),
      provider_profile:selected_provider_id (id, full_name, email, phone)
    `)
    .eq('id', id)
    .single()

  if (error || !job) {
    notFound()
  }

  // 2. Fetch Applications & Agreements
  const [appsRes, agreementsRes] = await Promise.all([
    supabase
      .from('job_applications')
      .select('*, profiles:provider_id(full_name, email, phone), tukang_profiles!provider_id(bio, rating_avg)')
      .eq('job_id', id),
    supabase
      .from('price_agreements')
      .select('*, profiles:provider_id(full_name)')
      .eq('job_id', id),
  ])

  const applications = appsRes.data ?? []
  const agreements = agreementsRes.data ?? []

  const categoryName = Array.isArray(job.service_categories)
    ? job.service_categories[0]?.name
    : job.service_categories?.name

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Back Button & Header */}
      <div className="flex items-center gap-3">
        <Link
          href="/jobs"
          className="p-2 rounded-lg bg-white border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
        </Link>
        <div>
          <h2 className="text-xl font-bold text-slate-900 font-[family-name:var(--font-heading)]">
            Detail Tiket #{job.id.slice(0, 8)}
          </h2>
          <p className="text-xs text-slate-500">Dibuat pada {formatDate(job.created_at)}</p>
        </div>
      </div>

      {/* Main Job Card */}
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs p-6 space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-6 border-b border-slate-100">
          <div>
            <div className="inline-block px-2.5 py-0.5 rounded-md bg-teal-50 text-teal-800 font-semibold text-xs mb-2">
              {categoryName || 'Jasa Rumah'}
            </div>
            <h1 className="text-xl font-bold text-slate-900 font-[family-name:var(--font-heading)]">
              {job.title}
            </h1>
          </div>
          <div className="flex items-center gap-3">
            <StatusBadge status={job.status} className="text-xs px-3 py-1 font-bold" />
          </div>
        </div>

        {/* Description */}
        <div>
          <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
            Deskripsi Kebutuhan Customer
          </h4>
          <p className="text-sm text-slate-700 bg-slate-50/80 p-4 rounded-xl border border-slate-100 whitespace-pre-wrap leading-relaxed">
            {job.description}
          </p>
        </div>

        {/* Location & Metadata */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs pt-2">
          <div className="p-3.5 rounded-xl border border-slate-100 bg-slate-50 flex items-center gap-3">
            <MapPin className="w-5 h-5 text-teal-600 shrink-0" />
            <div>
              <p className="text-slate-400 font-medium">Titik Lokasi Layanan (GPS)</p>
              <p className="font-mono text-slate-800 font-semibold mt-0.5">
                {job.lat.toFixed(5)}, {job.lng.toFixed(5)}
              </p>
            </div>
          </div>
          <div className="p-3.5 rounded-xl border border-slate-100 bg-slate-50 flex items-center gap-3">
            <Calendar className="w-5 h-5 text-teal-600 shrink-0" />
            <div>
              <p className="text-slate-400 font-medium">Pembaruan Terakhir</p>
              <p className="text-slate-800 font-semibold mt-0.5">
                {formatDate(job.updated_at)}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Two Column: Parties Involved */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
        {/* Customer Info */}
        <div className="bg-white rounded-xl border border-slate-200/80 p-5 shadow-2xs">
          <div className="flex items-center gap-2 mb-4 pb-3 border-b border-slate-100">
            <User className="w-4 h-4 text-blue-600" />
            <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
              Customer Pemilik Job
            </h3>
          </div>
          {job.customer_profile ? (
            <div className="space-y-2 text-xs">
              <p>
                <span className="text-slate-400">Nama:</span>{' '}
                <span className="font-bold text-slate-800">{job.customer_profile.full_name}</span>
              </p>
              <p>
                <span className="text-slate-400">Email:</span>{' '}
                <span className="text-slate-700 font-mono">{job.customer_profile.email}</span>
              </p>
              <p>
                <span className="text-slate-400">Telepon:</span>{' '}
                <span className="text-slate-700 font-mono">{job.customer_profile.phone || '-'}</span>
              </p>
            </div>
          ) : (
            <p className="text-xs text-slate-400 italic">Data profil tidak ditemukan</p>
          )}
        </div>

        {/* Selected Provider Info */}
        <div className="bg-white rounded-xl border border-slate-200/80 p-5 shadow-2xs">
          <div className="flex items-center gap-2 mb-4 pb-3 border-b border-slate-100">
            <User className="w-4 h-4 text-amber-600" />
            <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
              Tukang Terpilih (Locked)
            </h3>
          </div>
          {job.provider_profile ? (
            <div className="space-y-2 text-xs">
              <p>
                <span className="text-slate-400">Nama:</span>{' '}
                <span className="font-bold text-slate-800">{job.provider_profile.full_name}</span>
              </p>
              <p>
                <span className="text-slate-400">Email:</span>{' '}
                <span className="text-slate-700 font-mono">{job.provider_profile.email}</span>
              </p>
              <p>
                <span className="text-slate-400">Telepon:</span>{' '}
                <span className="text-slate-700 font-mono">{job.provider_profile.phone || '-'}</span>
              </p>
            </div>
          ) : (
            <p className="text-xs text-slate-400 italic">Customer belum memilih tukang</p>
          )}
        </div>
      </div>

      {/* Nota / Price Agreements */}
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center gap-2">
          <Receipt className="w-4 h-4 text-teal-600" />
          <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
            Nota Kesepakatan Harga (Price Agreement)
          </h3>
        </div>
        <div className="p-5">
          {agreements.length === 0 ? (
            <p className="text-xs text-slate-400 text-center py-4">
              Belum ada nota kesepakatan harga yang dibuat untuk tiket ini
            </p>
          ) : (
            <div className="space-y-3">
              {agreements.map((a) => (
                <div
                  key={a.id}
                  className={`p-4 rounded-xl border text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
                    a.voided
                      ? 'bg-slate-50 border-slate-200 opacity-60'
                      : 'bg-amber-50/50 border-amber-200'
                  }`}
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
                        {formatRupiah(a.amount)}
                      </span>
                      {a.voided && (
                        <span className="px-1.5 py-0.5 rounded-sm bg-slate-200 text-slate-600 text-[10px] font-bold">
                          Void / Batal
                        </span>
                      )}
                    </div>
                    <p className="text-slate-500 mt-1">
                      Metode: <span className="font-semibold text-slate-700 uppercase">{a.payment_method}</span> • Dibuat oleh:{' '}
                      <span className="font-medium text-slate-800">{a.profiles?.full_name || 'Tukang'}</span>
                    </p>
                  </div>
                  <div className="text-right">
                    <StatusBadge status={a.status} />
                    {a.paid_at && (
                      <p className="text-[10px] text-emerald-600 mt-1 font-medium">
                        Lunas pada: {formatDate(a.paid_at)}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Applications (Tukang yang Merespon) */}
      <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
        <div className="p-5 border-b border-slate-100">
          <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
            Tukang yang Merespon ({applications.length})
          </h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 text-slate-500 uppercase font-semibold">
              <tr>
                <th className="px-5 py-3">Nama Tukang</th>
                <th className="px-4 py-3">Rating</th>
                <th className="px-4 py-3">Bio Singkat</th>
                <th className="px-4 py-3">Status Aplikasi</th>
                <th className="px-4 py-3">Waktu Respond</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {applications.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-slate-400">
                    Belum ada tukang yang merespon pekerjaan ini
                  </td>
                </tr>
              ) : (
                applications.map((app) => (
                  <tr key={app.id} className="hover:bg-slate-50/70">
                    <td className="px-5 py-3 font-semibold text-slate-800">
                      {app.profiles?.full_name || 'Mitra Tukang'}
                    </td>
                    <td className="px-4 py-3 text-amber-600 font-bold">
                      ★ {app.tukang_profiles?.rating_avg?.toFixed(1) || '0.0'}
                    </td>
                    <td className="px-4 py-3 text-slate-600 max-w-[200px] truncate">
                      {app.tukang_profiles?.bio || '-'}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                          app.status === 'selected'
                            ? 'bg-emerald-100 text-emerald-800'
                            : app.status === 'locked_out'
                            ? 'bg-slate-100 text-slate-500'
                            : 'bg-blue-100 text-blue-800'
                        }`}
                      >
                        {app.status}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-400">{formatDate(app.created_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
