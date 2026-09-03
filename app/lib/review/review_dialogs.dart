import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import 'review_provider.dart';

class RatingDialog extends ConsumerStatefulWidget {
  final String jobId;
  final String customerId;
  final String providerId;
  final String providerName;

  const RatingDialog({
    super.key,
    required this.jobId,
    required this.customerId,
    required this.providerId,
    required this.providerName,
  });

  @override
  ConsumerState<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends ConsumerState<RatingDialog> {
  int _selectedRating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int r) {
    switch (r) {
      case 1:
        return 'Sangat Kecewa (1)';
      case 2:
        return 'Kurang Puas (2)';
      case 3:
        return 'Cukup (3)';
      case 4:
        return 'Puas (4)';
      case 5:
      default:
        return 'Sangat Puas (5)';
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      await repo.createReview(
        jobId: widget.jobId,
        customerId: widget.customerId,
        providerId: widget.providerId,
        rating: _selectedRating,
        comment: _commentController.text,
      );

      ref.invalidate(jobReviewProvider(widget.jobId));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih atas ulasan dan rating Anda!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim ulasan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Beri Rating untuk ${widget.providerName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bagaimana kualitas hasil kerja tukang ini?',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            // Barisan Bintang Interaktif
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(
                    starValue <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber.shade600,
                  ),
                  onPressed: () {
                    setState(() => _selectedRating = starValue);
                  },
                );
              }),
            ),
            Text(
              _getRatingLabel(_selectedRating),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tuliskan komentar atau ulasan Anda (opsional)...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nanti Saja'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(110, 40),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kirim Rating'),
        ),
      ],
    );
  }
}

class ComplaintDialog extends ConsumerStatefulWidget {
  final String jobId;
  final String customerId;
  final String providerId;

  const ComplaintDialog({
    super.key,
    required this.jobId,
    required this.customerId,
    required this.providerId,
  });

  @override
  ConsumerState<ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends ConsumerState<ComplaintDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(complaintRepositoryProvider);
      await repo.createComplaint(
        jobId: widget.jobId,
        customerId: widget.customerId,
        providerId: widget.providerId,
        reason: _reasonController.text,
      );

      ref.invalidate(jobComplaintProvider(widget.jobId));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komplain Anda telah terkirim dan akan ditinjau oleh Admin Beres.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim komplain: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.report_problem, color: AppColors.error, size: 22),
          SizedBox(width: 8),
          Text('Ajukan Komplain'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jelaskan kendala atau ketidaksesuaian hasil kerja yang Anda alami. Tim admin kami akan menindaklanjuti.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Tuliskan alasan komplain Anda secara rinci (minimal 10 karakter)...',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alasan komplain wajib diisi';
                  }
                  if (val.trim().length < 10) {
                    return 'Alasan komplain minimal 10 karakter';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(120, 40),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kirim Komplain'),
        ),
      ],
    );
  }
}
