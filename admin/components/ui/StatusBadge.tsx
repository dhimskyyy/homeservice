import React from 'react'
import { cn } from '@/lib/utils'

interface StatusBadgeProps {
  status: string
  className?: string
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  let label = status
  let styleClass = 'bg-slate-100 text-slate-700 border-slate-200'

  switch (status.toLowerCase()) {
    // Job status
    case 'open':
      label = 'Terbuka'
      styleClass = 'bg-blue-50 text-blue-700 border-blue-200'
      break
    case 'locked':
      label = 'Tukang Terpilih'
      styleClass = 'bg-amber-50 text-amber-800 border-amber-300'
      break
    case 'in_progress':
      label = 'Sedang Dikerjakan'
      styleClass = 'bg-purple-50 text-purple-700 border-purple-200'
      break
    case 'done':
      label = 'Selesai'
      styleClass = 'bg-emerald-50 text-emerald-700 border-emerald-200'
      break
    case 'paid':
      label = 'Lunas'
      styleClass = 'bg-teal-50 text-teal-800 border-teal-300 font-semibold'
      break
    case 'cancelled':
      label = 'Dibatalkan'
      styleClass = 'bg-rose-50 text-rose-700 border-rose-200'
      break

    // Payment status
    case 'pending':
      label = 'Menunggu Bayar'
      styleClass = 'bg-amber-50 text-amber-800 border-amber-200'
      break

    // Complaint status
    case 'resolved':
      label = 'Terselesaikan'
      styleClass = 'bg-emerald-50 text-emerald-700 border-emerald-200'
      break

    // User status
    case 'active':
    case 'aktif':
      label = 'Aktif'
      styleClass = 'bg-emerald-50 text-emerald-700 border-emerald-200'
      break
    case 'suspended':
    case 'suspend':
      label = 'Disuspend'
      styleClass = 'bg-rose-50 text-rose-700 border-rose-300 font-semibold'
      break
  }

  return (
    <span
      className={cn(
        'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border',
        styleClass,
        className
      )}
    >
      {label}
    </span>
  )
}
