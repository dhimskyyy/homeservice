import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../agreement/price_agreement_widgets.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../core/theme.dart';
import '../review/review_dialogs.dart';
import '../review/review_provider.dart';
import '../shared/models/job_models.dart';
import '../tracking/location_provider.dart';
import 'job_progress_tracker.dart';
import 'job_providers.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailPage({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  bool _isProcessing = false;

  Future<void> _handleLockProvider(String providerId, String providerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih & Kunci Tukang?'),
        content: Text(
          'Apakah Anda yakin memilih $providerName untuk mengerjakan permintaan ini? Aplikasi tukang lain otomatis dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pilih Tukang Ini'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.lockProvider(jobId: widget.jobId, providerId: providerId);

      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(jobApplicationsProvider(widget.jobId));
      ref.invalidate(customerJobsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil memilih $providerName! Membuka ruang chat...'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push('/chat?jobId=${widget.jobId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih tukang: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleStartJob(String providerId) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.startJob(widget.jobId);

      // Start sending location
      ref.read(tukangLocationSenderProvider).startSending(
            jobId: widget.jobId,
            providerId: providerId,
          );

      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(openJobsForTukangProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pekerjaan dimulai! Lokasi Anda dibagikan ke customer.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulai: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCompleteJob() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.completeJob(widget.jobId);

      // Stop location tracking
      ref.read(tukangLocationSenderProvider).stop();

      ref.invalidate(jobDetailProvider(widget.jobId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pekerjaan selesai! Menunggu konfirmasi pembayaran.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyelesaikan pekerjaan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApprovePayment(String agreementId) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.approvePayment(agreementId: agreementId, jobId: widget.jobId);

      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(customerJobsProvider);
      ref.invalidate(chatRoomProvider(widget.jobId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil disetujui! Pekerjaan lunas.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal konfirmasi pembayaran: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCancelJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Batalkan Permintaan?'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan permintaan ini? Tiket akan dihentikan dan dihapus dari daftar permintaan tukang sekitar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.cancelJob(widget.jobId);

      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(customerJobsProvider);
      ref.invalidate(openJobsForTukangProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan berhasil dibatalkan.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCreateAgreementDialog(Job job, String providerId) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => CreateAgreementDialog(
        jobId: job.id,
        customerId: job.customerId,
        providerId: providerId,
      ),
    ).then((val) {
      if (val == true) {
        ref.invalidate(jobAgreementsProvider(widget.jobId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final applicationsAsync = ref.watch(jobApplicationsProvider(widget.jobId));
    final agreementsAsync = ref.watch(jobAgreementsProvider(widget.jobId));
    final reviewAsync = ref.watch(jobReviewProvider(widget.jobId));
    final complaintAsync = ref.watch(jobComplaintProvider(widget.jobId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Permintaan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(jobDetailProvider(widget.jobId));
              ref.invalidate(jobApplicationsProvider(widget.jobId));
              ref.invalidate(jobAgreementsProvider(widget.jobId));
              ref.invalidate(jobReviewProvider(widget.jobId));
              ref.invalidate(jobComplaintProvider(widget.jobId));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: jobAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat detail: $e')),
          data: (job) {
            if (job == null) {
              return const Center(child: Text('Permintaan tidak ditemukan.'));
            }

            final isCustomer = user?.id == job.customerId;
            final isSelectedProvider = user?.id == job.selectedProviderId;

            // Cari nota aktif yang tidak voided
            final agreements = agreementsAsync.value ?? [];
            final activeAgreement = agreements.where((a) => !a.voided).firstOrNull;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kartu Info Job
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  job.categoryName ?? 'Jasa Rumah',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(job.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            job.title,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            job.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Lokasi: ${job.lat.toStringAsFixed(4)}, ${job.lng.toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Kartu Stepper Tracking Progress Alur Kerja
                  JobProgressTracker(
                    status: job.status,
                    isTukangView: isSelectedProvider,
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons berdasarkan Role & Status (Fase 4 Workflow)
                  if (job.status == JobStatus.inProgress) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Lacak Posisi Tukang di Peta Live'),
                      onPressed: () => context.push('/tracking?jobId=${job.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Tombol aksi tukang (start -> complete -> create agreement)
                  if (isSelectedProvider) ...[
                    // Tombol Buat Nota jika belum ada nota aktif
                    if (activeAgreement == null &&
                        (job.status == JobStatus.open || job.status == JobStatus.locked)) ...[
                      ElevatedButton.icon(
                        key: const Key('create_nota_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Buat Nota Kesepakatan Harga'),
                        onPressed: () => _showCreateAgreementDialog(job, user!.id),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (job.status == JobStatus.locked)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Mulai Bekerja (Aktifkan GPS)'),
                        onPressed: _isProcessing ? null : () => _handleStartJob(user!.id),
                      ),
                    if (job.status == JobStatus.inProgress)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Tandai Pekerjaan Selesai'),
                        onPressed: _isProcessing ? null : _handleCompleteJob,
                      ),
                    const SizedBox(height: 12),
                  ],

                  // Kartu Pembayaran P2P (saat done atau paid)
                  if (activeAgreement != null &&
                      (job.status == JobStatus.done || job.status == JobStatus.paid)) ...[
                    _buildPaymentCard(
                      activeAgreement: activeAgreement,
                      job: job,
                      isCustomer: isCustomer,
                      isSelectedProvider: isSelectedProvider,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bagian Rating & Komplain (Fase 5: saat status done atau paid untuk customer)
                  if (isCustomer &&
                      (job.status == JobStatus.done || job.status == JobStatus.paid) &&
                      job.selectedProviderId != null) ...[
                    _buildReviewAndComplaintSection(
                      job: job,
                      review: reviewAsync.value,
                      complaint: complaintAsync.value,
                      user: user!,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tombol Chat Utama HANYA jika tukang sudah terpilih (status bukan open)
                  if (job.status != JobStatus.open &&
                      (isCustomer || isSelectedProvider)) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Buka Obrolan'),
                      onPressed: () {
                        context.push('/chat?jobId=${job.id}');
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  // Tombol Batalkan Permintaan untuk Customer (bisa dari status open atau locked)
                  if (isCustomer &&
                      (job.status == JobStatus.open || job.status == JobStatus.locked)) ...[
                    OutlinedButton.icon(
                      key: const Key('cancel_job_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 42),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Batalkan Permintaan Ini'),
                      onPressed: _isProcessing ? null : _handleCancelJob,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Peta Titik Lokasi Customer (Sesuai Permintaan)
                  _buildCustomerLocationMap(job, theme),
                  const SizedBox(height: 20),

                  // Bagian Respon Tukang HANYA untuk Customer saat status masih open (untuk memilih tukang)
                  if (isCustomer && job.status == JobStatus.open) ...[
                    Text(
                      'Tukang yang Mengajukan Diri',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    applicationsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Text('Gagal memuat respon: $e'),
                      data: (apps) {
                        if (apps.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.hourglass_empty,
                                      color: AppColors.textMuted,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Belum ada respon dari tukang sekitar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Permintaan sedang disiarkan ke mitra tukang di radius 50 km.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: apps.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final app = apps[i];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                app.providerName ?? 'Mitra Tukang',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (app.providerRating != null)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star,
                                                      size: 16,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      app.providerRating!.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        _buildAppStatusBadge(app.status),
                                      ],
                                    ),
                                    if (app.providerBio != null && app.providerBio!.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        app.providerBio!,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                    if (app.paymentMethods.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: app.paymentMethods.map((m) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              m.displayName,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          key: Key('lock_provider_${app.providerId}'),
                                          icon: const Icon(Icons.check_circle_outline, size: 16),
                                          label: const Text('Terima Tukang Ini'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            minimumSize: const Size(130, 36),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: _isProcessing
                                              ? null
                                              : () => _handleLockProvider(
                                                    app.providerId,
                                                    app.providerName ?? 'Tukang',
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerLocationMap(Job job, ThemeData theme) {
    final location = LatLng(job.lat, job.lng);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Titik Lokasi Rumah / Customer',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: location,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.beres.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.error,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.explore_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Koordinat Lokasi: ${job.lat.toStringAsFixed(5)}, ${job.lng.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required PriceAgreement activeAgreement,
    required Job job,
    required bool isCustomer,
    required bool isSelectedProvider,
    required ThemeData theme,
  }) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  job.status == JobStatus.paid ? Icons.check_circle : Icons.payment,
                  color: Colors.green.shade800,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  job.status == JobStatus.paid
                      ? 'Pembayaran Telah Lunas Disetujui'
                      : 'Pembayaran Jasa (P2P Langsung)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nominal Sesuai Nota:', style: TextStyle(fontSize: 13)),
                Text(
                  currency.format(activeAgreement.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Metode Pembayaran:', style: TextStyle(fontSize: 13)),
                Text(
                  activeAgreement.paymentMethod.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const Divider(height: 20),

            if (job.status == JobStatus.done) ...[
              if (isCustomer) ...[
                const Text(
                  'Silakan lakukan pembayaran langsung ke tukang (tunai/transfer/e-wallet). Tukang akan menyetujui status lunas setelah dana diterima.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Beri Tahu Tukang Saya Sudah Bayar'),
                  onPressed: () {
                    context.push('/chat?jobId=${job.id}');
                  },
                ),
              ],
              if (isSelectedProvider) ...[
                const Text(
                  'Periksa apakah Anda telah menerima pembayaran dari customer.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  key: const Key('approve_payment_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  icon: const Icon(Icons.verified),
                  label: const Text('Konfirmasi Pembayaran Diterima (Lunas)'),
                  onPressed: _isProcessing
                      ? null
                      : () => _handleApprovePayment(activeAgreement.id),
                ),
              ],
            ] else if (job.status == JobStatus.paid) ...[
              const Text(
                'Transaksi selesai sepenuhnya. Terima kasih telah menggunakan Beres!',
                style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(JobStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAppStatusBadge(ApplicationStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case ApplicationStatus.responded:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case ApplicationStatus.selected:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case ApplicationStatus.lockedOut:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
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

  Widget _buildReviewAndComplaintSection({
    required Job job,
    required Review? review,
    required Complaint? complaint,
    required dynamic user,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kartu Ulasan / Tombol Beri Rating
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ulasan & Rating Anda',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (review != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${review.rating} / 5',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (review != null) ...[
                  if (review.comment != null && review.comment!.isNotEmpty)
                    Text('"${review.comment}"', style: theme.textTheme.bodyMedium)
                  else
                    const Text('Anda telah memberi rating tanpa komentar tertulis.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ] else ...[
                  const Text(
                    'Pekerjaan telah selesai. Berikan penilaian bintang dan ulasan untuk hasil kerja mitra tukang.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const Key('give_rating_button'),
                    icon: const Icon(Icons.star_rate, size: 18),
                    label: const Text('Beri Rating & Ulasan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => RatingDialog(
                          jobId: job.id,
                          customerId: job.customerId,
                          providerId: job.selectedProviderId!,
                          providerName: job.selectedProviderName ?? 'Tukang',
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Komplain Section
        if (complaint != null) ...[
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.report_problem, color: AppColors.error, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Komplain Diajukan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: complaint.status == ComplaintStatus.resolved
                              ? Colors.green.shade100
                              : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          complaint.status.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: complaint.status == ComplaintStatus.resolved
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    complaint.reason,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('open_complaint_dialog_button'),
              icon: const Icon(Icons.report_outlined, size: 16, color: AppColors.error),
              label: const Text(
                'Ada masalah? Ajukan Komplain',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ComplaintDialog(
                    jobId: job.id,
                    customerId: job.customerId,
                    providerId: job.selectedProviderId!,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
