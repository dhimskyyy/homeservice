'use client'

import React, { useState } from 'react'
import Link from 'next/link'
import { Search, ShieldAlert, ShieldCheck, User, Star, Eye } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { StatusBadge } from '@/components/ui/StatusBadge'
import { formatDate } from '@/lib/utils'

interface UserItem {
  id: string
  email: string
  full_name: string
  phone: string | null
  is_customer: boolean
  is_tukang: boolean
  is_admin: boolean
  is_suspended: boolean
  is_online: boolean
  created_at: string
  tukang_profiles:
    | {
        bio: string
        rating_avg: number
        job_count: number
      }[]
    | {
        bio: string
        rating_avg: number
        job_count: number
      }
    | null
}

interface UsersClientProps {
  initialUsers: UserItem[]
}

export function UsersClient({ initialUsers }: UsersClientProps) {
  const [users, setUsers] = useState<UserItem[]>(initialUsers)
  const [activeTab, setActiveTab] = useState<'all' | 'customer' | 'tukang'>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [loadingUserId, setLoadingUserId] = useState<string | null>(null)

  async function handleToggleSuspend(user: UserItem) {
    const nextStatus = !user.is_suspended
    const actionLabel = nextStatus ? 'Suspend' : 'Aktifkan'

    if (
      !confirm(
        `Apakah Anda yakin ingin ${actionLabel.toLowerCase()} pengguna "${user.full_name || user.email}"?`
      )
    ) {
      return
    }

    setLoadingUserId(user.id)
    try {
      const supabase = createClient()
      const { error } = await supabase.rpc('admin_set_suspended', {
        p_user_id: user.id,
        p_suspended: nextStatus,
      })

      if (error) {
        throw error
      }

      setUsers((prev) =>
        prev.map((u) => (u.id === user.id ? { ...u, is_suspended: nextStatus } : u))
      )
    } catch (err: unknown) {
      alert(`Gagal mengubah status: ${err instanceof Error ? err.message : 'Kesalahan jaringan'}`)
    } finally {
      setLoadingUserId(null)
    }
  }

  // Filter list
  const filteredUsers = users.filter((u) => {
    // Role tab filter
    if (activeTab === 'customer' && !u.is_customer) return false
    if (activeTab === 'tukang' && !u.is_tukang) return false

    // Search query filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      const matchName = u.full_name.toLowerCase().includes(q)
      const matchEmail = u.email.toLowerCase().includes(q)
      const matchPhone = u.phone?.toLowerCase().includes(q) ?? false
      return matchName || matchEmail || matchPhone
    }

    return true
  })

  return (
    <div className="bg-white rounded-xl border border-slate-200/80 shadow-2xs overflow-hidden">
      {/* Control Bar: Tabs & Search */}
      <div className="p-4 border-b border-slate-200/80 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-50/50">
        <div className="flex items-center gap-1 bg-slate-200/60 p-1 rounded-lg w-full sm:w-auto">
          <button
            onClick={() => setActiveTab('all')}
            className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all cursor-pointer ${
              activeTab === 'all'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Semua ({users.length})
          </button>
          <button
            onClick={() => setActiveTab('customer')}
            className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all cursor-pointer ${
              activeTab === 'customer'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Customer ({users.filter((u) => u.is_customer).length})
          </button>
          <button
            onClick={() => setActiveTab('tukang')}
            className={`px-3 py-1.5 rounded-md text-xs font-semibold transition-all cursor-pointer ${
              activeTab === 'tukang'
                ? 'bg-white text-slate-900 shadow-xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Tukang ({users.filter((u) => u.is_tukang).length})
          </button>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
          <input
            type="text"
            placeholder="Cari nama, email, nomor HP..."
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
              <th className="px-5 py-3">Pengguna</th>
              <th className="px-4 py-3">Peran (Role)</th>
              <th className="px-4 py-3">Kontak</th>
              <th className="px-4 py-3">Info Tukang</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Terdaftar</th>
              <th className="px-5 py-3 text-right">Aksi</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredUsers.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-5 py-12 text-center text-slate-400">
                  Tidak ada data pengguna yang sesuai dengan filter
                </td>
              </tr>
            ) : (
              filteredUsers.map((u) => {
                const tukangData = Array.isArray(u.tukang_profiles)
                  ? u.tukang_profiles[0]
                  : u.tukang_profiles

                return (
                  <tr key={u.id} className="hover:bg-slate-50/70 transition-colors">
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-700 flex items-center justify-center font-bold text-xs">
                          {u.full_name ? u.full_name[0].toUpperCase() : <User className="w-3.5 h-3.5" />}
                        </div>
                        <div>
                          <p className="font-semibold text-slate-800">
                            {u.full_name || 'Tanpa Nama'}
                          </p>
                          <p className="text-[11px] text-slate-400">{u.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3.5">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        {u.is_customer && (
                          <span className="px-2 py-0.5 rounded-sm bg-blue-50 text-blue-700 text-[10px] font-bold">
                            Customer
                          </span>
                        )}
                        {u.is_tukang && (
                          <span className="px-2 py-0.5 rounded-sm bg-amber-50 text-amber-800 text-[10px] font-bold">
                            Tukang
                          </span>
                        )}
                        {u.is_admin && (
                          <span className="px-2 py-0.5 rounded-sm bg-purple-50 text-purple-700 text-[10px] font-bold">
                            Admin
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3.5 text-slate-600 font-mono">
                      {u.phone || '-'}
                    </td>
                    <td className="px-4 py-3.5">
                      {u.is_tukang && tukangData ? (
                        <div className="flex items-center gap-2 text-xs">
                          <span className="flex items-center text-amber-600 font-semibold">
                            <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400 mr-1" />
                            {tukangData.rating_avg.toFixed(1)}
                          </span>
                          <span className="text-slate-400">• {tukangData.job_count} job</span>
                        </div>
                      ) : (
                        <span className="text-slate-400">-</span>
                      )}
                    </td>
                    <td className="px-4 py-3.5">
                      <StatusBadge status={u.is_suspended ? 'suspended' : 'active'} />
                    </td>
                    <td className="px-4 py-3.5 text-slate-400">{formatDate(u.created_at)}</td>
                    <td className="px-5 py-3.5 text-right flex items-center justify-end gap-2">
                      {u.is_tukang && (
                        <Link
                          href={`/users/${u.id}`}
                          className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-100 text-slate-700 hover:bg-slate-200 border border-slate-200 transition-all cursor-pointer"
                        >
                          <Eye className="w-3.5 h-3.5 text-teal-600" />
                          <span>Detail</span>
                        </Link>
                      )}
                      {!u.is_admin && (
                        <button
                          onClick={() => handleToggleSuspend(u)}
                          disabled={loadingUserId === u.id}
                          className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                            u.is_suspended
                              ? 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200'
                              : 'bg-rose-50 text-rose-700 hover:bg-rose-100 border border-rose-200'
                          }`}
                        >
                          {u.is_suspended ? (
                            <>
                              <ShieldCheck className="w-3.5 h-3.5" />
                              <span>Aktifkan</span>
                            </>
                          ) : (
                            <>
                              <ShieldAlert className="w-3.5 h-3.5" />
                              <span>Suspend</span>
                            </>
                          )}
                        </button>
                      )}
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
