import React from 'react'
import Link from 'next/link'
import { ChevronLeft, ChevronRight } from 'lucide-react'

interface PaginationProps {
  currentPage: number
  totalPages: number
  totalItems: number
  pageSize: number
  baseUrl: string
  searchParams?: Record<string, string | undefined>
}

export function Pagination({
  currentPage,
  totalPages,
  totalItems,
  pageSize,
  baseUrl,
  searchParams = {},
}: PaginationProps) {
  if (totalPages <= 1) return null

  const startItem = (currentPage - 1) * pageSize + 1
  const endItem = Math.min(currentPage * pageSize, totalItems)

  function buildUrl(page: number) {
    const params = new URLSearchParams()
    Object.entries(searchParams).forEach(([k, v]) => {
      if (v !== undefined && k !== 'page') params.set(k, v)
    })
    params.set('page', page.toString())
    return `${baseUrl}?${params.toString()}`
  }

  return (
    <div className="flex items-center justify-between px-5 py-3 border-t border-slate-200/80 bg-slate-50/50 text-xs text-slate-500">
      <div>
        Menampilkan <span className="font-semibold text-slate-800">{startItem}</span> -{' '}
        <span className="font-semibold text-slate-800">{endItem}</span> dari{' '}
        <span className="font-semibold text-slate-800">{totalItems}</span> data
      </div>

      <div className="flex items-center gap-1.5">
        <Link
          href={buildUrl(Math.max(1, currentPage - 1))}
          className={`px-2.5 py-1.5 rounded-lg border border-slate-200 flex items-center gap-1 font-medium transition-colors ${
            currentPage <= 1
              ? 'opacity-40 pointer-events-none bg-slate-100 text-slate-400'
              : 'bg-white hover:bg-slate-100 text-slate-700'
          }`}
        >
          <ChevronLeft className="w-3.5 h-3.5" />
          <span>Sebelumnya</span>
        </Link>

        <span className="px-3 py-1 font-semibold text-slate-700">
          Hal {currentPage} dari {totalPages}
        </span>

        <Link
          href={buildUrl(Math.min(totalPages, currentPage + 1))}
          className={`px-2.5 py-1.5 rounded-lg border border-slate-200 flex items-center gap-1 font-medium transition-colors ${
            currentPage >= totalPages
              ? 'opacity-40 pointer-events-none bg-slate-100 text-slate-400'
              : 'bg-white hover:bg-slate-100 text-slate-700'
          }`}
        >
          <span>Berikutnya</span>
          <ChevronRight className="w-3.5 h-3.5" />
        </Link>
      </div>
    </div>
  )
}
