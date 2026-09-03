import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/theme.dart';
import 'package:app/profile/tukang_payment_selector.dart';

void main() {
  testWidgets(
      'TukangPaymentSelector: displays e-wallets, handles auto-fill check for same numbers, and manual bank inputs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TukangPaymentSelector(
              onChanged: (methods, details) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tunai (Cash)'), findsOneWidget);
    expect(find.text('E-Wallet'), findsOneWidget);
    expect(find.text('Transfer Bank'), findsOneWidget);

    // 1. Centang E-Wallet
    await tester.tap(find.text('E-Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('DANA'), findsOneWidget);
    expect(find.text('OVO'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('ShopeePay'), findsOneWidget);

    // 2. Centang DANA dan isi nomornya
    await tester.tap(find.text('DANA'));
    await tester.pumpAndSettle();

    final danaField = find.widgetWithText(TextFormField, 'Nomor DANA');
    expect(danaField, findsOneWidget);
    await tester.enterText(danaField, '081234567890');
    await tester.pumpAndSettle();

    // 3. Centang OVO
    await tester.tap(find.text('OVO'));
    await tester.pumpAndSettle();

    // Verifikasi muncul checkbox pintar: "Nomor OVO sama dengan nomor DANA?"
    expect(find.text('Nomor OVO sama dengan nomor DANA?'), findsOneWidget);

    // Centang "Nomor OVO sama dengan nomor DANA?"
    await tester.tap(find.text('Nomor OVO sama dengan nomor DANA?'));
    await tester.pumpAndSettle();

    // Verifikasi field OVO otomatis terisi '081234567890'
    final ovoField = find.widgetWithText(TextFormField, 'Nomor OVO');
    expect(ovoField, findsOneWidget);
    expect(find.descendant(of: ovoField, matching: find.text('081234567890')), findsOneWidget);

    // 4. Centang Transfer Bank
    final transferBankFinder = find.text('Transfer Bank');
    await tester.ensureVisible(transferBankFinder);
    await tester.pumpAndSettle();
    await tester.tap(transferBankFinder);
    await tester.pumpAndSettle();

    expect(find.text('Bank BCA'), findsOneWidget);
    expect(find.text('Bank BRI'), findsOneWidget);
    expect(find.text('Bank BNI'), findsOneWidget);

    // Centang Bank BCA
    final bcaFinder = find.text('Bank BCA');
    await tester.ensureVisible(bcaFinder);
    await tester.pumpAndSettle();
    await tester.tap(bcaFinder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Nomor Rekening Bank BCA'), findsOneWidget);
    // Tidak ada opsi "Nomor rekening sama" untuk bank (karena setiap bank beda rekening)
    expect(find.textContaining('sama dengan nomor BCA'), findsNothing);
  });
}
