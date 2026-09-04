'use client'

import React, { useState } from 'react'
import { useRouter } from 'next/navigation'
import { LogOut, ShieldCheck, User } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'

interface HeaderProps {
  userEmail?: string
}

export function Header({ userEmail = 'admin@beres.test' }: HeaderProps) {
  const router = useRouter()
  const [isLoggingOut, setIsLoggingOut] = useState(false)

  async function handleLogout() {
    setIsLoggingOut(true)
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()
  }

  return (
    <header className="h-16 bg-white border-b border-slate-200/80 px-6 flex items-center justify-between sticky top-0 z-10 shadow-2xs">
      <div className="flex items-center gap-2 text-sm text-slate-500">
        <span className="font-semibold text-slate-900">Portal Operasional Platform</span>
      </div>

      <div className="flex items-center gap-4">
        {/* Admin Profile Chip */}
        <div className="flex items-center gap-2.5 px-3 py-1.5 rounded-lg bg-slate-50 border border-slate-200">
          <div className="w-7 h-7 rounded-full bg-teal-700 text-white flex items-center justify-center text-xs font-bold">
            <User className="w-3.5 h-3.5" />
          </div>
          <div className="text-left hidden sm:block">
            <p className="text-xs font-semibold text-slate-800 leading-tight">Admin Beres</p>
            <p className="text-[11px] text-slate-500 leading-none truncate max-w-[140px]">
              {userEmail}
            </p>
          </div>
          <ShieldCheck className="w-4 h-4 text-teal-600 hidden sm:block ml-1" />
        </div>

        {/* Logout Button */}
        <button
          onClick={handleLogout}
          disabled={isLoggingOut}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-rose-600 hover:bg-rose-50 border border-rose-200 transition-colors"
          title="Keluar dari sesi admin"
        >
          <LogOut className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">
            {isLoggingOut ? 'Keluar...' : 'Keluar'}
          </span>
        </button>
      </div>
    </header>
  )
}
