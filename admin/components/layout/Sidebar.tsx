'use client'

import React from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard,
  Users,
  Briefcase,
  Receipt,
  AlertTriangle,
  MapPin,
  Home,
} from 'lucide-react'
import { cn } from '@/lib/utils'

const menuItems = [
  {
    title: 'Dashboard',
    href: '/dashboard',
    icon: LayoutDashboard,
  },
  {
    title: 'Pengguna',
    href: '/users',
    icon: Users,
  },
  {
    title: 'Permintaan Jasa',
    href: '/jobs',
    icon: Briefcase,
  },
  {
    title: 'Nota & Pembayaran',
    href: '/agreements',
    icon: Receipt,
  },
  {
    title: 'Komplain Layanan',
    href: '/complaints',
    icon: AlertTriangle,
  },
  {
    title: 'Pelacakan Live',
    href: '/tracking',
    icon: MapPin,
  },
]

export function Sidebar() {
  const pathname = usePathname()

  return (
    <aside className="w-64 bg-slate-900 text-white min-h-screen flex flex-col border-r border-slate-800">
      {/* Brand Header */}
      <div className="h-16 flex items-center px-6 border-b border-slate-800/80 gap-3">
        <div className="w-9 h-9 rounded-lg bg-teal-600 flex items-center justify-center text-white font-bold shadow-xs">
          <Home className="w-5 h-5" />
        </div>
        <div>
          <h1 className="font-bold text-base tracking-tight font-[family-name:var(--font-heading)] leading-none">
            Beres Admin
          </h1>
          <span className="text-[10px] uppercase font-semibold text-teal-400 tracking-wider">
            Control Panel
          </span>
        </div>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 px-3 py-4 space-y-1">
        {menuItems.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== '/dashboard' && pathname.startsWith(item.href))
          const Icon = item.icon

          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                isActive
                  ? 'bg-teal-600/20 text-teal-400 border-l-3 border-teal-500 font-semibold'
                  : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/60'
              )}
            >
              <Icon className={cn('w-4 h-4', isActive ? 'text-teal-400' : 'text-slate-400')} />
              <span>{item.title}</span>
            </Link>
          )
        })}
      </nav>

      {/* Footer Info */}
      <div className="p-4 border-t border-slate-800 text-xs text-slate-500">
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          <span>Supabase Connected</span>
        </div>
        <p className="mt-1 text-[11px] text-slate-600">Beres v1.0 • Phase 6</p>
      </div>
    </aside>
  )
}
