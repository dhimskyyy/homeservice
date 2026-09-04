import 'dart:async';
import 'dart:typed_data';
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
    String? mediaUrl,
  }) async {
    final c = client;
    if (c == null) {
      throw Exception('Supabase client tidak diinisialisasi');
    }

    final payload = <String, dynamic>{
      'job_id': jobId,
      'sender_id': senderId,
      'body': body.trim(),
    };
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      payload['media_url'] = mediaUrl;
    }

    final data = await c
        .from('messages')
        .insert(payload)
        .select('*, profiles:sender_id(full_name)')
        .single();

    return ChatMessage.fromJson(data);
  }

  Future<String> uploadChatMedia({
    required String jobId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase client belum diinisialisasi');

    final path = '$jobId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await c.storage.from('chat-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return c.storage.from('chat-attachments').getPublicUrl(path);
  }

  Future<void> markMessagesAsRead({
    required String jobId,
    required String currentUserId,
  }) async {
    final c = client;
    if (c == null) return;

    await c
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('job_id', jobId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
  }

  RealtimeChannel? subscribeToMessages({
    required String jobId,
    required void Function(ChatMessage message) onMessage,
    void Function(ChatMessage updatedMessage)? onMessageUpdated,
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_id',
            value: jobId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty && onMessageUpdated != null) {
              onMessageUpdated(ChatMessage.fromJson(record));
            }
          },
        )
        .subscribe();

    return channel;
  }
}
