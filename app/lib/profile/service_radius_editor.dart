import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../profile/profile_provider.dart';
import '../shared/models/user_profile.dart';

/// Modal bottom sheet untuk atur radius jangkauan (0-100 km)
/// dengan animasi radar lingkaran + edit kategori keahlian.
class ServiceRadiusEditor extends ConsumerStatefulWidget {
  final TukangProfile tukangProfile;

  const ServiceRadiusEditor({super.key, required this.tukangProfile});

  static Future<void> show(BuildContext context, TukangProfile tukangProfile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ServiceRadiusEditor(tukangProfile: tukangProfile),
    );
  }

  @override
  ConsumerState<ServiceRadiusEditor> createState() => _ServiceRadiusEditorState();
}

class _ServiceRadiusEditorState extends ConsumerState<ServiceRadiusEditor>
    with SingleTickerProviderStateMixin {
  late int _radiusKm;
  late Set<String> _selectedServiceIds;
  bool _isSaving = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.tukangProfile.serviceRadiusKm.clamp(0, 100);
    _selectedServiceIds = Set.from(widget.tukangProfile.serviceTypeIds);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu kategori keahlian.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).updateTukangServices(
            serviceRadiusKm: _radiusKm,
            serviceTypeIds: _selectedServiceIds.toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan layanan berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sliderPercent = _radiusKm / 100;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset + 16 : 28,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Layanan',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Atur radius jangkauan dan keahlian jasa Anda',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===== 1. RADAR RADIUS ANIMASI =====
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Radar visual
                          SizedBox(
                            width: 190,
                            height: 190,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (ctx, _) {
                                return CustomPaint(
                                  painter: _RadarPainter(
                                    percent: sliderPercent,
                                    pulse: _pulseController.value,
                                    hasSignal: _radiusKm > 0,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _radiusKm > 0
                                            ? AppColors.primary
                                            : Colors.grey.shade400,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.two_wheeler,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Label radius besar
                          Text(
                            _radiusKm == 0
                                ? 'Radar Nonaktif'
                                : 'Radius $_radiusKm km',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _radiusKm == 0
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                            ),
                          ),
                          Text(
                            _radiusKm == 0
                                ? 'Anda tidak akan menerima pesanan baru'
                                : 'Anda menerima pesanan hingga $_radiusKm km dari posisi Anda',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.border,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withValues(alpha: 0.12),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _radiusKm.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '$_radiusKm km',
                              onChanged: (val) {
                                setState(() => _radiusKm = val.round());
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('0 km', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text('50 km', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text('100 km', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ===== 2. KATEGORI KEAHLIAN =====
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.handyman_outlined,
                                  size: 18, color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Text(
                                'Kategori Keahlian Jasa',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pilih jasa yang Anda kuasai. Anda akan menerima pesanan hanya untuk kategori ini. (${_selectedServiceIds.length} dipilih)',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          categoriesAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: (e, _) => Text('Gagal memuat kategori: $e',
                                style: const TextStyle(color: AppColors.error)),
                            data: (categories) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: categories.map((cat) {
                                  final isSel =
                                      _selectedServiceIds.contains(cat.id);
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isSel ? Colors.white : AppColors.textPrimary,
                                    ),
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Simpan Pengaturan Layanan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
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
      case 'servis-motor':
        return Icons.two_wheeler;
      case 'servis-mobil':
        return Icons.directions_car;
      case 'elektronik':
        return Icons.devices_other;
      case 'besi-baja':
        return Icons.construction;
      case 'jahit':
        return Icons.checkroom;
      case 'tambal-ban':
        return Icons.tire_repair;
      case 'las':
        return Icons.local_fire_department;
      default:
        return Icons.home_repair_service;
    }
  }
}

/// Painter untuk radar lingkaran dengan animasi pulse yang membesar/mengecil
class _RadarPainter extends CustomPainter {
  final double percent; // 0.0 - 1.0 (ukuran lingkaran sesuai slider)
  final double pulse; // 0.0 - 1.0 animasi berdenyut
  final bool hasSignal;

  _RadarPainter({
    required this.percent,
    required this.pulse,
    required this.hasSignal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 6;
    final baseRadius = maxRadius * (percent.clamp(0.02, 1.0));

    if (hasSignal) {
      // Lingkaran utama radius
      final mainPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, baseRadius, mainPaint);

      final borderPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, baseRadius, borderPaint);

      // Pulse ring yang membesar & memudar (mengikuti skala radius)
      final pulseRadius = baseRadius * (0.6 + (pulse * 0.4));
      final pulseOpacity = (1.0 - pulse).clamp(0.0, 1.0);
      final pulsePaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.35 * pulseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, pulseRadius, pulsePaint);

      // Garis tengah silang (grid)
      final gridPaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1;
      canvas.drawLine(Offset(center.dx, 8), Offset(center.dx, size.height - 8), gridPaint);
      canvas.drawLine(Offset(8, center.dy), Offset(size.width - 8, center.dy), gridPaint);
    } else {
      final offPaint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, maxRadius * 0.25, offPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.pulse != pulse ||
        oldDelegate.hasSignal != hasSignal;
  }
}
