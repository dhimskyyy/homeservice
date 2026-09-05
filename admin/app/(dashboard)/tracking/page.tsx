import React from 'react'
import { createClient } from '@/lib/supabase/server'
import { TrackingClient } from './TrackingClient'

export const dynamic = 'force-dynamic'


interface TukangRow {
  id: string
  full_name: string
  email: string
  avatar_url: string | null
  is_online: boolean
  is_suspended: boolean
  status: 'working' | 'online' | 'offline'
  job_id?: string
  job_title?: string
  lat: number
  lng: number
}

export default async function TrackingPage() {
  const supabase = await createClient()

  // 1. Ambil semua tukang yang terdaftar di sistem
  const { data: tukangProfiles } = await supabase
    .from('profiles')
    .select(`
      id,
      full_name,
      email,
      avatar_url,
      is_online,
      is_suspended
    `)
    .eq('is_tukang', true)
    .order('is_online', { ascending: false })

  // 2. Ambil semua pekerjaan yang sedang in_progress
  const { data: inProgressJobs } = await supabase
    .from('jobs')
    .select('id, title, selected_provider_id, lat, lng')
    .eq('status', 'in_progress')

  // 3. Ambil koordinat GPS terbaru dari tabel locations
  const { data: recentLocations } = await supabase
    .from('locations')
    .select('job_id, provider_id, lat, lng, created_at')
    .order('created_at', { ascending: false })
    .limit(100)

  // Buat map koordinat terbaru per provider
  const latestGpsByProvider: { [providerId: string]: { lat: number; lng: number } } = {}
  ;(recentLocations ?? []).forEach((loc) => {
    if (!latestGpsByProvider[loc.provider_id]) {
      latestGpsByProvider[loc.provider_id] = { lat: loc.lat, lng: loc.lng }
    }
  })

  // Format data tukang terpadu
  const allTukangs = (tukangProfiles ?? []).map((t): TukangRow | null => {
    const activeJob = (inProgressJobs ?? []).find(
      (j) => j.selected_provider_id === t.id
    )

    let statusText: 'working' | 'online' | 'offline' = 'offline'
    let jobTitle: string | undefined

    if (activeJob) {
      statusText = 'working'
      jobTitle = activeJob.title
    } else if (t.is_online && !t.is_suspended) {
      statusText = 'online'
    } else {
      statusText = 'offline'
    }

    // Koordinat: utamakan GPS realtime terbaru, lalu job lokasi, lalu home koordinat tukang
    const gps = latestGpsByProvider[t.id]
    const effectiveLat = gps?.lat ?? activeJob?.lat ?? 0
    const effectiveLng = gps?.lng ?? activeJob?.lng ?? 0

    // Skip tukang yang belum pernah mengirim GPS & tidak sedang di lokasi job
    if (effectiveLat === 0 && effectiveLng === 0) return null

    return {
      id: t.id,
      full_name: t.full_name || 'Mitra Tukang',
      email: t.email,
      avatar_url: t.avatar_url,
      is_online: t.is_online,
      is_suspended: t.is_suspended,
      status: statusText,
      job_id: activeJob?.id,
      job_title: jobTitle,
      lat: effectiveLat,
      lng: effectiveLng,
    }
  }).filter((t): t is TukangRow => t !== null)

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold tracking-tight text-slate-900 font-[family-name:var(--font-heading)]">
          Radar & Pelacakan Live Tukang (GPS Realtime)
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Pantau seluruh mitra tukang terdaftar, status kesiapan kerja online, serta pergerakan armada yang sedang beroperasi di peta.
        </p>
      </div>

      <TrackingClient initialTukangs={allTukangs} />
    </div>
  )
}
