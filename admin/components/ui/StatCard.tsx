import React from 'react'
import { LucideIcon } from 'lucide-react'
import { cn } from '@/lib/utils'

interface StatCardProps {
  title: string
  value: string | number
  icon: LucideIcon
  subtitle?: string
  trend?: string
  colorScheme?: 'teal' | 'amber' | 'blue' | 'purple' | 'rose'
}

export function StatCard({
  title,
  value,
  icon: Icon,
  subtitle,
  trend,
  colorScheme = 'teal',
}: StatCardProps) {
  const colorMap = {
    teal: 'bg-teal-50 text-teal-700 border-teal-200',
    amber: 'bg-amber-50 text-amber-700 border-amber-200',
    blue: 'bg-blue-50 text-blue-700 border-blue-200',
    purple: 'bg-purple-50 text-purple-700 border-purple-200',
    rose: 'bg-rose-50 text-rose-700 border-rose-200',
  }

  const iconColor = {
    teal: 'text-teal-600',
    amber: 'text-amber-600',
    blue: 'text-blue-600',
    purple: 'text-purple-600',
    rose: 'text-rose-600',
  }

  return (
    <div className="bg-white rounded-xl p-5 border border-slate-200/80 shadow-xs flex flex-col justify-between hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">
            {title}
          </p>
          <h3 className="text-2xl font-bold text-slate-900 mt-1 font-[family-name:var(--font-heading)]">
            {value}
          </h3>
        </div>
        <div className={cn('p-2.5 rounded-lg border', colorMap[colorScheme])}>
          <Icon className={cn('w-5 h-5', iconColor[colorScheme])} />
        </div>
      </div>
      {(subtitle || trend) && (
        <div className="mt-3 flex items-center justify-between text-xs text-slate-500 pt-2 border-t border-slate-100">
          <span>{subtitle}</span>
          {trend && <span className="font-semibold text-emerald-600">{trend}</span>}
        </div>
      )}
    </div>
  )
}
