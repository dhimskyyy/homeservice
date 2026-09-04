'use client'

import React, { useEffect, useRef } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

export interface TukangTrackItem {
  id: string
  full_name: string
  email: string
  avatar_url?: string | null
  is_online: boolean
  is_suspended: boolean
  status: 'working' | 'online' | 'offline'
  job_id?: string
  job_title?: string
  lat: number
  lng: number
}

interface TrackingMapProps {
  tukangs: TukangTrackItem[]
  selectedTukangId?: string | null
}

export default function TrackingMap({ tukangs, selectedTukangId }: TrackingMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<L.Map | null>(null)
  const markersRef = useRef<{ [key: string]: L.Marker }>({})

  useEffect(() => {
    if (!mapContainerRef.current) return

    // Inisialisasi peta Leaflet jika belum ada
    if (!mapInstanceRef.current) {
      const defaultCenter: L.LatLngExpression = [-6.1754, 106.8272] // Jakarta Pusat
      const map = L.map(mapContainerRef.current).setView(defaultCenter, 11)

      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 19,
      }).addTo(map)

      mapInstanceRef.current = map
    }

    const map = mapInstanceRef.current

    // Tukang yang aktif di radar (hanya yang statusnya online atau sedang working)
    // Sesuai permintaan: icon hilang jika tukang offline / mematikan status siap kerja
    const activeTukangs = tukangs.filter(
      (t) => (t.status === 'working' || t.status === 'online') && !t.is_suspended
    )

    // Hapus marker tukang yang sudah offline atau tidak aktif lagi
    const activeIds = new Set(activeTukangs.map((t) => t.id))
    Object.keys(markersRef.current).forEach((id) => {
      if (!activeIds.has(id)) {
        markersRef.current[id].remove()
        delete markersRef.current[id]
      }
    })

    // Tambah / Update marker tukang aktif
    activeTukangs.forEach((t) => {
      const latLng: L.LatLngExpression = [t.lat, t.lng]
      const isWorking = t.status === 'working'

      const customIcon = L.divIcon({
        className: 'custom-tukang-marker',
        html: `
          <div style="
            background-color: ${isWorking ? '#7c3aed' : '#0f766e'};
            width: 36px;
            height: 36px;
            border-radius: 50%;
            border: 3px solid white;
            box-shadow: 0 4px 10px rgba(0,0,0,0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 17px;
            cursor: pointer;
            transition: transform 0.2s ease;
          ">
            ${isWorking ? '🏍️' : '🔧'}
          </div>
        `,
        iconSize: [36, 36],
        iconAnchor: [18, 18],
      })

      const popupHtml = `
        <div style="font-family: sans-serif; min-width: 170px;">
          <h4 style="margin: 0 0 4px; font-size: 13px; font-weight: bold; color: #0f172a;">
            ${t.full_name}
          </h4>
          <p style="margin: 0 0 4px; font-size: 11px; color: ${isWorking ? '#7c3aed' : '#0f766e'}; font-weight: bold;">
            ● ${isWorking ? 'Sedang Bekerja / Di Jalan' : 'Siap Terima Pekerjaan'}
          </p>
          ${
            t.job_title
              ? `<p style="margin: 2px 0; font-size: 11px; color: #334155;">Tiket: <b>${t.job_title}</b></p>`
              : ''
          }
          <p style="margin: 4px 0 0; font-size: 10px; color: #94a3b8; font-family: monospace;">
            GPS: ${t.lat.toFixed(4)}, ${t.lng.toFixed(4)}
          </p>
        </div>
      `

      if (markersRef.current[t.id]) {
        markersRef.current[t.id].setLatLng(latLng)
        markersRef.current[t.id].setIcon(customIcon)
        markersRef.current[t.id].setPopupContent(popupHtml)
      } else {
        const marker = L.marker(latLng, { icon: customIcon })
          .addTo(map)
          .bindPopup(popupHtml)

        markersRef.current[t.id] = marker
      }
    })

    // Fokus ke tukang yang dipilih dari panel kiri jika ada
    if (selectedTukangId && markersRef.current[selectedTukangId]) {
      const selectedMarker = markersRef.current[selectedTukangId]
      map.setView(selectedMarker.getLatLng(), 15, { animate: true })
      selectedMarker.openPopup()
    }
  }, [tukangs, selectedTukangId])

  return <div ref={mapContainerRef} className="w-full h-full min-h-[580px] z-0" />
}
