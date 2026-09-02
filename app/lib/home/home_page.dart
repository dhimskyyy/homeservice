import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Belum login',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Silakan masuk atau daftar',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _navigateToLogin(context),
                      child: const Text('Masuk'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToRegister(context),
                      child: const Text('Daftar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Sementara: tampilkan email dan logout
    return Scaffold(
      appBar: AppBar(title: const Text('Beres')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Halo, ${user.email}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Anda login sebagai: ${user.userMetadata?['full_name'] ?? 'Pengguna'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    context.go('/login');
  }

  void _navigateToRegister(BuildContext context) {
    context.go('/register');
  }
}