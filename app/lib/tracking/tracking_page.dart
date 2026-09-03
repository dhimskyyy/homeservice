import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../shared/models/job_models.dart';
import 'location_provider.dart';

class TrackingPage extends ConsumerWidget {
  final String jobId;

  const TrackingPage({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final trackingState = ref.watch(liveTrackingProvider(jobId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelacakan Tukang Live'),
      ),
      body: SafeArea(
        child: jobAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat job: $e')),
          data: (job) {
            if (job == null) {
              return const Center(child: Text('Data pekerjaan tidak ditemukan'));
            }

            final customerPos = LatLng(job.lat, job.lng);
            final providerPos = trackingState.providerLocation;
            final centerPos = providerPos ?? customerPos;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.radar,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.status == JobStatus.inProgress
                                  ? 'Tukang sedang dalam perjalanan / bekerja'
                                  : 'Status: ${job.status.displayName}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              providerPos != null
                                  ? 'Posisi live diperbarui via Supabase Realtime'
                                  : 'Menunggu pembaruan koordinat GPS dari tukang...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: centerPos,
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.beres.app',
                      ),
                      MarkerLayer(
                        markers: [
                          // Marker Rumah Customer
                          Marker(
                            point: customerPos,
                            width: 44,
                            height: 44,
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.home,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          // Marker Tukang (Bergerak Live)
                          if (providerPos != null)
                            Marker(
                              point: providerPos,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.two_wheeler,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.home, color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Text('Lokasi Pekerjaan', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Posisi Tukang Live', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
