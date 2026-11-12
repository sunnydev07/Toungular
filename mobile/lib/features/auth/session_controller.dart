import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/session_manager.dart';
import '../../shared/models/learning_models.dart';
import 'auth_repository.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

enum SessionStatus { loading, signedOut, signedIn }

class SessionState {
  const SessionState._({required this.status, this.session});

  const SessionState.loading() : this._(status: SessionStatus.loading);
  const SessionState.signedOut() : this._(status: SessionStatus.signedOut);
  const SessionState.signedIn(LearnerSession value)
    : this._(status: SessionStatus.signedIn, session: value);

  final SessionStatus status;
  final LearnerSession? session;

  bool get isLoading => status == SessionStatus.loading;
  bool get isSignedIn => status == SessionStatus.signedIn;
  bool get requiresOnboarding =>
      isSignedIn && (session?.profile.needsOnboarding ?? true);
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final sessions = ref.read(sessionManagerProvider);
    final subscription = sessions.expired.listen((_) {
      state = const SessionState.signedOut();
    });
    ref.onDispose(subscription.cancel);
    scheduleMicrotask(_restore);
    return const SessionState.loading();
  }

  Future<void> _restore() async {
    try {
      final restored = await ref.read(sessionManagerProvider).restore();
      state = restored == null
          ? const SessionState.signedOut()
          : SessionState.signedIn(restored);
    } catch (_) {
      state = const SessionState.signedOut();
    }
  }

  void accept(LearnerSession session) {
    ref.read(sessionManagerProvider).accept(session);
    state = SessionState.signedIn(session);
  }

  void updateProfile(LearnerProfile profile) {
    final current = state.session;
    if (current != null) {
      final next = current.withProfile(profile);
      ref.read(sessionManagerProvider).accept(next);
      state = SessionState.signedIn(next);
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SessionState.signedOut();
  }
}
