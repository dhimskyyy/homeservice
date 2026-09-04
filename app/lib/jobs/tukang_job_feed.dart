import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../core/geo_service.dart';
import '../core/theme.dart';
import '../shared/models/job_models.dart';
import 'job_providers.dart';

class TukangJobFeed extends ConsumerWidget {
  const TukangJobFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openJobsForTukangProvider);
    final user = ref.watch(authProvider).user;

    return jobsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Gagal memuat pekerjaan: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(openJobsForTukangProvider),
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
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada permintaan pekerjaan baru',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Permintaan baru di radius 50 km akan muncul di sini secara realtime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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
            return _JobItemCard(job: job, userId: user?.id);
          },
        );
      },
    );
  }
}

class _JobItemCard extends ConsumerStatefulWidget {
  final Job job;
  final String? userId;

  const _JobItemCard({required this.job, required this.userId});

  @override
  ConsumerState<_JobItemCard> createState() => _JobItemCardState();
}

class _JobItemCardState extends ConsumerState<_JobItemCard> {
  bool _isResponding = false;

  Future<void> _handleRespond() async {
    if (widget.userId == null) return;

    // Tukang wajib mengaktifkan GPS sebelum merespon permintaan
    final hasGps = await GeoService.ensureTukangGpsEnabled(context);
    if (!hasGps) return;

    setState(() => _isResponding = true);

    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.respondToJob(
        jobId: widget.job.id,
        providerId: widget.userId!,
      );

      ref.invalidate(hasRespondedProvider(widget.job.id));
      ref.invalidate(openJobsForTukangProvider);
      ref.invalidate(tukangJobsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil merespon! Anda sekarang bisa bernegosiasi via chat.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push('/chat?jobId=${widget.job.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal merespon permintaan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRespondedAsync = ref.watch(hasRespondedProvider(widget.job.id));
    final hasResponded = hasRespondedAsync.value ?? false;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    widget.job.categoryName ?? 'Jasa Rumah',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Terbuka',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.job.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.job.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Lokasi: ${widget.job.lat.toStringAsFixed(3)}, ${widget.job.lng.toStringAsFixed(3)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasResponded) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Buka Chat & Buat Nota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(140, 40),
                    ),
                    onPressed: () {
                      context.push('/chat?jobId=${widget.job.id}');
                    },
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: _isResponding
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.reply, size: 18),
                    label: const Text('Respond Permintaan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      minimumSize: const Size(140, 40),
                    ),
                    onPressed: _isResponding ? null : _handleRespond,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
