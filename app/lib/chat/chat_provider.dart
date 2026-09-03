import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../agreement/agreement_repository.dart';
import '../core/supabase_client.dart';
import '../shared/models/job_models.dart';
import '../shared/models/user_profile.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return ChatRepository(client: client);
  } catch (_) {
    return ChatRepository(client: null);
  }
});

final agreementRepositoryProvider = Provider<AgreementRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return AgreementRepository(client: client);
  } catch (_) {
    return AgreementRepository(client: null);
  }
});

final jobAgreementsProvider = FutureProvider.autoDispose
    .family<List<PriceAgreement>, String>((ref, jobId) async {
  final repo = ref.watch(agreementRepositoryProvider);
  return repo.getAgreements(jobId);
});

class ChatRoomState {
  final List<ChatMessage> messages;
  final List<PriceAgreement> agreements;
  final bool isLoading;
  final String? error;

  const ChatRoomState({
    this.messages = const [],
    this.agreements = const [],
    this.isLoading = false,
    this.error,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    List<PriceAgreement>? agreements,
    bool? isLoading,
    String? error,
  }) {
    return ChatRoomState(
      messages: messages ?? this.messages,
      agreements: agreements ?? this.agreements,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  final String jobId;
  final ChatRepository chatRepo;
  final AgreementRepository agreementRepo;
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _agreementChannel;

  ChatRoomNotifier({
    required this.jobId,
    required this.chatRepo,
    required this.agreementRepo,
  }) : super(const ChatRoomState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final msgs = await chatRepo.getMessages(jobId);
      final agrs = await agreementRepo.getAgreements(jobId);

      state = state.copyWith(
        messages: msgs,
        agreements: agrs,
        isLoading: false,
      );

      _subscribeRealtime();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeRealtime() {
    _msgChannel = chatRepo.subscribeToMessages(
      jobId: jobId,
      onMessage: (newMsg) {
        if (!state.messages.any((m) => m.id == newMsg.id)) {
          state = state.copyWith(messages: [...state.messages, newMsg]);
        }
      },
    );

    _agreementChannel = agreementRepo.subscribeToAgreements(
      jobId: jobId,
      onUpdate: () async {
        final updated = await agreementRepo.getAgreements(jobId);
        state = state.copyWith(agreements: updated);
      },
    );
  }

  Future<void> sendMessage({
    required String senderId,
    required String body,
  }) async {
    try {
      final msg = await chatRepo.sendMessage(
        jobId: jobId,
        senderId: senderId,
        body: body,
      );
      if (!state.messages.any((m) => m.id == msg.id)) {
        state = state.copyWith(messages: [...state.messages, msg]);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> createPriceAgreement({
    required String customerId,
    required String providerId,
    required int amount,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      final agreement = await agreementRepo.createAgreement(
        jobId: jobId,
        customerId: customerId,
        providerId: providerId,
        amount: amount,
        paymentMethod: paymentMethod,
      );
      state = state.copyWith(agreements: [agreement, ...state.agreements]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    _agreementChannel?.unsubscribe();
    super.dispose();
  }
}

final chatRoomProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomNotifier, ChatRoomState, String>((ref, jobId) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final agreementRepo = ref.watch(agreementRepositoryProvider);
  return ChatRoomNotifier(
    jobId: jobId,
    chatRepo: chatRepo,
    agreementRepo: agreementRepo,
  );
});
