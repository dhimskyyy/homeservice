import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../auth/role_selection_dialog.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../jobs/tukang_job_feed.dart';
import '../profile/profile_provider.dart';
import '../shared/models/job_models.dart';
import '../shared/models/user_profile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return _buildGuestView(context);
    }

    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;

    if (profileState.isLoading && profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeRole = profileState.activeRole;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.home_repair_service,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              activeRole == UserRole.customer ? 'Beres Customer' : 'Beres Mitra Tukang',
            ),
          ],
        ),
        actions: [
          if (profileState.canSwitchRole)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Ganti Peran',
              onPressed: () {
                ref.read(profileProvider.notifier).switchRole();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      'Beralih ke mode ${ref.read(profileProvider).activeRole == UserRole.customer ? "Customer" : "Tukang"}',
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil Saya',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: activeRole == UserRole.customer
            ? _buildCustomerHome(context, ref, profile)
            : _buildTukangHome(context, ref, profile, profileState.tukangProfile),
      ),
      // Tombol FAB pojok kanan bawah sudah dihapus sesuai revisi
    );
  }

  Widget _buildGuestView(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_repair_service,
                    size: 72,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Beres',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Layanan Jasa Rumah Transparan & Terpercaya\nNegosiasi Harga Langsung via Chat & Nota Digital',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Masuk ke Akun'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => RoleSelectionDialog.show(context),
                  child: const Text('Daftar Akun Baru'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerHome(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final jobsAsync = ref.watch(customerJobsProvider);
    final theme = Theme.of(context);

    // Cari pekerjaan aktif yang belum selesai
    final allJobs = jobsAsync.value ?? [];
    final activeJobs = allJobs
        .where((j) => j.status == JobStatus.open ||
            j.status == JobStatus.locked ||
            j.status == JobStatus.inProgress)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(customerJobsProvider);
        ref.invalidate(serviceCategoriesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Salam & Tombol Riwayat Job Saya
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Pelanggan"} 👋',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Area Jabodetabek & Sekitarnya',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Job Saya', style: TextStyle(fontSize: 12)),
                  onPressed: () => context.push('/jobs'),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Hero Banner Utama Buat Permintaan
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF115E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Jasa Rumah Cepat & Terpercaya',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Ada Kerusakan di Rumah Anda?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Kirim permintaan jasa, terima respon tukang di sekitar, dan sepakati harga via nota transparan.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home_repair_service,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text(
                        'Buat Permintaan Jasa Sekarang',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => context.push('/create-job'),
                    ),
                  ],
                ),
              ),
            ),

            // Banner Permintaan Aktif (Jika Ada)
            if (activeJobs.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Permintaan Sedang Aktif (${activeJobs.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/jobs'),
                    child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...activeJobs.take(2).map((job) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/jobs/${job.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getCategoryIcon(job.categoryName?.toLowerCase() ?? ''),
                              color: AppColors.primary,
                              size: 24,
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  job.categoryName ?? 'Jasa Rumah',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          _buildMiniStatusBadge(job.status),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // Kategori Layanan Jasa
            Text(
              'Pilih Layanan Kategori',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Gagal memuat kategori: $e'),
              data: (categories) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          context.push('/create-job?categoryId=${cat.id}');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getCategoryIcon(cat.slug),
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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

            const SizedBox(height: 28),

            // Keunggulan Aplikasi Beres
            Text(
              'Mengapa Memilih Beres?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureTile(
              icon: Icons.receipt_long,
              title: 'Harga Transparan & Nota Kesepakatan',
              subtitle: 'Harga disepakati lewat chat & dikunci dalam nota digital resmi sebelum pengerjaan.',
            ),
            _buildFeatureTile(
              icon: Icons.radar,
              title: 'Pelacakan Posisi GPS Live',
              subtitle: 'Pantau posisi kedatangan mitra tukang secara langsung di peta realtime.',
            ),
            _buildFeatureTile(
              icon: Icons.verified_user,
              title: 'Pembayaran Langsung Tanpa Potongan',
              subtitle: 'Bayar tunai, transfer, atau e-wallet langsung ke tukang saat pekerjaan selesai.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusBadge(JobStatus status) {
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
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.displayName,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildTukangHome(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
    TukangProfile? tukang,
  ) {
    final theme = Theme.of(context);
    final isOnline = profile?.isOnline ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, Mitra ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Tukang"} 🔧',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Pantau pesanan masuk dan atur ketersediaan Anda',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: isOnline
                ? AppColors.success.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isOnline
                    ? AppColors.success.withValues(alpha: 0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: SwitchListTile(
              title: Text(
                isOnline ? 'Status: Siap Menerima Kerja' : 'Status: Sedang Offline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOnline ? AppColors.success : AppColors.textSecondary,
                ),
              ),
              subtitle: Text(
                isOnline
                    ? 'Anda menerima permintaan job dalam radius 50 km.'
                    : 'Aktifkan untuk mulai menerima notifikasi job.',
                style: const TextStyle(fontSize: 12),
              ),
              value: isOnline,
              activeThumbColor: AppColors.success,
              onChanged: (val) {
                ref.read(profileProvider.notifier).updateProfile(isOnline: val);
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '${tukang?.ratingAvg.toStringAsFixed(1) ?? "0.0"} ★',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Rating Rata-rata',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '${tukang?.jobCount ?? 0}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Pekerjaan Selesai',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Permintaan Jasa Terbuka',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  ref.invalidate(openJobsForTukangProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TukangJobFeed(),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String slug) {
    switch (slug) {
      case 'ac':
        return Icons.ac_unit;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'plumbing':
        return Icons.plumbing;
      case 'listrik':
        return Icons.electric_bolt;
      case 'handyman':
        return Icons.handyman;
      default:
        return Icons.home_repair_service;
    }
  }
}
