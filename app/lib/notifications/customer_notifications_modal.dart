import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import 'notifications_provider.dart';

class CustomerNotificationsModal extends ConsumerWidget {
  const CustomerNotificationsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CustomerNotificationsModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Pemberitahuan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (notifState.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${notifState.unreadCount}',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notifState.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      ref.read(notificationsProvider.notifier).markAllRead();
                    },
                    child: const Text('Tandai Dibaca', style: TextStyle(fontSize: 12)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Content
          Expanded(
            child: notifState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifState.items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.notifications_none, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Notifikasi',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Respon dari tukang dan update pesanan Anda akan muncul di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: notifState.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final notif = notifState.items[i];
                          return Dismissible(
                            key: Key('notif_dismiss_${notif.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.white, size: 22),
                                  SizedBox(width: 6),
                                  Text(
                                    'Hapus',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) {
                              ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                if (!notif.read) {
                                  ref.read(notificationsProvider.notifier).markAsRead(notif.id);
                                }
                                Navigator.of(context).pop();
                                if (notif.jobId != null) {
                                  context.push('/jobs/${notif.jobId}');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: notif.read
                                      ? AppColors.surfaceVariant.withValues(alpha: 0.3)
                                      : AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: notif.read
                                        ? Colors.transparent
                                        : AppColors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: _getNotifBgColor(notif.type),
                                      child: Icon(_getNotifIcon(notif.type), color: _getNotifColor(notif.type), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notif.body,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: notif.read ? FontWeight.w500 : FontWeight.bold,
                                              color: notif.read ? AppColors.textSecondary : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(notif.createdAt),
                                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!notif.read)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
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
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'job_responded':
        return Icons.handshake_outlined;
      case 'new_job':
        return Icons.work_outline;
      case 'job_locked':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'job_responded':
        return AppColors.secondary;
      case 'job_locked':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  Color _getNotifBgColor(String type) {
    return _getNotifColor(type).withValues(alpha: 0.12);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
