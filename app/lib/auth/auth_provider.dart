import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthUiState>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return AuthNotifier(client: client);
  } catch (_) {
    return AuthNotifier(client: null);
  }
});

class AuthUiState {
  final User? user;
  final bool isLoading;
  final String? error;
  final String? message;

  const AuthUiState({
    this.user,
    this.isLoading = false,
    this.error,
    this.message,
  });

  static const Object _unset = Object();

  AuthUiState copyWith({
    Object? user = _unset,
    bool? isLoading,
    Object? error = _unset,
    Object? message = _unset,
  }) {
    return AuthUiState(
      user: identical(user, _unset) ? this.user : user as User?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthUiState> {
  final SupabaseClient? client;
  StreamSubscription<AuthState>? _authSub;

  AuthNotifier({this.client}) : super(const AuthUiState()) {
    if (client != null) {
      _init();
    }
  }

  Future<void> _init() async {
    final c = client;
    if (c == null) return;

    _authSub = c.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(user: session.user, error: null);
      } else {
        state = state.copyWith(user: null, message: null);
      }
    });

    final session = c.auth.currentSession;
    if (session != null) {
      state = state.copyWith(user: session.user);
    }
  }

  String _mapAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        return 'Email atau kata sandi salah.';
      }
      if (msg.contains('user already registered')) {
        return 'Email ini sudah terdaftar.';
      }
      if (msg.contains('password should be at least')) {
        return 'Kata sandi minimal 6 karakter.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Email belum dikonfirmasi. Silakan periksa kotak masuk Anda.';
      }
      return error.message;
    }
    return error.toString();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    Map<String, dynamic> metadata = const {},
  }) async {
    final c = client;
    if (c == null) {
      return true;
    }
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final dataPayload = <String, dynamic>{
        'full_name': fullName.trim(),
        ...metadata,
      };

      final response = await c.auth.signUp(
        email: email.trim(),
        password: password,
        data: dataPayload,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Registrasi gagal. Silakan coba lagi.');
      }

      final hasActiveSession = response.session != null;

      state = state.copyWith(
        user: response.session?.user,
        isLoading: false,
        message: !hasActiveSession
            ? 'Akun berhasil dibuat. Silakan cek email Anda untuk konfirmasi jika diperlukan.'
            : null,
      );

      return hasActiveSession;
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final c = client;
    if (c == null) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final response = await c.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = state.copyWith(user: response.user, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final c = client;
    if (c == null) {
      state = const AuthUiState();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      await c.auth.signOut();
      state = const AuthUiState();
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
