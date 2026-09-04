import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/agreement/agreement_repository.dart';
import 'package:app/auth/auth_provider.dart';
import 'package:app/chat/chat_page.dart';
import 'package:app/chat/chat_provider.dart';
import 'package:app/chat/chat_repository.dart';
import 'package:app/core/theme.dart';
import 'package:app/jobs/job_providers.dart';
import 'package:app/shared/models/job_models.dart';
import 'package:app/shared/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final sampleUser = User(
    id: 'c-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final sampleJob = Job(
    id: 'job-1',
    customerId: 'c-1',
    categoryId: 'cat-1',
    title: 'Service AC 1 PK',
    description: 'Cuci AC dan tambah freon',
    lat: -6.1754,
    lng: 106.8272,
    status: JobStatus.open,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleMessages = [
    ChatMessage(
      id: 'm1',
      jobId: 'job-1',
      senderId: 'c-1',
      body: 'Halo tukang, bisa datang besok jam 1 siang?',
      createdAt: DateTime.now(),
      senderName: 'Customer Budi',
    ),
    ChatMessage(
      id: 'm2',
      jobId: 'job-1',
      senderId: 't-1',
      body: 'Bisa pak, estimasi biaya 150rb.',
      createdAt: DateTime.now(),
      senderName: 'Agus Tukang',
    ),
  ];

  final sampleAgreement = PriceAgreement(
    id: 'pa-1',
    jobId: 'job-1',
    customerId: 'c-1',
    providerId: 't-1',
    amount: 150000,
    paymentMethod: PaymentMethod.cash,
    status: PaymentStatus.pending,
    voided: false,
    createdAt: DateTime.now(),
    providerName: 'Agus Tukang',
  );

  testWidgets('ChatPage renders messages, header, and price agreement card',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _MockAuthNotifier(sampleUser)),
          jobDetailProvider('job-1').overrideWith((ref) async => sampleJob),
          chatRoomProvider('job-1').overrideWith((ref) {
            return _MockChatRoomNotifier(
              ChatRoomState(
                messages: sampleMessages,
                agreements: [sampleAgreement],
                isLoading: false,
              ),
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatPage(jobId: 'job-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mitra Tukang'), findsOneWidget);
    expect(find.text('Halo tukang, bisa datang besok jam 1 siang?'), findsOneWidget);
    expect(find.text('Bisa pak, estimasi biaya 150rb.'), findsOneWidget);
    expect(find.text('Nota Kesepakatan'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsWidgets);
  });
}

class _MockChatRoomNotifier extends StateNotifier<ChatRoomState>
    implements ChatRoomNotifier {
  _MockChatRoomNotifier(super.state);

  @override
  String get jobId => 'job-1';

  @override
  ChatRepository get chatRepo => ChatRepository();

  @override
  AgreementRepository get agreementRepo => AgreementRepository();

  @override
  Future<void> sendMessage({required String senderId, required String body, String? mediaUrl}) async {}

  @override
  Future<void> sendMediaMessage({
    required String senderId,
    required String fileName,
    required dynamic bytes,
    String? caption,
  }) async {}

  @override
  Future<void> markAsRead(String currentUserId) async {}

  @override
  Future<void> createPriceAgreement({
    required String customerId,
    required String providerId,
    required int amount,
    required PaymentMethod paymentMethod,
  }) async {}
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
