import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import 'location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return LocationRepository(client: client);
  } catch (_) {
    return LocationRepository(client: null);
  }
});

class LiveTrackingState {
  final LatLng? providerLocation;
  final bool isTracking;
  final String? error;

  const LiveTrackingState({
    this.providerLocation,
    this.isTracking = false,
    this.error,
  });

  LiveTrackingState copyWith({
    LatLng? providerLocation,
    bool? isTracking,
    String? error,
  }) {
    return LiveTrackingState(
      providerLocation: providerLocation ?? this.providerLocation,
      isTracking: isTracking ?? this.isTracking,
      error: error,
    );
  }
}

class LiveTrackingNotifier extends StateNotifier<LiveTrackingState> {
  final String jobId;
  final LocationRepository repo;
  RealtimeChannel? _channel;

  LiveTrackingNotifier({
    required this.jobId,
    required this.repo,
  }) : super(const LiveTrackingState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isTracking: true, error: null);
    try {
      final latest = await repo.getLatestLocation(jobId);
      if (latest != null) {
        state = state.copyWith(
          providerLocation: LatLng(latest.lat, latest.lng),
        );
      }

      _channel = repo.subscribeToLocations(
        jobId: jobId,
        onLocation: (loc) {
          state = state.copyWith(
            providerLocation: LatLng(loc.lat, loc.lng),
          );
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final liveTrackingProvider = StateNotifierProvider.autoDispose
    .family<LiveTrackingNotifier, LiveTrackingState, String>((ref, jobId) {
  final repo = ref.watch(locationRepositoryProvider);
  return LiveTrackingNotifier(jobId: jobId, repo: repo);
});

// GPS sender loop for tukang while in_progress
class TukangLocationSender {
  final LocationRepository _repo;
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  bool _isRunning = false;

  TukangLocationSender(this._repo);

  bool get isRunning => _isRunning;

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startSending({
    required String jobId,
    required String providerId,
  }) async {
    if (_isRunning) return;

    final hasPerm = await requestPermission();
    if (!hasPerm) return;

    _isRunning = true;

    // Send immediately
    try {
      final currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _repo.sendLocation(
        jobId: jobId,
        providerId: providerId,
        lat: currentPos.latitude,
        lng: currentPos.longitude,
      );
    } catch (_) {}

    // Periodic every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isRunning) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        await _repo.sendLocation(
          jobId: jobId,
          providerId: providerId,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (_) {}
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
  }
}

final tukangLocationSenderProvider = Provider<TukangLocationSender>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  final sender = TukangLocationSender(repo);
  ref.onDispose(() => sender.stop());
  return sender;
});
