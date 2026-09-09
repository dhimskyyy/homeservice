import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_provider.dart';
import '../core/supabase_client.dart';
import '../shared/models/job_models.dart';

final _notifRepo = Provider<SupabaseClient?>((ref) {
  try {
    return ref.watch(supabaseClientProvider);
  } catch (_) {
    return null;
  }
});

class NotificationsState {
  final List<AppNotificationItem> items;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotificationItem>? items,
    bool? isLoading,
    String? error,
  }) {
    final nextItems = items ?? this.items;
    return NotificationsState(
      items: nextItems,
      unreadCount: nextItems.where((n) => !n.read).length,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  RealtimeChannel? _channel;
  final Ref _ref;

  NotificationsNotifier(this._ref) : super(const NotificationsState(isLoading: true)) {
    _init();
  }

  SupabaseClient? get _client => _ref.read(_notifRepo);

  Future<void> _init() async {
    final user = _ref.read(authProvider).user;
    final c = _client;
    if (user == null || c == null) {
      state = const NotificationsState();
      return;
    }

    try {
      final data = await c
          .from('app_notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      state = state.copyWith(
        items: (data as List)
            .map((e) => AppNotificationItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }

    // Realtime subscription
    _channel = c
        .channel('public:app_notifications:user=${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final notif = AppNotificationItem.fromJson(record);
              if (!state.items.any((n) => n.id == notif.id)) {
                state = state.copyWith(items: [notif, ...state.items]);
              }
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              final updated = AppNotificationItem.fromJson(record);
              state = state.copyWith(
                items: state.items
                    .map((n) => n.id == updated.id ? updated : n)
                    .toList(),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notifId) async {
    final user = _ref.read(authProvider).user;
    final c = _client;
    if (user == null || c == null) return;

    try {
      await c
          .from('app_notifications')
          .update({'read': true})
          .eq('id', notifId)
          .eq('user_id', user.id);

      state = state.copyWith(
        items: state.items.map((n) => n.id == notifId ? n.copyWith(read: true) : n).toList(),
      );
    } catch (_) {}
  }

  Future<void> deleteNotification(String notifId) async {
    final user = _ref.read(authProvider).user;
    final c = _client;
    if (user == null || c == null) return;

    try {
      await c
          .from('app_notifications')
          .delete()
          .eq('id', notifId)
          .eq('user_id', user.id);

      state = state.copyWith(
        items: state.items.where((n) => n.id != notifId).toList(),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final user = _ref.read(authProvider).user;
    final c = _client;
    if (user == null || c == null) return;

    final unread = state.items.where((n) => !n.read).toList();
    if (unread.isEmpty) return;

    try {
      await c
          .from('app_notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);

      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(read: true)).toList(),
      );
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _init();
  }

  @override
  void dispose() {
    _disposeChannel();
    super.dispose();
  }

  Future<void> _disposeChannel() async {
    final channel = _channel;
    _channel = null;
    final c = _client;
    if (channel != null && c != null) {
      try {
        await channel.unsubscribe();
        await c.removeChannel(channel);
      } catch (_) {}
    }
  }
}

final notificationsProvider =
    StateNotifierProvider.autoDispose<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});
