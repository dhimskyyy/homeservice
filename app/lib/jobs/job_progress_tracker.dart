import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../shared/models/job_models.dart';

class JobProgressTracker extends StatelessWidget {
  final JobStatus status;
  final bool isTukangView;

  const JobProgressTracker({
    super.key,
    required this.status,
    this.isTukangView = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == JobStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text(
              'Permintaan Ini Telah Dibatalkan',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      _StepInfo(
        title: 'Terbuka',
        desc: 'Menunggu respon',
        icon: Icons.assignment_outlined,
        isCompleted: status != JobStatus.open,
        isActive: status == JobStatus.open,
      ),
      _StepInfo(
        title: 'Tukang Terpilih',
        desc: 'Deal harga & nota',
        icon: Icons.handyman_outlined,
        isCompleted: status == JobStatus.inProgress ||
            status == JobStatus.done ||
            status == JobStatus.paid,
        isActive: status == JobStatus.locked,
      ),
      _StepInfo(
        title: 'Proses Kerja',
        desc: 'Tukang di jalan / kerja',
        icon: Icons.two_wheeler,
        isCompleted: status == JobStatus.done || status == JobStatus.paid,
        isActive: status == JobStatus.inProgress,
      ),
      _StepInfo(
        title: 'Selesai',
        desc: 'Pembayaran P2P',
        icon: Icons.task_alt,
        isCompleted: status == JobStatus.paid,
        isActive: status == JobStatus.done,
      ),
      _StepInfo(
        title: 'Lunas',
        desc: 'Ulasan & rating',
        icon: Icons.verified,
        isCompleted: status == JobStatus.paid,
        isActive: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timeline, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Tahapan Proses Pekerjaan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              _buildCurrentStatusChip(status),
            ],
          ),
          const SizedBox(height: 16),
          // Stepper Horizontal
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecting line
                final stepIndex = index ~/ 2;
                final isDone = steps[stepIndex].isCompleted;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? AppColors.primary : AppColors.border,
                  ),
                );
              }

              final stepIndex = index ~/ 2;
              final step = steps[stepIndex];
              return _buildStepCircle(step);
            }),
          ),
          const SizedBox(height: 12),
          // Keterangan step aktif
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getStatusDescription(status, isTukangView),
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

  Widget _buildStepCircle(_StepInfo step) {
    Color bg;
    Color iconColor;

    if (step.isCompleted) {
      bg = AppColors.primary;
      iconColor = Colors.white;
    } else if (step.isActive) {
      bg = AppColors.secondary;
      iconColor = Colors.white;
    } else {
      bg = Colors.grey.shade200;
      iconColor = Colors.grey.shade500;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: step.isActive
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          step.isCompleted ? Icons.check : step.icon,
          size: 15,
          color: iconColor,
        ),
      ),
    );
  }

  Widget _buildCurrentStatusChip(JobStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case JobStatus.open:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case JobStatus.locked:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case JobStatus.inProgress:
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade800;
        break;
      case JobStatus.done:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case JobStatus.paid:
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.displayName,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getStatusDescription(JobStatus status, bool isTukang) {
    switch (status) {
      case JobStatus.open:
        return isTukang
            ? 'Permintaan terbuka. Ajukan diri Anda dengan menekan "Respond Permintaan".'
            : 'Permintaan telah disiarkan ke tukang dalam radius 50 km. Menunggu respon.';
      case JobStatus.locked:
        return isTukang
            ? 'Customer telah memilih Anda! Buat nota kesepakatan harga dan tekan "Mulai Bekerja" saat menuju lokasi.'
            : 'Anda telah memilih tukang. Sepakati harga via nota chat dan tunggu tukang mulai bekerja.';
      case JobStatus.inProgress:
        return isTukang
            ? 'Pekerjaan sedang berlangsung. Posisi GPS Anda dibagikan live. Tekan "Tandai Selesai" jika pekerjaan tuntas.'
            : 'Tukang sedang dalam perjalanan / bekerja. Pantau posisi GPS secara live di peta.';
      case JobStatus.done:
        return isTukang
            ? 'Pekerjaan telah Anda tandai selesai. Tunggu pembayaran customer, lalu tekan "Konfirmasi Pembayaran Diterima".'
            : 'Pekerjaan telah diselesaikan tukang. Silakan lakukan pembayaran langsung (P2P) ke tukang.';
      case JobStatus.paid:
        return isTukang
            ? 'Pembayaran telah disetujui & lunas. Pekerjaan selesai sepenuhnya!'
            : 'Pembayaran telah lunas disetujui! Jangan lupa beri rating ulasan bintang untuk tukang.';
      case JobStatus.cancelled:
        return 'Permintaan ini telah dibatalkan.';
    }
  }
}

class _StepInfo {
  final String title;
  final String desc;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;

  _StepInfo({
    required this.title,
    required this.desc,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
  });
}
