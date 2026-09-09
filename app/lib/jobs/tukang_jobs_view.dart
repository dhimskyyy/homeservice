import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../shared/models/job_models.dart';
import '../shared/widgets/spinning_refresh_button.dart';
import 'job_providers.dart';

class TukangJobsView extends ConsumerStatefulWidget {
  final bool showAppBar;

  const TukangJobsView({super.key, this.showAppBar = false});

  @override
  ConsumerState<TukangJobsView> createState() => _TukangJobsViewState();
}

class _TukangJobsViewState extends ConsumerState<TukangJobsView> {
  int _selectedFilter = 0; // 0: Semua, 1: Aktif, 2: Selesai

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allJobsAsync = ref.watch(tukangAllJobsProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Pekerjaan Saya'),
              automaticallyImplyLeading: false,
              actions: [
                SpinningRefreshButton(
                  size: 20,
                  onRefresh: () async {
                    ref.invalidate(tukangAllJobsProvider);
                    ref.invalidate(tukangJobsProvider);
                  },
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _selectedFilter == 0,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _selectedFilter == 0 ? AppColors.primary : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Sedang Berjalan'),
                    selected: _selectedFilter == 1,
                    selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _selectedFilter == 1 ? AppColors.secondary : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Selesai'),
                    selected: _selectedFilter == 2,
                    selectedColor: AppColors.success.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _selectedFilter == 2 ? AppColors.success : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(tukangAllJobsProvider);
                  ref.invalidate(tukangJobsProvider);
                },
                child: allJobsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text('Gagal memuat pekerjaan: $e', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.refresh(tukangAllJobsProvider),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (jobs) {
                    List<Job> filtered = jobs;
                    if (_selectedFilter == 1) {
                      filtered = jobs.where((j) =>
                          j.status == JobStatus.open ||
                          j.status == JobStatus.locked ||
                          j.status == JobStatus.inProgress
                      ).toList();
                    } else if (_selectedFilter == 2) {
                      filtered = jobs.where((j) =>
                          j.status == JobStatus.done ||
                          j.status == JobStatus.paid
                      ).toList();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_outlined, size: 56, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Pekerjaan',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pekerjaan yang Anda respon atau kerjakan akan tampil di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final job = filtered[i];

                        return Card(
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ],
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
          ],
        ),
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
