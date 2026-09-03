import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/auth/auth_provider.dart';
import 'package:app/chat/chat_provider.dart' show jobAgreementsProvider;
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_detail_page.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/review/review_dialogs.dart';
import 'package:app/review/review_provider.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final customerUser = User(
    id: 'cust-1',
    appMetadata: {},
    userMetadata: {'full_name': 'Budi Pelanggan'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final doneJob = Job(
    id: 'job-1',
    customerId: 'cust-1',
    categoryId: 'cat-1',
    title: 'Service Cuci AC',
    description: 'Cuci bersih 2 unit indoor & outdoor',
    lat: -6.1754,
    lng: 106.8272,
    status: JobStatus.done,
    selectedProviderId: 'prov-1',
    selectedProviderName: 'Agus Pratama',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets('RatingDialog renders interactive star options and sends review',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RatingDialog(
              jobId: 'job-1',
              customerId: 'cust-1',
              providerId: 'prov-1',
              providerName: 'Agus Pratama',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Beri Rating untuk Agus Pratama'), findsOneWidget);
    expect(find.text('Sangat Puas (5)'), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(5));
    expect(find.widgetWithText(ElevatedButton, 'Kirim Rating'), findsOneWidget);

    // Tap bintang ke-4
    await tester.tap(find.byType(IconButton).at(3));
    await tester.pumpAndSettle();

    expect(find.text('Puas (4)'), findsOneWidget);
  });

  testWidgets('ComplaintDialog validates reason minimum 10 chars',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ComplaintDialog(
              jobId: 'job-1',
              customerId: 'cust-1',
              providerId: 'prov-1',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ajukan Komplain'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Kirim Komplain'), findsOneWidget);

    // Submit kosong
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kirim Komplain'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan komplain wajib diisi'), findsOneWidget);

    // Submit terlalu pendek (< 10 karakter)
    await tester.enterText(find.byType(TextFormField), 'Rusak!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kirim Komplain'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan komplain minimal 10 karakter'), findsOneWidget);
  });

  testWidgets(
      'JobDetailPage displays Rating and Complaint sections for customer on done job',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(customerUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => doneJob),
          jobApplicationsProvider('job-1').overrideWith((ref) async => []),
          jobAgreementsProvider('job-1').overrideWith((ref) async => []),
          jobReviewProvider('job-1').overrideWith((ref) async => null),
          jobComplaintProvider('job-1').overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobDetailPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ulasan & Rating Anda'), findsOneWidget);
    expect(find.byKey(const Key('give_rating_button')), findsOneWidget);
    expect(find.byKey(const Key('open_complaint_dialog_button')), findsOneWidget);
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
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {}
}
