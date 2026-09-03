import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/auth/role_selection_dialog.dart';
import 'package:app/core/theme.dart';

void main() {
  testWidgets('RoleSelectionDialog displays Customer and Tukang registration choices',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: RoleSelectionDialog(),
        ),
      ),
    );

    expect(find.text('Daftar Sebagai Apa?'), findsOneWidget);
    expect(find.text('Customer (Pencari Jasa)'), findsOneWidget);
    expect(find.text('Mitra Tukang (Penyedia Jasa)'), findsOneWidget);
  });
}
