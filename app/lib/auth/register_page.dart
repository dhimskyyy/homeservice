import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../profile/profile_provider.dart';
import '../profile/tukang_payment_selector.dart';
import '../shared/models/user_profile.dart';
import 'auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  final String? initialRole;

  const RegisterPage({super.key, this.initialRole});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _bioController = TextEditingController();

  bool _obscurePassword = true;
  late bool _isTukang;

  // State khusus tukang
  final Set<String> _selectedServiceIds = {};
  List<PaymentMethod> _selectedPaymentMethods = [PaymentMethod.cash];
  Map<String, dynamic> _paymentDetails = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _isTukang = widget.initialRole == 'tukang';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isTukang) {
      if (_selectedServiceIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tukang wajib memilih minimal 1 kategori keahlian jasa.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_selectedPaymentMethods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih minimal 1 metode pembayaran yang Anda terima.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Sign Up Akun Supabase
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      // 2. Jika Tukang, panggil become_tukang dengan metode pembayaran & rekening/ewallet
      if (_isTukang) {
        await ref.read(profileProvider.notifier).becomeTukang(
              bio: _bioController.text.trim().isNotEmpty
                  ? _bioController.text.trim()
                  : 'Mitra Tukang Beres Profesional',
              serviceTypeIds: _selectedServiceIds.toList(),
              paymentMethods: _selectedPaymentMethods,
              paymentDetails: _paymentDetails,
            );
      }

      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTukang
                  ? 'Selamat bergabung sebagai Mitra Tukang Beres!'
                  : 'Pendaftaran berhasil! Selamat datang di Beres.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
      }
    } catch (_) {
      // Error handled in authProvider state
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isTukang ? 'Daftar Mitra Tukang' : 'Daftar Akun Customer'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Pilihan Role
                      Text(
                        _isTukang ? 'Registrasi Mitra Tukang' : 'Buat Akun Customer',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isTukang
                            ? 'Lengkapi data keahlian dan metode pembayaran Anda untuk mulai menerima pesanan jasa.'
                            : 'Daftar akun untuk mencari dan memesan jasa perbaikan rumah.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Segmented Button Pilihan Role
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Customer')),
                                selected: !_isTukang,
                                selectedColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isTukang ? AppColors.primary : AppColors.textSecondary,
                                ),
                                onSelected: (sel) {
                                  if (sel) setState(() => _isTukang = false);
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Mitra Tukang')),
                                selected: _isTukang,
                                selectedColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isTukang ? AppColors.secondary : AppColors.textSecondary,
                                ),
                                onSelected: (sel) {
                                  if (sel) setState(() => _isTukang = true);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // FIELD DASAR AKUN
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          hintText: 'Budi Santoso',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama lengkap wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'nama@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kata sandi wajib diisi';
                          }
                          if (value.length < 6) {
                            return 'Kata sandi minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Konfirmasi Kata Sandi',
                          prefixIcon: Icon(Icons.lock_clock_outlined),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Konfirmasi kata sandi tidak cocok';
                          }
                          return null;
                        },
                      ),

                      // KHUSUS FORM TUKANG
                      if (_isTukang) ...[
                        const Divider(height: 32),
                        Text(
                          'Kategori Keahlian Jasa yang Dilayani',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pilih minimal satu layanan yang Anda kuasai:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        categoriesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Gagal memuat kategori: $e'),
                          data: (categories) {
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: categories.map((cat) {
                                final isSel = _selectedServiceIds.contains(cat.id);
                                return FilterChip(
                                  label: Text(cat.name),
                                  selected: isSel,
                                  selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                                  checkmarkColor: AppColors.secondary,
                                  labelStyle: TextStyle(
                                    color: isSel ? AppColors.secondary : AppColors.textPrimary,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bioController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Bio & Pengalaman Keahlian',
                            hintText: 'Contoh: Spesialis perbaikan AC bocor dan cuci AC, pengalaman 5 tahun.',
                          ),
                          validator: (val) {
                            if (_isTukang && (val == null || val.trim().length < 8)) {
                              return 'Jelaskan keahlian Anda minimal 8 karakter';
                            }
                            return null;
                          },
                        ),
                        const Divider(height: 32),
                        Text(
                          'Metode Pembayaran yang Didukung',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pilih metode pembayaran (Tunai, E-Wallet, dan Transfer Bank) serta nomor penerimaan dana Anda.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TukangPaymentSelector(
                          initialMethods: _selectedPaymentMethods,
                          initialDetails: _paymentDetails,
                          onChanged: (methods, details) {
                            _selectedPaymentMethods = methods;
                            _paymentDetails = details;
                          },
                        ),
                      ],

                      const SizedBox(height: 24),
                      if (state.error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  state.error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTukang ? AppColors.secondary : AppColors.primary,
                        ),
                        onPressed: _isSubmitting || state.isLoading ? null : _handleRegister,
                        child: _isSubmitting || state.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isTukang ? 'Daftar Menjadi Tukang' : 'Daftar Customer'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sudah punya akun?'),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Masuk'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
