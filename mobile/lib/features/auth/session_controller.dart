import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/session_store.dart';
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
    scheduleMicrotask(() { _restore(); });
    return const SessionState.loading();
  }

  Future<void> _restore() async {
    final store = ref.read(sessionStoreProvider);
    LearnerSession? saved;
    try {
      saved = await store.readSession();
    } catch (_) {
      state = const SessionState.signedOut();
      return;
    }
    if (saved == null) {
      state = const SessionState.signedOut();
      return;
    }

    try {
      final refreshed =
          await ref.read(authRepositoryProvider).refresh(saved.refreshToken);
      state = SessionState.signedIn(refreshed);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await store.clearSession();
        state = const SessionState.signedOut();
      } else {
        state = SessionState.signedIn(saved);
      }
    } catch (_) {
      state = SessionState.signedIn(saved);
    }
  }

  void accept(LearnerSession session) {
    state = SessionState.signedIn(session);
  }

  void updateProfile(LearnerProfile profile) {
    final current = state.session;
    if (current != null) {
      state = SessionState.signedIn(current.withProfile(profile));
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SessionState.signedOut();
  }
}
