'use client'

import React, { useState, useEffect } from 'react'
import dynamic from 'next/dynamic'
import {
  MapPin,
  RefreshCw,
  Search,
  User,
  Radio,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { TukangTrackItem } from '@/components/map/TrackingMap'

const TrackingMap = dynamic(() => import('@/components/map/TrackingMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-[580px] bg-slate-100 flex items-center justify-center text-xs text-slate-400">
      Memuat peta Leaflet & OpenStreetMap...
    </div>
  ),
})

interface TrackingClientProps {
  initialTukangs: TukangTrackItem[]
}

export function TrackingClient({ initialTukangs }: TrackingClientProps) {
  const [tukangs, setTukangs] = useState<TukangTrackItem[]>(initialTukangs)
  const [selectedTukangId, setSelectedTukangId] = useState<string | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  const [filterStatus, setFilterStatus] = useState<'all' | 'working' | 'online' | 'offline'>('all')
  const [isRefreshing, setIsRefreshing] = useState(false)

  // Realtime subscription untuk locations dan profiles
  useEffect(() => {
    const supabase = createClient()

    // 1. Dengarkan pergerakan GPS live di tabel locations
    const locChannel = supabase
      .channel('admin-realtime-locations')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'locations' },
        (payload) => {
          const newLoc = payload.new as { provider_id: string; lat: number; lng: number }
          setTukangs((prev) =>
            prev.map((t) =>
              t.id === newLoc.provider_id
                ? { ...t, lat: newLoc.lat, lng: newLoc.lng }
                : t
            )
          )
        }
      )
      .subscribe()

    // 2. Dengarkan perubahan status online/offline di tabel profiles
    const profChannel = supabase
      .channel('admin-realtime-profiles')
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'profiles' },
        (payload) => {
          const updated = payload.new as { id: string; is_online: boolean; is_suspended: boolean }
          setTukangs((prev) =>
            prev.map((t) => {
              if (t.id === updated.id) {
                const newStatus: 'working' | 'online' | 'offline' =
                  t.status === 'working'
                    ? 'working'
                    : updated.is_online && !updated.is_suspended
                    ? 'online'
                    : 'offline'
                return {
                  ...t,
                  is_online: updated.is_online,
                  is_suspended: updated.is_suspended,
                  status: newStatus,
                }
              }
              return t
            })
          )
        }
      )
      .subscribe()

    return () => {
      locChannel.unsubscribe()
      profChannel.unsubscribe()
    }
  }, [])

  async function handleRefresh() {
    setIsRefreshing(true)
    try {
      const supabase = createClient()
      const [profilesRes, jobsRes, locsRes] = await Promise.all([
        supabase
          .from('profiles')
          .select('id, full_name, email, avatar_url, is_online, is_suspended, lat, lng')
          .eq('is_tukang', true)
          .order('is_online', { ascending: false }),
        supabase.from('jobs').select('id, title, selected_provider_id, lat, lng').eq('status', 'in_progress'),
        supabase.from('locations').select('provider_id, lat, lng').order('created_at', { ascending: false }).limit(100),
      ])

      const latestGps: { [id: string]: { lat: number; lng: number } } = {}
      ;(locsRes.data ?? []).forEach((l) => {
        if (!latestGps[l.provider_id]) latestGps[l.provider_id] = { lat: l.lat, lng: l.lng }
      })

      const mapped = (profilesRes.data ?? []).map((t) => {
        const activeJob = (jobsRes.data ?? []).find((j) => j.selected_provider_id === t.id)
        let s: 'working' | 'online' | 'offline' = 'offline'
        if (activeJob) s = 'working'
        else if (t.is_online && !t.is_suspended) s = 'online'

        const gps = latestGps[t.id]
        return {
          id: t.id,
          full_name: t.full_name || 'Mitra Tukang',
          email: t.email,
          avatar_url: t.avatar_url,
          is_online: t.is_online,
          is_suspended: t.is_suspended,
          status: s,
          job_id: activeJob?.id,
          job_title: activeJob?.title,
          lat: gps?.lat ?? activeJob?.lat ?? t.lat ?? -6.1754,
          lng: gps?.lng ?? activeJob?.lng ?? t.lng ?? 106.8272,
        }
      })

      setTukangs(mapped)
    } finally {
      setIsRefreshing(false)
    }
  }

  // Filter list
  const filteredTukangs = tukangs.filter((t) => {
    if (filterStatus !== 'all' && t.status !== filterStatus) return false

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      return t.full_name.toLowerCase().includes(q) || t.email.toLowerCase().includes(q)
    }
    return true
  })

  const workingCount = tukangs.filter((t) => t.status === 'working').length
  const onlineCount = tukangs.filter((t) => t.status === 'online').length
  const offlineCount = tukangs.filter((t) => t.status === 'offline').length

  return (
    <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
      {/* Panel Kiri: List Semua Tukang (5 Cols) */}
      <div className="lg:col-span-5 bg-white rounded-2xl border border-slate-200/80 shadow-2xs overflow-hidden flex flex-col h-[650px]">
        {/* Header Panel */}
        <div className="p-4 border-b border-slate-100 bg-slate-50/50 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Radio className="w-4 h-4 text-teal-600 animate-pulse" />
              <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
                Daftar Tukang Terdaftar ({tukangs.length})
              </h3>
            </div>
            <button
              onClick={handleRefresh}
              disabled={isRefreshing}
              className="p-1.5 rounded-lg border border-slate-200 text-slate-600 hover:bg-white transition-colors cursor-pointer disabled:opacity-50"
              title="Segarkan data"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>

          {/* Search Input */}
          <div className="relative">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Cari nama tukang..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-8 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
            />
          </div>

          {/* Status Filter Chips */}
          <div className="flex items-center gap-1 overflow-x-auto text-[11px] pt-1">
            <button
              onClick={() => setFilterStatus('all')}
              className={`px-2.5 py-1 rounded-md font-semibold transition-colors cursor-pointer ${
                filterStatus === 'all'
                  ? 'bg-slate-900 text-white'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
              }`}
            >
              Semua ({tukangs.length})
            </button>
            <button
              onClick={() => setFilterStatus('working')}
              className={`px-2.5 py-1 rounded-md font-semibold transition-colors cursor-pointer ${
                filterStatus === 'working'
                  ? 'bg-purple-700 text-white'
                  : 'bg-purple-50 text-purple-700 border border-purple-200'
              }`}
            >
              Bekerja ({workingCount})
            </button>
            <button
              onClick={() => setFilterStatus('online')}
              className={`px-2.5 py-1 rounded-md font-semibold transition-colors cursor-pointer ${
                filterStatus === 'online'
                  ? 'bg-teal-700 text-white'
                  : 'bg-teal-50 text-teal-700 border border-teal-200'
              }`}
            >
              Siap Kerja ({onlineCount})
            </button>
            <button
              onClick={() => setFilterStatus('offline')}
              className={`px-2.5 py-1 rounded-md font-semibold transition-colors cursor-pointer ${
                filterStatus === 'offline'
                  ? 'bg-slate-600 text-white'
                  : 'bg-slate-100 text-slate-500 border border-slate-200'
              }`}
            >
              Offline ({offlineCount})
            </button>
          </div>
        </div>

        {/* List Tukang Scrollable */}
        <div className="flex-1 overflow-y-auto divide-y divide-slate-100 p-2">
          {filteredTukangs.length === 0 ? (
            <div className="p-8 text-center text-xs text-slate-400">
              Tidak ada mitra tukang yang sesuai filter
            </div>
          ) : (
            filteredTukangs.map((t) => {
              const isSelected = selectedTukangId === t.id
              const canTrack = t.status === 'working' || t.status === 'online'

              return (
                <div
                  key={t.id}
                  onClick={() => {
                    if (canTrack) setSelectedTukangId(t.id)
                  }}
                  className={`p-3 rounded-xl transition-all cursor-pointer flex items-center justify-between gap-3 ${
                    isSelected
                      ? 'bg-teal-50 border border-teal-200'
                      : 'hover:bg-slate-50 border border-transparent'
                  }`}
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {t.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={t.avatar_url}
                        alt={t.full_name}
                        className="w-10 h-10 rounded-full object-cover border border-slate-200 shrink-0"
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-slate-100 border border-slate-200 text-slate-700 flex items-center justify-center font-bold text-sm shrink-0">
                        {t.full_name ? t.full_name[0].toUpperCase() : <User className="w-4 h-4" />}
                      </div>
                    )}
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5">
                        <p className="font-bold text-xs text-slate-900 truncate">{t.full_name}</p>
                        <span className="px-1.5 py-0.2 rounded-sm bg-slate-100 text-[10px] text-slate-600 font-mono">
                          Tukang
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-400 truncate">{t.email}</p>

                      {/* Status Keterangan */}
                      <div className="mt-1 flex items-center gap-1.5">
                        <span
                          className={`w-1.5 h-1.5 rounded-full ${
                            t.status === 'working'
                              ? 'bg-purple-600 animate-ping'
                              : t.status === 'online'
                              ? 'bg-teal-500'
                              : 'bg-slate-300'
                          }`}
                        />
                        <span
                          className={`text-[10px] font-semibold ${
                            t.status === 'working'
                              ? 'text-purple-700'
                              : t.status === 'online'
                              ? 'text-teal-700'
                              : 'text-slate-400'
                          }`}
                        >
                          {t.status === 'working'
                            ? 'Sedang Bekerja / Di Jalan'
                            : t.status === 'online'
                            ? 'Siap Terima Kerja (Online)'
                            : 'Offline (Tidak di Radar)'}
                        </span>
                      </div>
                      {t.job_title && (
                        <p className="text-[10px] text-slate-500 truncate mt-0.5 font-medium">
                          Tiket: {t.job_title}
                        </p>
                      )}
                    </div>
                  </div>

                  {canTrack && (
                    <button
                      type="button"
                      className="p-1.5 rounded-lg bg-white border border-slate-200 text-teal-700 hover:bg-teal-50 text-[10px] font-semibold shrink-0"
                      title="Fokuskan posisi tukang di peta"
                    >
                      <MapPin className="w-3.5 h-3.5" />
                    </button>
                  )}
                </div>
              )
            })
          )}
        </div>
      </div>

      {/* Panel Kanan: Peta Radar Leaflet (7 Cols) */}
      <div className="lg:col-span-7 bg-white rounded-2xl border border-slate-200/80 shadow-2xs overflow-hidden flex flex-col h-[650px]">
        {/* Map Header */}
        <div className="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
          <div className="flex items-center gap-2">
            <MapPin className="w-4 h-4 text-teal-600" />
            <h3 className="font-bold text-sm text-slate-900 font-[family-name:var(--font-heading)]">
              Radar Peta Terbuka ({workingCount + onlineCount} Mitra Aktif di Peta)
            </h3>
          </div>
          <div className="flex items-center gap-3 text-xs text-slate-500">
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-purple-600 inline-block" />
              <span>Di Jalan (Motor)</span>
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-teal-600 inline-block" />
              <span>Siap Kerja</span>
            </span>
          </div>
        </div>

        {/* Leaflet Map */}
        <div className="flex-1 relative">
          <TrackingMap tukangs={tukangs} selectedTukangId={selectedTukangId} />
        </div>
      </div>
    </div>
  )
}
