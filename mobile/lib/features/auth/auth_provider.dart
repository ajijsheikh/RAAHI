import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Set once in main() from --dart-define values.
final supabaseEnabledProvider = Provider<bool>((ref) => false);

enum AuthStatus { unknown, authenticated, unauthenticated, demoMode }

class RaahiAuthState {
  const RaahiAuthState({
    required this.status,
    this.email,
    this.errorMessage,
  });

  final AuthStatus status;
  final String? email;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isDemoMode => status == AuthStatus.demoMode;
}

class AuthNotifier extends StateNotifier<RaahiAuthState> {
  AuthNotifier({required bool supabaseEnabled})
      : super(RaahiAuthState(
          status: supabaseEnabled
              ? AuthStatus.unknown
              : AuthStatus.demoMode,
        )) {
    if (!supabaseEnabled) return;

    _sync(Supabase.instance.client.auth.currentSession);
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => _sync(data.session),
    );
  }

  StreamSubscription<dynamic>? _subscription;

  void _sync(Session? session) {
    if (!mounted) return;
    state = session == null
        ? const RaahiAuthState(status: AuthStatus.unauthenticated)
        : RaahiAuthState(
            status: AuthStatus.authenticated,
            email: session.user.email,
          );
  }

  Future<bool> signIn(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return true; // state updates via onAuthStateChange
    } on AuthException catch (e) {
      state = RaahiAuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      // Email confirmation may be required depending on project settings.
      state = const RaahiAuthState(
        status: AuthStatus.unauthenticated,
        errorMessage:
            'Account created. Check your inbox to confirm, then sign in.',
      );
      return false;
    } on AuthException catch (e) {
      state = RaahiAuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {/* already signed out */}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, RaahiAuthState>((ref) {
  return AuthNotifier(supabaseEnabled: ref.watch(supabaseEnabledProvider));
});
