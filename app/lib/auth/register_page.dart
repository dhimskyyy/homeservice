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
      // 1. Sign Up Akun Supabase dengan metadata lengkap
      final metadata = _isTukang
          ? {
              'role': 'tukang',
              'bio': _bioController.text.trim().isNotEmpty
                  ? _bioController.text.trim()
                  : 'Mitra Tukang Beres Profesional',
              'service_type_ids': _selectedServiceIds.toList(),
              'payment_methods': _selectedPaymentMethods.map((m) => m.toDbValue()).toList(),
              'payment_details': _paymentDetails,
            }
          : {'role': 'customer'};

      final hasActiveSession = await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            metadata: metadata,
          );

      if (!mounted) return;

      // Jika email konfirmasi diperlukan (belum ada active session)
      if (!hasActiveSession) {
        context.go(
          '/verify-email',
          extra: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'isTukang': _isTukang,
            'bio': _bioController.text.trim(),
            'serviceTypeIds': _selectedServiceIds.toList(),
            'paymentMethods': _selectedPaymentMethods,
            'paymentDetails': _paymentDetails,
          },
        );
        return;
      }

      // 2. Jika sesi langsung aktif dan mendaftar sebagai Tukang
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pendaftaran gagal: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
                        Row(
                          children: [
                            const Icon(Icons.handyman_outlined, size: 20, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Text(
                              'Kategori Keahlian Jasa yang Dilayani',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pilih satu atau beberapa keahlian jasa yang Anda tawarkan:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedServiceIds.isEmpty
                                  ? Colors.amber.shade300
                                  : AppColors.border,
                            ),
                          ),
                          child: categoriesAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: (e, _) => _buildFallbackCategoryChips(),
                            data: (categories) {
                              final list = categories.isNotEmpty
                                  ? categories
                                  : _getStaticDefaultCategories();

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: list.map((cat) {
                                  final isSel = _selectedServiceIds.contains(cat.id);
                                  return FilterChip(
                                    avatar: Icon(
                                      _getCategoryIcon(cat.slug),
                                      size: 16,
                                      color: isSel ? Colors.white : AppColors.secondary,
                                    ),
                                    label: Text(cat.name),
                                    selected: isSel,
                                    selectedColor: AppColors.secondary,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : AppColors.textPrimary,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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

  List<ServiceCategory> _getStaticDefaultCategories() {
    return [
      ServiceCategory(
        id: '691d4d07-6707-4e0b-8a26-1e648fa0b330',
        name: 'AC',
        slug: 'ac',
        sortOrder: 1,
        createdAt: DateTime.now(),
      ),
      ServiceCategory(
        id: '5b34c4f4-8cd9-4c7e-8047-28fa59481b83',
        name: 'Cleaning',
        slug: 'cleaning',
        sortOrder: 2,
        createdAt: DateTime.now(),
      ),
      ServiceCategory(
        id: '7e28dab8-e5b2-4e35-881d-a3155fe64af3',
        name: 'Plumbing',
        slug: 'plumbing',
        sortOrder: 3,
        createdAt: DateTime.now(),
      ),
      ServiceCategory(
        id: '709cdc56-88ef-43e7-a117-73e35c1c3674',
        name: 'Listrik',
        slug: 'listrik',
        sortOrder: 4,
        createdAt: DateTime.now(),
      ),
      ServiceCategory(
        id: 'feb6ee9c-3bd1-42d0-94e6-13565972be7b',
        name: 'Handyman',
        slug: 'handyman',
        sortOrder: 5,
        createdAt: DateTime.now(),
      ),
    ];
  }

  Widget _buildFallbackCategoryChips() {
    final list = _getStaticDefaultCategories();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: list.map((cat) {
        final isSel = _selectedServiceIds.contains(cat.id);
        return FilterChip(
          avatar: Icon(
            _getCategoryIcon(cat.slug),
            size: 16,
            color: isSel ? Colors.white : AppColors.secondary,
          ),
          label: Text(cat.name),
          selected: isSel,
          selectedColor: AppColors.secondary,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSel ? Colors.white : AppColors.textPrimary,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
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
