import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/auth/verify_email_page.dart';
import 'package:app/core/theme.dart';

void main() {
  testWidgets('VerifyEmailPage renders email and verification buttons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProviderScope(
          child: VerifyEmailPage(
            email: 'tukangbaru@gmail.com',
            isTukang: true,
          ),
        ),
      ),
    );

    expect(find.text('Verifikasi Email Akun'), findsOneWidget);
    expect(find.text('Cek Email Anda'), findsOneWidget);
    expect(find.text('tukangbaru@gmail.com'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Saya Sudah Verifikasi'), findsOneWidget);
    expect(find.text('Kirim Ulang Email Konfirmasi'), findsOneWidget);
    expect(find.text('Kembali ke Halaman Masuk'), findsOneWidget);
  });
}
