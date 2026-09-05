import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../notifications/notifications_provider.dart';

class TukangNotificationsPanel extends ConsumerWidget {
  const TukangNotificationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Notifikasi Pesanan Masuk',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (notifState.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${notifState.unreadCount} baru',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    if (notifState.unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          ref.read(notificationsProvider.notifier).markAllRead();
                        },
                        child: const Text(
                          'Tandai dibaca',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (notifState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (notifState.error != null)
              Text(
                'Gagal memuat notifikasi: ${notifState.error}',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              )
            else if (notifState.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.inbox, size: 32, color: AppColors.textMuted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Belum ada notifikasi. Pastikan status Anda online dan radius jangkauan aktif di Profil.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifState.items.take(5).length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final notif = notifState.items[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!notif.read) {
                        ref.read(notificationsProvider.notifier).markAllRead();
                      }
                      if (notif.jobId != null) {
                        context.push('/jobs/${notif.jobId}');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: notif.read
                            ? AppColors.surfaceVariant.withValues(alpha: 0.4)
                            : AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: notif.read
                              ? Colors.transparent
                              : AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getNotifIcon(notif.type),
                            color: _getNotifColor(notif.type),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif.body,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: notif.read ? FontWeight.w500 : FontWeight.bold,
                                    color: notif.read
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTime(notif.createdAt),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (!notif.read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'new_job':
        return Icons.work_outline;
      case 'job_responded':
        return Icons.handshake_outlined;
      case 'job_locked':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'new_job':
        return AppColors.primary;
      case 'job_responded':
        return AppColors.secondary;
      case 'job_locked':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
