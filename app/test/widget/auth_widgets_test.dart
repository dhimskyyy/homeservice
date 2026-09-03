import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/auth/login_page.dart';
import 'package:app/auth/register_page.dart';
import 'package:app/core/theme.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('LoginPage Widget Test', () {
    testWidgets('renders email and password inputs and login button',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const LoginPage()));

      expect(find.text('Masuk ke Beres'), findsOneWidget);
      expect(find.text('Selamat Datang Kembali'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const LoginPage()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    });

    testWidgets('shows invalid email format error', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const LoginPage()));

      await tester.enterText(find.byType(TextFormField).first, 'invalidemail');
      await tester.enterText(find.byType(TextFormField).last, 'secret123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid'), findsOneWidget);
    });
  });

  group('RegisterPage Widget Test', () {
    testWidgets('renders all registration fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const RegisterPage()));

      expect(find.text('Daftar Akun Customer'), findsOneWidget);
      expect(find.text('Buat Akun Customer'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); // Nama, Email, Password, Konfirmasi
      expect(find.widgetWithText(ElevatedButton, 'Daftar Customer'), findsOneWidget);
    });

    testWidgets('validates required fields on submit', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const RegisterPage()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar Customer'));
      await tester.pumpAndSettle();

      expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);
      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    });

    testWidgets('validates password confirmation mismatch', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const RegisterPage()));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Budi Santoso');
      await tester.enterText(fields.at(1), 'budi@test.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'password456'); // beda

      await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar Customer'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi kata sandi tidak cocok'), findsOneWidget);
    });
  });
}
