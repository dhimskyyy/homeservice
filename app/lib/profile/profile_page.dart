import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../shared/models/job_models.dart';
import '../shared/models/user_profile.dart';
import 'edit_profile_dialog.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _selectedHistoryTab = 0; // 0: Semua / Aktif, 1: Selesai

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Apakah Anda yakin ingin keluar dari Beres?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(88, 40),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).signOut();
      if (!context.mounted) return;
      context.go('/login');
    }
  }

  Future<bool?> _confirmDeleteJob(BuildContext context, Job job) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Hapus Permintaan?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus permintaan "${job.title}" dari riwayat Anda?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final tukang = profileState.tukangProfile;
    final customerJobsAsync = ref.watch(customerJobsProvider);
    final theme = Theme.of(context);

    if (profileState.isLoading && profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Profil tidak ditemukan'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Masuk Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final activeRoleLabel = profileState.activeRole == UserRole.customer
        ? 'Customer (Pencari Jasa)'
        : 'Tukang (Penyedia Jasa)';

    final jobs = customerJobsAsync.value ?? [];
    final activeJobs = jobs
        .where((j) =>
            j.status == JobStatus.open ||
            j.status == JobStatus.locked ||
            j.status == JobStatus.inProgress)
        .toList();
    final completedJobs = jobs
        .where((j) =>
            j.status == JobStatus.done ||
            j.status == JobStatus.paid)
        .toList();
    final cancelledJobs = jobs
        .where((j) => j.status == JobStatus.cancelled)
        .toList();

    List<Job> displayedJobs;
    switch (_selectedHistoryTab) {
      case 1:
        displayedJobs = completedJobs;
        break;
      case 2:
        displayedJobs = cancelledJobs;
        break;
      case 0:
      default:
        displayedJobs = activeJobs;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        // Icon logout di AppBar kanan atas sudah dihapus sesuai revisi
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerJobsProvider);
            if (profile.id.isNotEmpty) {
              await ref.read(profileProvider.notifier).loadProfile(profile.id);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card Profil dengan tombol Edit
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0].toUpperCase()
                                    : 'U',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty
                                        ? profile.fullName
                                        : 'Pengguna Beres',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.email,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.phone!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (profile.isCustomer)
                                        _buildRoleBadge('Customer', Colors.blue.shade700),
                                      if (profile.isTukang)
                                        _buildRoleBadge('Tukang', AppColors.secondary),
                                      if (profile.isAdmin)
                                        _buildRoleBadge('Admin', Colors.purple.shade700),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(120, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit Profil', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => EditProfileDialog(profile: profile),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Kartu Status Mode Aktif & Switch Role (BR-1.6)
                if (profileState.canSwitchRole)
                  Card(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mode Saat Ini: $activeRoleLabel',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('switch_role_button'),
                            icon: const Icon(Icons.sync_alt),
                            label: Text(
                              profileState.activeRole == UserRole.customer
                                  ? 'Beralih ke Mode Tukang'
                                  : 'Beralih ke Mode Customer',
                            ),
                            onPressed: () {
                              ref.read(profileProvider.notifier).switchRole();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // Jika belum tukang, tampilkan ajakan daftar jadi tukang
                if (!profile.isTukang) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.handyman,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ingin Menjadi Mitra Tukang?',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dapatkan pesanan jasa perbaikan rumah di sekitar wilayah Anda.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                            ),
                            onPressed: () => context.push('/become-tukang'),
                            child: const Text('Daftar Jadi Tukang Sekarang'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Info khusus profil tukang jika ada
                if (profile.isTukang && tukang != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profil Jasa Tukang',
                            style: theme.textTheme.titleSmall,
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Rating',
                                  '${tukang.ratingAvg.toStringAsFixed(1)} ★',
                                  Icons.star,
                                  Colors.amber.shade700,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Selesai',
                                  '${tukang.jobCount} Job',
                                  Icons.task_alt,
                                  AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bio / Keahlian:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tukang.bio.isNotEmpty ? tukang.bio : 'Belum ada bio.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Metode Pembayaran Diterima:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: tukang.paymentMethods.map((m) {
                              return Chip(
                                label: Text(
                                  m.displayName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Status Siap Terima Pekerjaan (Online)'),
                            value: profile.isOnline,
                            activeThumbColor: AppColors.success,
                            onChanged: (val) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(isOnline: val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // SECTION: History Permintaan Saya (Geser ke Kiri untuk Menghapus)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History Permintaan Saya',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Geser kiri ➔ hapus',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Toggle Tab: Sedang Berjalan vs Selesai vs Dibatalkan
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Sedang Berjalan (${activeJobs.length})'),
                        selected: _selectedHistoryTab == 0,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        onSelected: (_) => setState(() => _selectedHistoryTab = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Selesai (${completedJobs.length})'),
                        selected: _selectedHistoryTab == 1,
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        onSelected: (_) => setState(() => _selectedHistoryTab = 1),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Dibatalkan (${cancelledJobs.length})'),
                        selected: _selectedHistoryTab == 2,
                        selectedColor: AppColors.error.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.error,
                        onSelected: (_) => setState(() => _selectedHistoryTab = 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (displayedJobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _selectedHistoryTab == 0
                                ? 'Tidak ada permintaan yang sedang aktif'
                                : _selectedHistoryTab == 1
                                    ? 'Belum ada riwayat permintaan selesai'
                                    : 'Tidak ada permintaan yang dibatalkan',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedJobs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final job = displayedJobs[i];

                      // Dismissible geser ke kiri untuk menghapus riwayat
                      return Dismissible(
                        key: Key('job_item_${job.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) => _confirmDeleteJob(context, job),
                        onDismissed: (direction) async {
                          try {
                            final repo = ref.read(jobRepositoryProvider);
                            await repo.deleteJob(job.id);
                            ref.invalidate(customerJobsProvider);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Permintaan "${job.title}" berhasil dihapus.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menghapus: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                        background: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Hapus Permintaan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.delete, color: Colors.white),
                            ],
                          ),
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.push('/jobs/${job.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          job.categoryName ?? 'Jasa Rumah',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildMiniBadge(job.status),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 28),

                // Tombol Keluar dari Akun di Bagian Bawah
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMiniBadge(JobStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
