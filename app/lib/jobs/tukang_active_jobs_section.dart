import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../core/theme.dart';
import '../shared/models/job_models.dart';
import 'job_providers.dart';

class TukangActiveJobsSection extends ConsumerWidget {
  const TukangActiveJobsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(tukangJobsProvider);
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);

    return jobsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Gagal memuat pekerjaan Anda: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(tukangJobsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 44,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tidak ada job yang aktif saat ini',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lihat tab "Permintaan Terbuka Sekitar" untuk merespon pekerjaan baru dari customer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final job = jobs[i];
            final isLockedToMe = job.selectedProviderId == user?.id;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isLockedToMe ? AppColors.secondary : AppColors.border,
                  width: isLockedToMe ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            job.categoryName ?? 'Jasa Rumah',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        _buildStatusBadge(job, user?.id),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Highlight jika customer mengunci ke tukang ini
                    if (isLockedToMe && job.status == JobStatus.locked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock, size: 16, color: Colors.amber),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Customer telah memilih Anda! Silakan koordinasi via chat.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      job.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),

                    const SizedBox(height: 14),

                    // Tombol Aksi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(100, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Detail Job', style: TextStyle(fontSize: 12)),
                          onPressed: () => context.push('/jobs/${job.id}'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLockedToMe ? AppColors.secondary : AppColors.primary,
                            minimumSize: const Size(110, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('Buka Chat', style: TextStyle(fontSize: 12)),
                          onPressed: () => context.push('/chat?jobId=${job.id}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(Job job, String? currentUserId) {
    Color bg;
    Color fg;
    String label;

    if (job.selectedProviderId == currentUserId) {
      switch (job.status) {
        case JobStatus.locked:
          bg = Colors.amber.shade100;
          fg = Colors.amber.shade900;
          label = 'Anda Terpilih!';
          break;
        case JobStatus.inProgress:
          bg = Colors.purple.shade100;
          fg = Colors.purple.shade800;
          label = 'Sedang Dikerjakan';
          break;
        case JobStatus.done:
          bg = Colors.green.shade100;
          fg = Colors.green.shade800;
          label = 'Selesai (Menunggu Bayar)';
          break;
        case JobStatus.paid:
          bg = Colors.teal.shade100;
          fg = Colors.teal.shade800;
          label = 'Lunas';
          break;
        default:
          bg = Colors.grey.shade100;
          fg = Colors.grey.shade700;
          label = job.status.displayName;
          break;
      }
    } else {
      if (job.status == JobStatus.open) {
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'Menunggu Customer';
      } else {
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = 'Tukang Lain Terpilih';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
