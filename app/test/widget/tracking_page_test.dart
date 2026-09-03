import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/tracking/location_provider.dart';
import 'package:app/tracking/location_repository.dart';
import 'package:app/tracking/tracking_page.dart';

void main() {
  final inProgressJob = Job(
    id: 'job-1',
    customerId: 'cust-1',
    categoryId: 'cat-1',
    title: 'Service Pompa Air',
    description: 'Pompa tidak mau menyedot air',
    lat: -6.1754,
    lng: 106.8272,
    status: JobStatus.inProgress,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('TrackingPage renders live status and legend labels',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobDetailProvider('job-1').overrideWith((ref) async => inProgressJob),
          liveTrackingProvider('job-1').overrideWith((ref) {
            return _MockLiveTrackingNotifier(
              const LiveTrackingState(
                providerLocation: LatLng(-6.1800, 106.8300),
                isTracking: true,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TrackingPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pelacakan Tukang Live'), findsOneWidget);
    expect(find.text('Tukang sedang dalam perjalanan / bekerja'), findsOneWidget);
    expect(find.text('Lokasi Pekerjaan'), findsOneWidget);
    expect(find.text('Posisi Tukang Live'), findsOneWidget);
  });
}

class _MockLiveTrackingNotifier extends StateNotifier<LiveTrackingState>
    implements LiveTrackingNotifier {
  _MockLiveTrackingNotifier(super.state);

  @override
  String get jobId => 'job-1';

  @override
  LocationRepository get repo => LocationRepository();
}
