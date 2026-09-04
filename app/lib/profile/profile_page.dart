import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../shared/models/job_models.dart';
import '../shared/models/user_profile.dart';
import 'edit_payment_dialog.dart';
import 'edit_profile_dialog.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _selectedHistoryTab = 0; // 0: Aktif, 1: Selesai, 2: Dibatalkan

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
          'Apakah Anda yakin ingin menghapus tiket "${job.title}" dari riwayat Anda?',
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

    final isTukangRole = profileState.activeRole == UserRole.tukang;
    final activeRoleLabel = isTukangRole ? 'Tukang (Penyedia Jasa)' : 'Customer (Pencari Jasa)';

    final tukangJobsAsync = ref.watch(tukangAllJobsProvider);
    final jobs = isTukangRole
        ? (tukangJobsAsync.value ?? [])
        : (customerJobsAsync.value ?? []);

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
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerJobsProvider);
            ref.invalidate(tukangJobsProvider);
            ref.invalidate(tukangAllJobsProvider);
            if (profile.id.isNotEmpty) {
              await ref.read(profileProvider.notifier).loadProfile(profile.id);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER KARTU PROFIL UTAMA (Clean & Modern)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  backgroundImage: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                                      ? NetworkImage(profile.avatarUrl!)
                                      : null,
                                  child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                                      ? Text(
                                          profile.fullName.isNotEmpty
                                              ? profile.fullName[0].toUpperCase()
                                              : 'U',
                                          style: theme.textTheme.headlineMedium?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName.isNotEmpty ? profile.fullName : 'Pengguna Beres',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.email,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      profile.phone!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (profile.isCustomer)
                                        _buildRoleBadge('Customer', Colors.blue.shade700),
                                      if (profile.isTukang)
                                        _buildRoleBadge('Mitra Tukang', AppColors.secondary),
                                      if (profile.isAdmin)
                                        _buildRoleBadge('Admin', Colors.purple.shade700),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Profil & Foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => EditProfileDialog.show(context, profile),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 2. KARTU STATISTIK METRIKS
                if (profile.isTukang && tukang != null)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn('Rating', '${tukang.ratingAvg.toStringAsFixed(1)} ★', Icons.star, Colors.amber.shade600),
                          Container(width: 1, height: 32, color: AppColors.border),
                          _buildStatColumn('Selesai', '${tukang.jobCount} Job', Icons.task_alt, AppColors.primary),
                          Container(width: 1, height: 32, color: AppColors.border),
                          _buildStatColumn('Status', profile.isOnline ? 'Online' : 'Offline', Icons.circle, profile.isOnline ? AppColors.success : Colors.grey),
                        ],
                      ),
                    ),
                  ),

                // 3. KARTU SWITCH ROLE (Hanya jika akun punya 2 role sesuai BR-1.6)
                if (profileState.canSwitchRole) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: AppColors.primary.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.swap_horiz, color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Peran Aktif Saat Ini', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Text(activeRoleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton(
                            key: const Key('switch_role_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(80, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () => ref.read(profileProvider.notifier).switchRole(),
                            child: const Text('Ganti', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // 4. KARTU DETAIL TUKANG (Keahlian, Metode Pembayaran & Status Online)
                if (profile.isTukang && tukang != null) ...[
                  const SizedBox(height: 12),
                  Card(
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
                              Text('Pengaturan Layanan Tukang', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Switch.adaptive(
                                value: profile.isOnline,
                                activeThumbColor: AppColors.success,
                                onChanged: (val) => ref.read(profileProvider.notifier).updateProfile(isOnline: val),
                              ),
                            ],
                          ),
                          Text(
                            profile.isOnline ? 'Siap menerima pesanan di radius 50 km' : 'Sedang offline / tidak menerima pesanan',
                            style: TextStyle(fontSize: 11, color: profile.isOnline ? AppColors.success : AppColors.textSecondary),
                          ),
                          const Divider(height: 20),
                          const Text('Bio / Keahlian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(tukang.bio.isNotEmpty ? tukang.bio : 'Belum ada bio keahlian.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Metode Pembayaran:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: AppColors.secondary),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Kelola', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  EditPaymentDialog.show(context, tukang);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            children: tukang.paymentMethods.map((m) {
                              return Chip(
                                label: Text(m.displayName, style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // 5. AJAKAN DAFTAR TUKANG (Jika akun belum punya role tukang)
                if (!profile.isTukang) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: AppColors.secondary.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.25)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.handyman, color: AppColors.secondary, size: 22),
                              const SizedBox(width: 8),
                              Text('Ingin Menjadi Mitra Tukang?', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Buka keahlian jasa Anda dan terima pesanan dari customer di sekitar radius 50 km.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size(double.infinity, 38)),
                            onPressed: () => context.push('/become-tukang'),
                            child: const Text('Daftar Jadi Tukang Sekarang', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // 6. RIWAYAT PERMINTAAN SAYA (History Permintaan)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('History Permintaan Saya', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Text('Geser kiri ➔ hapus', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 8),

                // Tab Filter
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
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _selectedHistoryTab == 0
                                ? 'Tidak ada pekerjaan yang sedang aktif'
                                : _selectedHistoryTab == 1
                                    ? 'Belum ada riwayat pekerjaan selesai'
                                    : 'Tidak ada tiket yang dibatalkan',
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

                      return Dismissible(
                        key: Key('job_item_${job.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) => _confirmDeleteJob(context, job),
                        onDismissed: (direction) async {
                          try {
                            final repo = ref.read(jobRepositoryProvider);
                            await repo.deleteJob(job.id);
                            ref.invalidate(customerJobsProvider);
                            ref.invalidate(tukangJobsProvider);
                            ref.invalidate(tukangAllJobsProvider);
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
                              Text('Hapus Permintaan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(width: 8),
                              Icon(Icons.delete, color: Colors.white),
                            ],
                          ),
                        ),
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
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
                                    child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(job.categoryName ?? 'Jasa Rumah', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

                // 7. TOMBOL KELUAR DARI AKUN
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text('Keluar dari Akun', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.displayName, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
