import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../profile/profile_provider.dart';
import '../shared/models/user_profile.dart';
import 'auth_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  final String email;
  final String? password;
  final bool isTukang;
  final String? bio;
  final List<String> serviceTypeIds;
  final List<PaymentMethod> paymentMethods;
  final Map<String, dynamic> paymentDetails;

  const VerifyEmailPage({
    super.key,
    required this.email,
    this.password,
    this.isTukang = false,
    this.bio,
    this.serviceTypeIds = const [],
    this.paymentMethods = const [],
    this.paymentDetails = const {},
  });

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _handleCheckVerified() async {
    setState(() => _isChecking = true);

    try {
      final c = supabase;

      // Coba refresh session dulu
      try {
        await c.auth.refreshSession();
      } catch (_) {}

      // Jika ada password tersimpan sementara dari form registrasi, coba login otomatis
      if (c.auth.currentSession == null && widget.password != null) {
        try {
          await ref.read(authProvider.notifier).signIn(
                email: widget.email,
                password: widget.password!,
              );
        } catch (_) {}
      }

      final session = c.auth.currentSession;

      if (session != null) {
        // Jika tukang, daftarkan profil tukang sekarang karena session sudah aktif
        if (widget.isTukang) {
          try {
            await ref.read(profileProvider.notifier).becomeTukang(
                  bio: widget.bio ?? 'Mitra Tukang Beres Profesional',
                  serviceTypeIds: widget.serviceTypeIds,
                  paymentMethods: widget.paymentMethods,
                  paymentDetails: widget.paymentDetails,
                );
          } catch (_) {}
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isTukang
                  ? 'Verifikasi berhasil! Selamat datang, Mitra Tukang.'
                  : 'Verifikasi berhasil! Selamat datang di Beres.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
        return;
      }

      // Jika masih belum terverifikasi
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Belum Terkonfirmasi'),
          content: const Text(
            'Email Anda belum terverifikasi. Pastikan Anda sudah membuka Gmail dan mengklik tautan konfirmasi yang kami kirimkan, lalu coba klik tombol ini lagi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Baik, Saya Cek Lagi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() => _isResending = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email konfirmasi baru telah dikirimkan ke kotak masuk Anda.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim ulang email: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Email Akun'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ikon Surat
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: widget.isTukang
                            ? AppColors.secondary.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: widget.isTukang ? AppColors.secondary : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Cek Email Anda',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Tautan konfirmasi pendaftaran telah dikirim ke:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Silakan buka aplikasi Gmail/Email Anda, lalu klik tombol konfirmasi pada pesan dari Beres.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tombol Utama "Saya Sudah Verifikasi"
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            widget.isTukang ? AppColors.secondary : AppColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: _isChecking ? null : _handleCheckVerified,
                      child: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Saya Sudah Verifikasi',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Kirim Ulang Email
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: _isResending
                          ? const Text('Mengirim...')
                          : const Text('Kirim Ulang Email Konfirmasi'),
                      onPressed: _isResending ? null : _handleResendEmail,
                    ),
                    const SizedBox(height: 16),

                    // Kembali ke Halaman Masuk
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Kembali ke Halaman Masuk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
