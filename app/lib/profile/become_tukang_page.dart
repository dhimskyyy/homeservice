import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../shared/models/user_profile.dart';
import 'profile_provider.dart';

class BecomeTukangPage extends ConsumerStatefulWidget {
  const BecomeTukangPage({super.key});

  @override
  ConsumerState<BecomeTukangPage> createState() => _BecomeTukangPageState();
}

class _BecomeTukangPageState extends ConsumerState<BecomeTukangPage> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final Set<String> _selectedServiceIds = {};
  final Set<PaymentMethod> _selectedPaymentMethods = {PaymentMethod.cash};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu keahlian jasa.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedPaymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu metode pembayaran yang Anda terima.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(profileProvider.notifier).becomeTukang(
            bio: _bioController.text.trim(),
            serviceTypeIds: _selectedServiceIds.toList(),
            paymentMethods: _selectedPaymentMethods.toList(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selamat! Anda sekarang terdaftar sebagai Tukang.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendaftar tukang: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Menjadi Tukang'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mulai Tawarkan Jasa Anda',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lengkapi profil keahlian Anda agar customer di radius 50 km dapat menemukan dan mempercayai jasa Anda.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '1. Kategori Jasa yang Dilayani',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Gagal memuat kategori: $err',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  data: (categories) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = _selectedServiceIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServiceIds.add(cat.id);
                              } else {
                                _selectedServiceIds.remove(cat.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  '2. Bio & Pengalaman Kerja',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Spesialis perbaikan AC bocor dan cuci AC, pengalaman 5 tahun di area Jakarta.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bio singkat keahlian wajib diisi';
                    }
                    if (value.trim().length < 10) {
                      return 'Jelaskan keahlian Anda minimal 10 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  '3. Metode Pembayaran yang Diterima',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Column(
                  children: PaymentMethod.values.map((method) {
                    final isChecked = _selectedPaymentMethods.contains(method);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(method.displayName),
                      value: isChecked,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPaymentMethods.add(method);
                          } else {
                            if (_selectedPaymentMethods.length > 1) {
                              _selectedPaymentMethods.remove(method);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Minimal pilih 1 metode pembayaran.'),
                                ),
                              );
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan & Mulai Jadi Tukang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
