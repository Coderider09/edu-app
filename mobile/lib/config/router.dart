import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/home/home_screen.dart';
import '../features/home/home_shell.dart';
import '../features/leaderboard/leaderboard_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/profile_created_screen.dart';
import '../features/onboarding/screens/role_selection_screen.dart';
import '../features/onboarding/screens/survey_screen.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/subject/subject_screen.dart';
import '../features/test/result_screen.dart';
import '../features/test/test_screen.dart';
import '../data/models.dart';
import 'app_config.dart';

/// Slide + fade transition used for every pushed screen.
Page<void> _page(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondary, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) == true) return child;
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Bridges session changes to GoRouter's refreshListenable.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

const _publicPaths = {'/onboarding', '/login', '/register'};
const _onboardingPaths = {'/role', '/survey'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      final inOnboarding = _onboardingPaths.any(path.startsWith);

      switch (session.status) {
        case SessionStatus.loading:
        case SessionStatus.error:
          return path == '/splash' ? null : '/splash';
        case SessionStatus.loggedOut:
          if (_publicPaths.contains(path)) return null;
          return AppConfig.onboardingSeen ? '/login' : '/onboarding';
        case SessionStatus.needsRole:
          return inOnboarding ? null : '/role';
        case SessionStatus.ready:
          // /survey stays reachable to add a second role from the settings
          if (path == '/splash' || path == '/role' || _publicPaths.contains(path)) return '/home';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (c, s) => _page(s, const SplashScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
      GoRoute(path: '/login', pageBuilder: (c, s) => _page(s, const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (c, s) => _page(s, const RegisterScreen())),
      GoRoute(path: '/role', pageBuilder: (c, s) => _page(s, const RoleSelectionScreen())),
      GoRoute(
        path: '/survey/:role',
        pageBuilder: (c, s) => _page(
          s,
          SurveyScreen(role: s.pathParameters['role']!, mode: SurveyMode.values.byName(s.uri.queryParameters['mode'] ?? 'first')),
        ),
      ),
      GoRoute(path: '/profile-created', pageBuilder: (c, s) => _page(s, const ProfileCreatedScreen())),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/rating', builder: (c, s) => const LeaderboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/subject/:id',
        pageBuilder: (c, s) => _page(s, SubjectScreen(subjectId: int.parse(s.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/lesson/:id',
        pageBuilder: (c, s) => _page(s, LessonScreen(lessonId: int.parse(s.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/test/:type',
        pageBuilder: (c, s) {
          final q = s.uri.queryParameters;
          return _page(
            s,
            TestScreen(
              launch: TestLaunch(
                testType: s.pathParameters['type']!,
                referenceId: int.tryParse(q['ref'] ?? ''),
                timed: q['timed'] == '1',
                questionCount: int.tryParse(q['count'] ?? ''),
                title: q['title'],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/result/:attemptId',
        pageBuilder: (c, s) => _page(
          s,
          ResultScreen(
            attemptId: int.parse(s.pathParameters['attemptId']!),
            initial: s.extra is AttemptResult ? s.extra as AttemptResult : null,
          ),
        ),
      ),
      GoRoute(path: '/settings', pageBuilder: (c, s) => _page(s, const SettingsScreen())),
    ],
  );
});
