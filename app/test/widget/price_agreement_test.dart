import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/agreement/price_agreement_widgets.dart';
import 'package:app/core/theme.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/shared/models/user_profile.dart';

void main() {
  testWidgets('PriceAgreementCard renders formatted Rupiah and status correctly',
      (tester) async {
    final validAgreement = PriceAgreement(
      id: 'pa-1',
      jobId: 'j-1',
      customerId: 'c-1',
      providerId: 'p-1',
      amount: 150000,
      paymentMethod: PaymentMethod.cash,
      status: PaymentStatus.pending,
      voided: false,
      createdAt: DateTime.now(),
      providerName: 'Agus Pratama',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PriceAgreementCard(agreement: validAgreement),
        ),
      ),
    );

    expect(find.text('Nota Kesepakatan'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(find.text('Tunai (Cash)'), findsOneWidget);
    expect(find.text('Menunggu Pembayaran'), findsOneWidget);
    expect(find.text('Dibuat oleh: Agus Pratama'), findsOneWidget);
  });

  testWidgets('PriceAgreementCard renders voided status when voided is true',
      (tester) async {
    final voidedAgreement = PriceAgreement(
      id: 'pa-2',
      jobId: 'j-1',
      customerId: 'c-1',
      providerId: 'p-2',
      amount: 200000,
      paymentMethod: PaymentMethod.bankTransfer,
      status: PaymentStatus.pending,
      voided: true,
      createdAt: DateTime.now(),
      providerName: 'Dewi Lestari',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PriceAgreementCard(agreement: voidedAgreement),
        ),
      ),
    );

    expect(find.text('Tidak Berlaku (Void)'), findsOneWidget);
    expect(find.text('Transfer Bank'), findsOneWidget);
  });
}
