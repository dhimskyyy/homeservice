import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/agreement/agreement_repository.dart';
import 'package:app/auth/auth_provider.dart';
import 'package:app/chat/chat_provider.dart' show agreementRepositoryProvider, jobAgreementsProvider;
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_detail_page.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/shared/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final customerUser = User(
    id: 'customer-1',
    appMetadata: {},
    userMetadata: {'full_name': 'Customer Budi'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final providerUser = User(
    id: 'tukang-1',
    appMetadata: {},
    userMetadata: {'full_name': 'Tukang Agus'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final openJob = Job(
    id: 'job-1',
    customerId: 'customer-1',
    categoryId: 'cat-1',
    title: 'Perbaikan AC Rusak',
    description: 'AC tidak dingin dan berisik',
    lat: -6.1754,
    lng: 106.8272,
    status: JobStatus.open,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final respondedApp = JobApplication(
    id: 'app-1',
    jobId: 'job-1',
    providerId: 'tukang-1',
    status: ApplicationStatus.responded,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    providerName: 'Tukang Agus',
    providerRating: 4.8,
  );

  testWidgets(
      'Workflow 1: Customer can see Pilih Tukang Ini button when job is open',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(customerUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => openJob),
          jobApplicationsProvider('job-1').overrideWith((ref) async => [respondedApp]),
          jobAgreementsProvider('job-1').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobDetailPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Perbaikan AC Rusak'), findsOneWidget);
    expect(find.text('Tukang Agus'), findsOneWidget);
    expect(find.byKey(const Key('lock_provider_tukang-1')), findsOneWidget);
    expect(find.byKey(const Key('cancel_job_button')), findsOneWidget);
  });

  testWidgets(
      'Workflow 2: Selected provider can see Mulai Bekerja button when job is locked',
      (tester) async {
    final lockedJob = openJob.copyWith(
      status: JobStatus.locked,
      selectedProviderId: 'tukang-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(providerUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => lockedJob),
          jobApplicationsProvider('job-1').overrideWith((ref) async => [
                respondedApp.copyWith(status: ApplicationStatus.selected),
              ]),
          jobAgreementsProvider('job-1').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobDetailPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mulai Bekerja (Aktifkan GPS)'), findsOneWidget);
  });

  testWidgets(
      'Workflow 3: Shows Tandai Pekerjaan Selesai & Lacak Posisi when job is in_progress',
      (tester) async {
    final inProgressJob = openJob.copyWith(
      status: JobStatus.inProgress,
      selectedProviderId: 'tukang-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(providerUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => inProgressJob),
          jobApplicationsProvider('job-1').overrideWith((ref) async => []),
          jobAgreementsProvider('job-1').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobDetailPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tandai Pekerjaan Selesai'), findsOneWidget);
    expect(find.text('Lacak Posisi Tukang di Peta Live'), findsOneWidget);
  });

  testWidgets(
      'Workflow 4: Provider can approve payment when job is done',
      (tester) async {
    final doneJob = openJob.copyWith(
      status: JobStatus.done,
      selectedProviderId: 'tukang-1',
    );

    final agreement = PriceAgreement(
      id: 'pa-1',
      jobId: 'job-1',
      customerId: 'customer-1',
      providerId: 'tukang-1',
      amount: 175000,
      paymentMethod: PaymentMethod.cash,
      status: PaymentStatus.pending,
      voided: false,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(providerUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => doneJob),
          jobApplicationsProvider('job-1').overrideWith((ref) async => []),
          jobAgreementsProvider('job-1').overrideWith((ref) async => [agreement]),
          agreementRepositoryProvider.overrideWithValue(_MockAgreementRepository([agreement])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobDetailPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pembayaran Jasa (P2P Langsung)'), findsOneWidget);
    expect(find.text('Rp 175.000'), findsOneWidget);
    expect(find.byKey(const Key('approve_payment_button')), findsOneWidget);
  });
}

class _MockAuthNotifier extends StateNotifier<AuthUiState> implements AuthNotifier {
  _MockAuthNotifier(User user) : super(AuthUiState(user: user));

  @override
  SupabaseClient? get client => null;

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    Map<String, dynamic> metadata = const {},
  }) async {
    return true;
  }
}

class _MockAgreementRepository implements AgreementRepository {
  final List<PriceAgreement> agreements;

  _MockAgreementRepository(this.agreements);

  @override
  SupabaseClient? get client => null;

  @override
  Future<PriceAgreement> createAgreement({
    required String jobId,
    required String customerId,
    required String providerId,
    required int amount,
    required PaymentMethod paymentMethod,
  }) async {
    return agreements.first;
  }

  @override
  Future<List<PriceAgreement>> getAgreements(String jobId) async {
    return agreements;
  }

  @override
  RealtimeChannel? subscribeToAgreements({
    required String jobId,
    required void Function() onUpdate,
  }) {
    return null;
  }
}
