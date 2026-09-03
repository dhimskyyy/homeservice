import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../jobs/tukang_job_feed.dart';
import '../profile/profile_provider.dart';
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
        title: Text(
          activeRole == UserRole.customer ? 'Beres Customer' : 'Beres Tukang',
        ),
        actions: [
          if (activeRole == UserRole.customer)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Daftar Permintaan Saya',
              onPressed: () => context.push('/jobs'),
            ),
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
      floatingActionButton: activeRole == UserRole.customer
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/create-job'),
              icon: const Icon(Icons.add),
              label: const Text('Buat Permintaan'),
            )
          : null,
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_repair_service,
                    size: 64,
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
                  'Layanan Jasa Rumah Transparan & Terpercaya',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Masuk'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Pelanggan"} 👋',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Butuh bantuan apa untuk rumah Anda hari ini?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(110, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('Job Saya', style: TextStyle(fontSize: 12)),
                onPressed: () => context.push('/jobs'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Panggil Tukang Cepat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tukang di sekitar 50 km siap menerima permintaan Anda.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 38),
                          ),
                          onPressed: () => context.push('/create-job'),
                          child: const Text('Buat Permintaan'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 64,
                    color: Colors.white24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Kategori Layanan Jasa',
            style: theme.textTheme.titleMedium,
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
                  childAspectRatio: 0.95,
                ),
                itemCount: categories.length,
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push('/create-job?categoryId=${cat.id}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCategoryIcon(cat.slug),
                              color: AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
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
        ],
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
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Pantau pesanan dan atur ketersediaan Anda',
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
                style: theme.textTheme.titleMedium,
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
