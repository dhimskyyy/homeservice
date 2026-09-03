import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/job_models.dart';

class LocationRepository {
  final SupabaseClient? client;

  LocationRepository({this.client});

  Future<LocationPoint?> getLatestLocation(String jobId) async {
    final c = client;
    if (c == null) return null;

    final data = await c
        .from('locations')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return LocationPoint.fromJson(data);
  }

  Future<void> sendLocation({
    required String jobId,
    required String providerId,
    required double lat,
    required double lng,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    await c.from('locations').insert({
      'job_id': jobId,
      'provider_id': providerId,
      'lat': lat,
      'lng': lng,
    });
  }

  RealtimeChannel? subscribeToLocations({
    required String jobId,
    required void Function(LocationPoint location) onLocation,
  }) {
    final c = client;
    if (c == null) return null;

    final channel = c.channel('public:locations:job=$jobId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: jobId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onLocation(LocationPoint.fromJson(record));
            }
          },
        )
        .subscribe();

    return channel;
  }
}
