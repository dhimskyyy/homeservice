import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthUiState>((ref) {
  return AuthNotifier();
});

class AuthUiState {
  final User? user;
  final bool isLoading;
  final String? error;
  final String? message;

  const AuthUiState({this.user, this.isLoading = false, this.error, this.message});

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
  AuthNotifier() : super(const AuthUiState()) {
    _init();
  }

  StreamSubscription<AuthState>? _authSub;

  Future<void> _init() async {
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(user: session.user, error: null);
      } else {
        state = state.copyWith(user: null, message: null);
      }
    });
    final session = supabase.auth.currentSession;
    if (session != null) {
      state = state.copyWith(user: session.user);
    }
  }

  Future<void> signUp(String email, String password, String fullName, bool isCustomer) async {
    state = state.copyWith(isLoading: true, error: null, message: null);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'com.beres.app://',
        data: {
          'full_name': fullName,
          'is_customer': isCustomer,
          'is_tukang': !isCustomer,
        },
      );
      final user = response.user;
      if (user == null) throw Exception('Registrasi gagal');

      // Profile is auto-created by the handle_new_user DB trigger.
      // If email confirmation is required, response.session is null.
      state = state.copyWith(
        user: response.session?.user,
        isLoading: false,
        message: response.session == null
            ? 'Link verifikasi telah dikirim ke email Anda. Silakan cek email untuk mengaktifkan akun.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(user: response.user, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = state.copyWith(user: null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
