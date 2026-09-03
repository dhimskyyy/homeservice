import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/models/job_models.dart';

class ChatRepository {
  final SupabaseClient? client;

  ChatRepository({this.client});

  Future<List<ChatMessage>> getMessages(String jobId) async {
    final c = client;
    if (c == null) return [];

    final data = await c
        .from('messages')
        .select('*, profiles:sender_id(full_name)')
        .eq('job_id', jobId)
        .order('created_at', ascending: true);

    return (data as List).map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({
    required String jobId,
    required String senderId,
    required String body,
  }) async {
    final c = client;
    if (c == null) {
      throw Exception('Supabase client tidak diinisialisasi');
    }

    final data = await c
        .from('messages')
        .insert({
          'job_id': jobId,
          'sender_id': senderId,
          'body': body.trim(),
        })
        .select('*, profiles:sender_id(full_name)')
        .single();

    return ChatMessage.fromJson(data);
  }

  RealtimeChannel? subscribeToMessages({
    required String jobId,
    required void Function(ChatMessage message) onMessage,
  }) {
    final c = client;
    if (c == null) return null;

    final channel = c.channel('public:messages:job=$jobId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: jobId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onMessage(ChatMessage.fromJson(record));
            }
          },
        )
        .subscribe();

    return channel;
  }
}
