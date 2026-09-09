import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../shared/models/job_models.dart';
import 'job_providers.dart';

class JobListPage extends ConsumerWidget {
  final bool showAppBar;

  const JobListPage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(customerJobsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Daftar Permintaan Saya'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerJobsProvider);
          },
          child: jobsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat daftar permintaan',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.refresh(customerJobsProvider),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (jobs) {
              if (jobs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Permintaan',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Anda belum pernah membuat permintaan jasa rumah.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.push('/create-job'),
                          child: const Text('Buat Permintaan Baru'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: jobs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final job = jobs[i];
                  final canDelete = job.status == JobStatus.open || job.status == JobStatus.cancelled;

                  return Dismissible(
                    key: Key('job_dismiss_${job.id}'),
                    direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
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
                          Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Hapus',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                              SizedBox(width: 8),
                              Text('Hapus Permintaan?'),
                            ],
                          ),
                          content: Text('Apakah Anda yakin ingin menghapus permintaan "${job.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dCtx).pop(false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () => Navigator.of(dCtx).pop(true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      try {
                        await ref.read(jobRepositoryProvider).deleteJob(job.id);
                        ref.invalidate(customerJobsProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permintaan jasa berhasil dihapus.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        ref.invalidate(customerJobsProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal menghapus permintaan: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    },
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/jobs/${job.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.title,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(job.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                job.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.category_outlined,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        job.categoryName ?? 'Jasa Umum',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (canDelete) ...[
                                        const Text(
                                          'Geser hapus',
                                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/create-job'),
        icon: const Icon(Icons.add),
        label: const Text('Buat Permintaan'),
      ),
    );
  }

  Widget _buildStatusBadge(JobStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case JobStatus.open:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case JobStatus.locked:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case JobStatus.inProgress:
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case JobStatus.done:
      case JobStatus.paid:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case JobStatus.cancelled:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
