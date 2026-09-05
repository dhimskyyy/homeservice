import React from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import {
  ArrowLeft,
  User,
  Star,
  CheckCircle,
  AlertTriangle,
  CreditCard,
  MessageSquare,
  Wrench,
  Calendar,
  Mail,
  Phone,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/server'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatDate } from '@/lib/utils'

export const dynamic = 'force-dynamic'


interface PageProps {
  params: Promise<{ id: string }>
}

export default async function UserDetailPage({ params }: PageProps) {
  const { id } = await params
  const supabase = await createClient()

  // 1. Fetch Profile Tukang
  const { data: profile, error } = await supabase
    .from('profiles')
    .select(`
      *,
      tukang_profiles (
        bio,
        rating_avg,
        job_count,
        service_radius_km,
        service_type_ids,
        payment_methods,
        payment_details
      )
    `)
    .eq('id', id)
    .single()

  if (error || !profile) {
    notFound()
  }

  // 2. Fetch Reviews, Complaints, and Service Categories for this tukang
  const [reviewsRes, complaintsRes, categoriesRes] = await Promise.all([
    supabase
      .from('reviews')
      .select('*, customer:customer_id(full_name)')
      .eq('provider_id', id)
      .order('created_at', { ascending: false }),
    supabase
      .from('complaints')
      .select('*, customer:customer_id(full_name), jobs(title)')
      .eq('provider_id', id)
      .order('created_at', { ascending: false }),
    supabase.from('service_categories').select('id, name, slug'),
  ])

  const reviews = reviewsRes.data ?? []
  const complaints = complaintsRes.data ?? []
  const allCategories = categoriesRes.data ?? []

  const tukangData = Array.isArray(profile.tukang_profiles)
    ? profile.tukang_profiles[0]
    : profile.tukang_profiles

  // Hitung distribusi bintang 1-5
  const ratingCounts: { [key: number]: number } = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 }
  reviews.forEach((r) => {
    if (r.rating >= 1 && r.rating <= 5) {
      ratingCounts[r.rating] = (ratingCounts[r.rating] || 0) + 1
    }
  })
  const totalReviews = reviews.length

  // Filter kategori yang dilayani tukang
  const serviceIds = (tukangData?.service_type_ids as string[]) || []
  const myCategories = allCategories.filter((c) => serviceIds.includes(c.id))

  const paymentDetails = (tukangData?.payment_details as Record<string, unknown>) || {}
  const ewallets = (paymentDetails.ewallet as Record<string, string>) || {}
  const banks = (paymentDetails.bank_transfer as Record<string, string>) || {}

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header Back Button */}
      <div className="flex items-center gap-3">
        <Link
          href="/users"
          className="p-2 rounded-lg bg-white border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
        </Link>
        <div>
          <h2 className="text-xl font-bold text-slate-900 font-[family-name:var(--font-heading)]">
            Detail Profil Mitra Tukang
          </h2>
          <p className="text-xs text-slate-500">ID: {profile.id}</p>
        </div>
      </div>

      {/* Main Profile Info Card */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-2xs p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-6 pb-6 border-b border-slate-100">
          <div className="flex items-center gap-4">
            {profile.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={profile.avatar_url}
                alt={profile.full_name}
                className="w-16 h-16 rounded-full object-cover border-2 border-slate-200 shadow-xs"
              />
            ) : (
              <div className="w-16 h-16 rounded-full bg-teal-50 border border-teal-200 text-teal-800 flex items-center justify-center font-bold text-xl shadow-xs">
                {profile.full_name ? profile.full_name[0].toUpperCase() : <User className="w-8 h-8" />}
              </div>
            )}
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold text-slate-900 font-[family-name:var(--font-heading)]">
                  {profile.full_name || 'Mitra Tukang'}
                </h1>
                <StatusBadge status={profile.is_suspended ? 'suspended' : 'active'} />
              </div>
              <div className="flex items-center gap-4 text-xs text-slate-500 mt-1 flex-wrap">
                <span className="flex items-center gap-1 font-mono">
                  <Mail className="w-3.5 h-3.5 text-slate-400" />
                  {profile.email}
                </span>
                <span className="flex items-center gap-1 font-mono">
                  <Phone className="w-3.5 h-3.5 text-slate-400" />
                  {profile.phone || 'Belum diisi'}
                </span>
                <span className="flex items-center gap-1 text-slate-400">
                  <Calendar className="w-3.5 h-3.5" />
                  Bergabung {formatDate(profile.created_at)}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span
              className={`px-3 py-1 rounded-full text-xs font-semibold flex items-center gap-1.5 ${
                profile.is_online
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                  : 'bg-slate-100 text-slate-500 border border-slate-200'
              }`}
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  profile.is_online ? 'bg-emerald-500 animate-pulse' : 'bg-slate-400'
                }`}
              />
              <span>{profile.is_online ? 'Siap Kerja (Online)' : 'Sedang Offline'}</span>
            </span>
          </div>
        </div>

        {/* Bio & Summary */}
        <div className="pt-4">
          <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
            Bio & Keahlian Tukang
          </p>
          <p className="text-sm text-slate-700 bg-slate-50 p-3.5 rounded-xl border border-slate-100 leading-relaxed">
            {tukangData?.bio || 'Tukang belum mengisi bio profil.'}
          </p>
        </div>
      </div>

      {/* Grid: Rating Breakdown & Layanan / Pembayaran */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Rating Breakdown Bintang 1-5 */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-2xs p-6 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100">
            <div className="flex items-center gap-2">
              <Star className="w-5 h-5 text-amber-500 fill-amber-400" />
              <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
                Statistik Rating & Kepuasan
              </h3>
            </div>
            <span className="text-xs text-slate-400">{totalReviews} total ulasan</span>
          </div>

          <div className="flex items-center gap-6">
            <div className="text-center p-3 bg-amber-50/60 border border-amber-200/80 rounded-xl min-w-[100px]">
              <span className="text-3xl font-extrabold text-amber-900 font-[family-name:var(--font-heading)]">
                {tukangData?.rating_avg?.toFixed(1) || '0.0'}
              </span>
              <div className="flex justify-center text-amber-400 mt-0.5">
                {[...Array(5)].map((_, i) => (
                  <Star
                    key={i}
                    className={`w-3.5 h-3.5 ${
                      i < Math.round(tukangData?.rating_avg || 0)
                        ? 'fill-amber-400 text-amber-400'
                        : 'text-slate-200'
                    }`}
                  />
                ))}
              </div>
              <p className="text-[10px] text-slate-500 mt-1">Rata-rata rating</p>
            </div>

            {/* Bars 5 to 1 */}
            <div className="flex-1 space-y-1.5 text-xs">
              {[5, 4, 3, 2, 1].map((stars) => {
                const count = ratingCounts[stars] || 0
                const percent = totalReviews > 0 ? (count / totalReviews) * 100 : 0

                return (
                  <div key={stars} className="flex items-center gap-2">
                    <span className="w-7 font-medium text-slate-600 flex items-center gap-0.5">
                      {stars} <Star className="w-3 h-3 fill-amber-400 text-amber-400 inline" />
                    </span>
                    <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-amber-400 rounded-full transition-all duration-500"
                        style={{ width: `${percent}%` }}
                      />
                    </div>
                    <span className="w-8 text-right font-mono text-slate-400 text-[11px]">
                      {count}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
            <span>Pekerjaan Selesai (Job Count):</span>
            <span className="font-bold text-slate-900">{tukangData?.job_count ?? 0} Pekerjaan</span>
          </div>
          <div className="flex items-center justify-between text-xs text-slate-500">
            <span>Radius Jangkauan Pesanan:</span>
            <span className="font-bold text-slate-900">
              {(tukangData?.service_radius_km ?? 0) > 0
                ? `${tukangData.service_radius_km} km`
                : 'Nonaktif'}
            </span>
          </div>
        </div>

        {/* Keahlian & Rekening Pembayaran */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-2xs p-6 space-y-4">
          <div className="flex items-center gap-2 pb-3 border-b border-slate-100">
            <CreditCard className="w-5 h-5 text-teal-600" />
            <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
              Keahlian Jasa & Pembayaran
            </h3>
          </div>

          <div>
            <p className="text-xs font-semibold text-slate-500 mb-2 flex items-center gap-1.5">
              <Wrench className="w-3.5 h-3.5 text-slate-400" />
              Layanan yang Dilayani ({myCategories.length}):
            </p>
            <div className="flex flex-wrap gap-1.5">
              {myCategories.length === 0 ? (
                <span className="text-xs text-slate-400 italic">Belum memilih kategori</span>
              ) : (
                myCategories.map((c) => (
                  <span
                    key={c.id}
                    className="px-2.5 py-1 bg-teal-50 border border-teal-200 text-teal-800 rounded-lg text-xs font-semibold"
                  >
                    {c.name}
                  </span>
                ))
              )}
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100 space-y-2">
            <p className="text-xs font-semibold text-slate-500">Rekening & E-Wallet Tukang:</p>
            {/* E-Wallets */}
            {Object.keys(ewallets).length > 0 && (
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 text-xs space-y-1">
                <span className="font-bold text-slate-700 uppercase tracking-wide text-[10px]">
                  E-Wallet:
                </span>
                {Object.entries(ewallets).map(([name, num]) => (
                  <p key={name} className="flex justify-between font-mono">
                    <span className="text-slate-600 uppercase font-semibold">{name}:</span>
                    <span className="text-slate-900 font-bold">{num}</span>
                  </p>
                ))}
              </div>
            )}

            {/* Banks */}
            {Object.keys(banks).length > 0 && (
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 text-xs space-y-1">
                <span className="font-bold text-slate-700 uppercase tracking-wide text-[10px]">
                  Transfer Bank:
                </span>
                {Object.entries(banks).map(([name, num]) => (
                  <p key={name} className="flex justify-between font-mono">
                    <span className="text-slate-600 uppercase font-semibold">Bank {name}:</span>
                    <span className="text-slate-900 font-bold">{num}</span>
                  </p>
                ))}
              </div>
            )}

            {Object.keys(ewallets).length === 0 && Object.keys(banks).length === 0 && (
              <p className="text-xs text-slate-400 italic">Hanya menerima pembayaran tunai (Cash)</p>
            )}
          </div>
        </div>
      </div>

      {/* Komplain yang Pernah Dilaporkan Terhadap Tukang Ini */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-2xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-rose-600" />
            <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
              Riwayat Komplain Pelanggan ({complaints.length})
            </h3>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 text-slate-500 uppercase font-semibold border-b border-slate-100">
              <tr>
                <th className="px-5 py-3">Tiket Pekerjaan</th>
                <th className="px-4 py-3">Customer Pelapor</th>
                <th className="px-5 py-3">Isi Komplain</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Waktu</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {complaints.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-slate-400">
                    <CheckCircle className="w-6 h-6 text-emerald-500 mx-auto mb-1 opacity-80" />
                    Tukang ini tidak memiliki riwayat komplain dari pelanggan
                  </td>
                </tr>
              ) : (
                complaints.map((c) => (
                  <tr key={c.id} className="hover:bg-slate-50/70">
                    <td className="px-5 py-3.5 font-medium text-slate-800">
                      {c.jobs?.title || 'Pekerjaan'}
                    </td>
                    <td className="px-4 py-3.5 text-slate-700">{c.customer?.full_name || 'Customer'}</td>
                    <td className="px-5 py-3.5 text-slate-700 max-w-[280px]">
                      <p className="leading-relaxed">{c.reason}</p>
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={c.status} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">{formatDate(c.created_at)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Ulasan & Komentar Customer */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-2xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center gap-2">
          <MessageSquare className="w-5 h-5 text-teal-600" />
          <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
            Ulasan & Komentar Pelanggan ({reviews.length})
          </h3>
        </div>

        <div className="divide-y divide-slate-100">
          {reviews.length === 0 ? (
            <p className="p-8 text-center text-xs text-slate-400">
              Belum ada ulasan yang masuk untuk tukang ini
            </p>
          ) : (
            reviews.map((r) => (
              <div key={r.id} className="p-4 sm:px-6 hover:bg-slate-50/50 transition-colors">
                <div className="flex items-center justify-between text-xs mb-1.5">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-slate-800">{r.customer?.full_name || 'Customer'}</span>
                    <span className="flex items-center text-amber-500 font-bold bg-amber-50 px-2 py-0.5 rounded-sm border border-amber-200/60">
                      ★ {r.rating}
                    </span>
                  </div>
                  <span className="text-slate-400 text-[11px]">{formatDate(r.created_at)}</span>
                </div>
                <p className="text-xs text-slate-600 italic">
                  {r.comment ? `"${r.comment}"` : 'Tidak ada ulasan tertulis.'}
                </p>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
