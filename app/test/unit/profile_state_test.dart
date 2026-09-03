import 'package:flutter_test/flutter_test.dart';
import 'package:app/profile/profile_provider.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  group('ProfileState & Switch Role logic', () {
    final customerProfile = UserProfile(
      id: 'u1',
      email: 'customer@beres.test',
      fullName: 'Customer Saja',
      isCustomer: true,
      isTukang: false,
      isAdmin: false,
      isSuspended: false,
      isOnline: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final dualRoleProfile = customerProfile.copyWith(
      fullName: 'Customer dan Tukang',
      isTukang: true,
    );

    test('canSwitchRole returns false for single role customer', () {
      final state = ProfileState(profile: customerProfile);
      expect(state.canSwitchRole, false);
    });

    test('canSwitchRole returns true for dual role profile', () {
      final state = ProfileState(profile: dualRoleProfile);
      expect(state.canSwitchRole, true);
    });

    test('state transition when role switched', () {
      var state = ProfileState(
        profile: dualRoleProfile,
        activeRole: UserRole.customer,
      );

      expect(state.activeRole, UserRole.customer);

      state = state.copyWith(
        activeRole: state.activeRole == UserRole.customer
            ? UserRole.tukang
            : UserRole.customer,
      );
      expect(state.activeRole, UserRole.tukang);

      state = state.copyWith(
        activeRole: state.activeRole == UserRole.customer
            ? UserRole.tukang
            : UserRole.customer,
      );
      expect(state.activeRole, UserRole.customer);
    });
  });
}
