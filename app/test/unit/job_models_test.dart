import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  group('JobStatus Enum', () {
    test('roundtrip conversion to/from db value', () {
      for (final s in JobStatus.values) {
        expect(JobStatus.fromDbValue(s.toDbValue()), s);
      }
      expect(JobStatus.fromDbValue('unknown'), JobStatus.open);
    });
  });

  group('ApplicationStatus Enum', () {
    test('roundtrip conversion to/from db value', () {
      for (final s in ApplicationStatus.values) {
        expect(ApplicationStatus.fromDbValue(s.toDbValue()), s);
      }
      expect(ApplicationStatus.fromDbValue('unknown'), ApplicationStatus.responded);
    });
  });

  group('PaymentStatus Enum', () {
    test('roundtrip conversion to/from db value', () {
      for (final s in PaymentStatus.values) {
        expect(PaymentStatus.fromDbValue(s.toDbValue()), s);
      }
      expect(PaymentStatus.fromDbValue('unknown'), PaymentStatus.pending);
    });
  });

  group('Job Model', () {
    test('fromJson & toJson serialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'j1',
        'customer_id': 'c1',
        'category_id': 'cat1',
        'title': 'Reparasi AC',
        'description': 'AC tidak dingin',
        'lat': -6.1754,
        'lng': 106.8272,
        'status': 'open',
        'selected_provider_id': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'service_categories': {'name': 'AC'},
      };

      final job = Job.fromJson(json);
      expect(job.id, 'j1');
      expect(job.title, 'Reparasi AC');
      expect(job.status, JobStatus.open);
      expect(job.lat, -6.1754);
      expect(job.categoryName, 'AC');

      final serialized = job.toJson();
      expect(serialized['id'], 'j1');
      expect(serialized['status'], 'open');
    });
  });

  group('PriceAgreement Model', () {
    test('parses amount and payment methods correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'pa1',
        'job_id': 'j1',
        'customer_id': 'c1',
        'provider_id': 'p1',
        'amount': 250000,
        'payment_method': 'cash',
        'status': 'pending',
        'voided': false,
        'created_at': now.toIso8601String(),
        'paid_at': null,
        'profiles': {'full_name': 'Pak Agus Tukang'},
      };

      final agreement = PriceAgreement.fromJson(json);
      expect(agreement.amount, 250000);
      expect(agreement.paymentMethod, PaymentMethod.cash);
      expect(agreement.status, PaymentStatus.pending);
      expect(agreement.voided, false);
      expect(agreement.providerName, 'Pak Agus Tukang');
    });
  });

  group('ChatMessage Model', () {
    test('parses sender body and timestamp', () {
      final now = DateTime.now();
      final json = {
        'id': 'm1',
        'job_id': 'j1',
        'sender_id': 'u1',
        'body': 'Halo pak, besok jam 10 pagi bisa?',
        'created_at': now.toIso8601String(),
        'profiles': {'full_name': 'Budi'},
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.body, 'Halo pak, besok jam 10 pagi bisa?');
      expect(msg.senderId, 'u1');
      expect(msg.senderName, 'Budi');
    });
  });
}
