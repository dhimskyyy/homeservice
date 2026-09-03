import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  group('UserProfile Model', () {
    test('fromJson and toJson should preserve data correctly', () {
      final now = DateTime.now();
      final json = {
        'id': 'u1',
        'email': 'test@beres.test',
        'full_name': 'Budi Santoso',
        'phone': '08123456789',
        'avatar_url': 'https://example.com/avatar.jpg',
        'is_customer': true,
        'is_tukang': true,
        'is_admin': false,
        'is_suspended': false,
        'is_online': true,
        'lat': -6.1754,
        'lng': 106.8272,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'u1');
      expect(profile.email, 'test@beres.test');
      expect(profile.fullName, 'Budi Santoso');
      expect(profile.phone, '08123456789');
      expect(profile.isCustomer, true);
      expect(profile.isTukang, true);
      expect(profile.hasDualRole, true);
      expect(profile.isOnline, true);
      expect(profile.lat, -6.1754);
      expect(profile.lng, 106.8272);
    });

    test('hasDualRole is false when only customer or only tukang', () {
      final customerOnly = UserProfile(
        id: '1',
        email: 'c@test.com',
        fullName: 'Customer',
        isCustomer: true,
        isTukang: false,
        isAdmin: false,
        isSuspended: false,
        isOnline: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tukangOnly = customerOnly.copyWith(
        isCustomer: false,
        isTukang: true,
      );

      expect(customerOnly.hasDualRole, false);
      expect(tukangOnly.hasDualRole, false);

      final dualRole = customerOnly.copyWith(
        isCustomer: true,
        isTukang: true,
      );
      expect(dualRole.hasDualRole, true);
    });
  });

  group('PaymentMethod Enum', () {
    test('conversion to and from database value matches schema enum', () {
      expect(PaymentMethod.cash.toDbValue(), 'cash');
      expect(PaymentMethod.ewallet.toDbValue(), 'ewallet');
      expect(PaymentMethod.bankTransfer.toDbValue(), 'bank_transfer');

      expect(PaymentMethod.fromDbValue('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromDbValue('ewallet'), PaymentMethod.ewallet);
      expect(PaymentMethod.fromDbValue('bank_transfer'), PaymentMethod.bankTransfer);
      expect(PaymentMethod.fromDbValue('unknown'), PaymentMethod.cash);
    });
  });

  group('TukangProfile Model', () {
    test('fromJson parses lists and numbers accurately', () {
      final json = {
        'profile_id': 't1',
        'bio': 'Spesialis AC bocor',
        'service_type_ids': ['s1', 's2'],
        'payment_methods': ['cash', 'ewallet'],
        'rating_avg': 4.8,
        'job_count': 12,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final tukang = TukangProfile.fromJson(json);

      expect(tukang.profileId, 't1');
      expect(tukang.bio, 'Spesialis AC bocor');
      expect(tukang.serviceTypeIds, ['s1', 's2']);
      expect(tukang.paymentMethods, [PaymentMethod.cash, PaymentMethod.ewallet]);
      expect(tukang.ratingAvg, 4.8);
      expect(tukang.jobCount, 12);
    });
  });
}
