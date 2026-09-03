import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme.dart';
import 'package:app/profile/become_tukang_page.dart';
import 'package:app/profile/profile_provider.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  final mockCategories = [
    ServiceCategory(
      id: 'cat-1',
      name: 'AC',
      slug: 'ac',
      sortOrder: 1,
      createdAt: DateTime.now(),
    ),
    ServiceCategory(
      id: 'cat-2',
      name: 'Cleaning',
      slug: 'cleaning',
      sortOrder: 2,
      createdAt: DateTime.now(),
    ),
  ];

  testWidgets('BecomeTukangPage renders form and handles empty validation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceCategoriesProvider.overrideWith((ref) async => mockCategories),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BecomeTukangPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daftar Menjadi Tukang'), findsOneWidget);
    expect(find.text('Mulai Tawarkan Jasa Anda'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Cleaning'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    final submitButton = find.widgetWithText(ElevatedButton, 'Simpan & Mulai Jadi Tukang');
    expect(submitButton, findsOneWidget);

    // Scroll hingga tombol terlihat, lalu submit
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Bio singkat keahlian wajib diisi'), findsOneWidget);
  });
}
