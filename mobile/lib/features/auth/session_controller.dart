import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/api/api_client.dart';
import '../../core/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

enum SessionStatus { loading, loggedOut, needsRole, ready, error }

class SessionState {
  final SessionStatus status;
  final Profile? profile;
  const SessionState(this.status, [this.profile]);
}

/// Who is signed in and whether onboarding (role selection) is complete. Drives routing.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.read(apiClientProvider).onSessionExpired = () => logout();
    Future.microtask(restore);
    return const SessionState(SessionStatus.loading);
  }

  Future<void> restore() async {
    if (await AppConfig.getAccessToken() == null) {
      state = const SessionState(SessionStatus.loggedOut);
      return;
    }
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).me();
      _apply(profile);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await logout();
      } else if (state.profile == null) {
        state = const SessionState(SessionStatus.error);
      }
    }
  }

  void _apply(Profile profile) {
    ref.read(branchProvider.notifier).state = switch (profile.activeRole) {
      'abiturient' => Branch.abiturient,
      'schoolboy' => Branch.schoolboy,
      _ => Branch.neutral,
    };
    state = SessionState(profile.roles.isEmpty ? SessionStatus.needsRole : SessionStatus.ready, profile);
  }

  /// Profile returned by any profile-changing call.
  void setProfile(Profile profile) => _apply(profile);

  Future<void> login(String login, String password) async {
    await ref.read(authRepositoryProvider).login(login, password);
    await _afterSignIn();
  }

  Future<void> register({required String name, required String password, String? email, String? phone}) async {
    await ref.read(authRepositoryProvider).register(
          name: name,
          password: password,
          email: email,
          phone: phone,
          language: ref.read(settingsProvider).language,
        );
    await _afterSignIn();
  }

  Future<void> google(String idToken) async {
    await ref.read(authRepositoryProvider).google(idToken, ref.read(settingsProvider).language);
    await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    final profile = await ref.read(profileRepositoryProvider).me();
    await ref.read(settingsProvider.notifier).applyFromProfile(
          language: profile.language,
          theme: profile.theme,
          notifications: profile.notificationsEnabled,
        );
    _apply(profile);
  }

  Future<void> logout() async {
    await AppConfig.clearSession();
    ref.read(branchProvider.notifier).state = Branch.neutral;
    state = const SessionState(SessionStatus.loggedOut);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
