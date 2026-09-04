import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_progress_tracker.dart';
import 'package:app/shared/models/job_models.dart';

void main() {
  testWidgets('JobProgressTracker renders all workflow steps correctly',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: JobProgressTracker(status: JobStatus.inProgress),
        ),
      ),
    );

    expect(find.text('Tahapan Proses Pekerjaan'), findsOneWidget);
    expect(find.text('Sedang Dikerjakan'), findsOneWidget);
    expect(find.byType(JobProgressTracker), findsOneWidget);
  });

  testWidgets('JobProgressTracker renders cancelled indicator when status cancelled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: JobProgressTracker(status: JobStatus.cancelled),
        ),
      ),
    );

    expect(find.text('Permintaan Ini Telah Dibatalkan'), findsOneWidget);
  });
}
