import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/chat/chat_provider.dart';
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_detail_page.dart';
import 'package:app/jobs/job_list_page.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/shared/models/job_models.dart';

void main() {
  final sampleJob = Job(
    id: 'job-1',
    customerId: 'c-1',
    categoryId: 'cat-1',
    title: 'Perbaikan Pipa Bocor',
    description: 'Pipa wastafel dapur bocor rembes ke bawah',
    lat: -6.1754,
    lng: 106.8272,
    status: JobStatus.open,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    categoryName: 'Plumbing',
  );

  testWidgets('JobListPage renders empty state when jobs list is empty',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerJobsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobListPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daftar Permintaan Saya'), findsOneWidget);
    expect(find.text('Belum Ada Permintaan'), findsOneWidget);
    expect(find.text('Buat Permintaan Baru'), findsOneWidget);
  });

  testWidgets('JobListPage renders job card with title and status badge',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerJobsProvider.overrideWith((ref) async => [sampleJob]),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const JobListPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Perbaikan Pipa Bocor'), findsOneWidget);
    expect(find.text('Pipa wastafel dapur bocor rembes ke bawah'), findsOneWidget);
    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Terbuka'), findsOneWidget);
  });

  testWidgets('JobDetailPage renders title, status and chat button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobDetailProvider('job-1').overrideWith((ref) async => sampleJob),
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

    expect(find.text('Detail Permintaan'), findsOneWidget);
    expect(find.text('Perbaikan Pipa Bocor'), findsOneWidget);
    expect(find.text('Belum ada respon dari tukang sekitar'), findsOneWidget);
    expect(find.text('Buka Ruang Obrolan & Negosiasi'), findsNothing);
  });
}
