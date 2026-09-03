import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/profile/profile_page.dart';
import 'package:app/profile/profile_provider.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  final customerOnlyProfile = UserProfile(
    id: 'u1',
    email: 'customer@beres.test',
    fullName: 'Budi Pelanggan',
    isCustomer: true,
    isTukang: false,
    isAdmin: false,
    isSuspended: false,
    isOnline: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final dualRoleProfile = customerOnlyProfile.copyWith(
    fullName: 'Agus Customer dan Tukang',
    isTukang: true,
    isOnline: true,
  );

  final dummyTukangProfile = TukangProfile(
    profileId: 'u1',
    bio: 'Ahli listrik dan AC',
    serviceTypeIds: ['s1'],
    paymentMethods: [PaymentMethod.cash, PaymentMethod.ewallet],
    ratingAvg: 4.9,
    jobCount: 8,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets(
      'BR-1.6: Switch Role button does NOT appear when user only has customer role',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerJobsProvider.overrideWith((ref) async => []),
          profileProvider.overrideWith((ref) {
            return _MockProfileNotifier(
              ProfileState(
                profile: customerOnlyProfile,
                activeRole: UserRole.customer,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfilePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Budi Pelanggan'), findsOneWidget);
    expect(find.byKey(const Key('switch_role_button')), findsNothing);
    expect(find.text('Daftar Jadi Tukang Sekarang'), findsOneWidget);
  });

  testWidgets(
      'BR-1.6: Switch Role button APPEARS when user has both customer and tukang roles',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerJobsProvider.overrideWith((ref) async => []),
          profileProvider.overrideWith((ref) {
            return _MockProfileNotifier(
              ProfileState(
                profile: dualRoleProfile,
                tukangProfile: dummyTukangProfile,
                activeRole: UserRole.customer,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfilePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Agus Customer dan Tukang'), findsOneWidget);
    expect(find.byKey(const Key('switch_role_button')), findsOneWidget);
    expect(find.text('Beralih ke Mode Tukang'), findsOneWidget);
    expect(find.text('Daftar Jadi Tukang Sekarang'), findsNothing);
  });

  testWidgets('ProfilePage renders Edit Profile button and History Permintaan',
      (tester) async {
    final sampleJob = Job(
      id: 'job-100',
      customerId: 'u1',
      categoryId: 'cat-1',
      title: 'Perbaikan Kipas Angin',
      description: 'Kipas tidak mau berputar',
      lat: -6.1754,
      lng: 106.8272,
      status: JobStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      categoryName: 'Listrik',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerJobsProvider.overrideWith((ref) async => [sampleJob]),
          profileProvider.overrideWith((ref) {
            return _MockProfileNotifier(
              ProfileState(
                profile: customerOnlyProfile,
                activeRole: UserRole.customer,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfilePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.text('History Permintaan Saya'), findsOneWidget);
    expect(find.text('Perbaikan Kipas Angin'), findsOneWidget);
    expect(find.byType(Dismissible), findsOneWidget);
  });
}

class _MockProfileNotifier extends StateNotifier<ProfileState>
    implements ProfileNotifier {
  _MockProfileNotifier(super.state);

  @override
  void switchRole() {
    if (!state.canSwitchRole) return;
    state = state.copyWith(
      activeRole: state.activeRole == UserRole.customer
          ? UserRole.tukang
          : UserRole.customer,
    );
  }

  @override
  Future<void> becomeTukang({
    required String bio,
    required List<String> serviceTypeIds,
    required List<PaymentMethod> paymentMethods,
  }) async {}

  @override
  Future<void> loadProfile(String userId) async {}

  @override
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    bool? isOnline,
  }) async {}
}
