import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/job_models.dart';

void main() {
  group('LocationPoint Model', () {
    test('fromJson and toJson serialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'loc-1',
        'job_id': 'job-123',
        'provider_id': 'prov-456',
        'lat': -6.2250,
        'lng': 106.9004,
        'created_at': now.toIso8601String(),
      };

      final loc = LocationPoint.fromJson(json);
      expect(loc.id, 'loc-1');
      expect(loc.jobId, 'job-123');
      expect(loc.providerId, 'prov-456');
      expect(loc.lat, -6.2250);
      expect(loc.lng, 106.9004);

      final serialized = loc.toJson();
      expect(serialized['id'], 'loc-1');
      expect(serialized['lat'], -6.2250);
      expect(serialized['lng'], 106.9004);
    });
  });
}
