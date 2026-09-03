import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/job_models.dart';

void main() {
  group('ComplaintStatus Enum', () {
    test('roundtrip conversion to/from db value', () {
      expect(ComplaintStatus.open.toDbValue(), 'open');
      expect(ComplaintStatus.resolved.toDbValue(), 'resolved');

      expect(ComplaintStatus.fromDbValue('open'), ComplaintStatus.open);
      expect(ComplaintStatus.fromDbValue('resolved'), ComplaintStatus.resolved);
      expect(ComplaintStatus.fromDbValue('unknown'), ComplaintStatus.open);
    });
  });

  group('Review Model', () {
    test('fromJson and toJson serialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'rev-1',
        'job_id': 'job-1',
        'customer_id': 'cust-1',
        'provider_id': 'prov-1',
        'rating': 5,
        'comment': 'Sangat memuaskan dan cepat rapi!',
        'created_at': now.toIso8601String(),
        'profiles': {'full_name': 'Budi Santoso'},
      };

      final review = Review.fromJson(json);
      expect(review.id, 'rev-1');
      expect(review.rating, 5);
      expect(review.comment, 'Sangat memuaskan dan cepat rapi!');
      expect(review.customerName, 'Budi Santoso');

      final serialized = review.toJson();
      expect(serialized['rating'], 5);
      expect(serialized['comment'], 'Sangat memuaskan dan cepat rapi!');
    });
  });

  group('Complaint Model', () {
    test('fromJson and toJson serialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'comp-1',
        'job_id': 'job-1',
        'customer_id': 'cust-1',
        'provider_id': 'prov-1',
        'reason': 'Pipa masih menetes air setelah diperbaiki.',
        'status': 'open',
        'created_at': now.toIso8601String(),
        'resolved_at': null,
      };

      final comp = Complaint.fromJson(json);
      expect(comp.id, 'comp-1');
      expect(comp.reason, 'Pipa masih menetes air setelah diperbaiki.');
      expect(comp.status, ComplaintStatus.open);

      final serialized = comp.toJson();
      expect(serialized['reason'], 'Pipa masih menetes air setelah diperbaiki.');
      expect(serialized['status'], 'open');
    });
  });
}
