// Which screens the screenshot test renders, with the providers they need.
import 'package:eduapp/core/theme/app_theme.dart';
import 'package:eduapp/features/abiturient/screens/abiturient_dashboard.dart';
import 'package:eduapp/features/home/home_screen.dart';
import 'package:eduapp/features/home/home_shell.dart';
import 'package:eduapp/features/leaderboard/leaderboard_screen.dart';
import 'package:eduapp/features/profile/profile_screen.dart';
import 'package:eduapp/features/profile/settings_screen.dart';
import 'package:eduapp/features/subject/subject_screen.dart';
import 'package:eduapp/core/api/api_client.dart';
import 'package:eduapp/data/models.dart';
import 'package:eduapp/features/auth/screens/login_screen.dart';
import 'package:eduapp/features/auth/screens/register_screen.dart';
import 'package:eduapp/features/lesson/lesson_screen.dart';
import 'package:eduapp/features/offline/downloads_screen.dart';
import 'package:eduapp/features/onboarding/screens/onboarding_screen.dart';
import 'package:eduapp/features/onboarding/screens/profile_created_screen.dart';
import 'package:eduapp/features/onboarding/screens/role_selection_screen.dart';
import 'package:eduapp/features/onboarding/screens/splash_screen.dart';
import 'package:eduapp/features/onboarding/screens/survey_screen.dart';
import 'package:eduapp/offline/pack_store.dart';
import 'package:eduapp/offline/sync_service.dart';
import 'package:eduapp/features/test/result_screen.dart';
import 'package:eduapp/features/test/test_controller.dart';
import 'package:eduapp/features/test/test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fixtures.dart' as fx;

class ScreenShot {
  final String name;
  final Widget Function() builder;
  final List<Override> overrides;
  final Branch branch;
  final bool dark;
  final double height; // logical pixels; taller than a phone to see the whole page
  const ScreenShot(this.name, this.builder, {this.overrides = const [], this.branch = Branch.abiturient,
      this.dark = false, this.height = 852});
}

final _profileData = <Override>[
  progressProvider.overrideWith((ref) async => fx.progress),
  historyProvider.overrideWith((ref) async => fx.history),
  achievementsProvider.overrideWith((ref) async => fx.achievements),
];

final _home = <Override>[
  dashboardProvider.overrideWith((ref) async => fx.dashboard),
  clusterScreenProvider.overrideWith((ref, id) async => fx.clusterScreen),
];

/// A tab screen inside the app shell with the floating navigation bar.
Widget inShell(Widget screen, int index) => Scaffold(
      extendBody: true,
      body: screen,
      bottomNavigationBar: AppNavBar(index: index, onSelect: (_) {}),
    );

/// A test controller frozen in a given state (no network, no timer).
class _FrozenTest extends TestController {
  final TestState frozen;
  _FrozenTest(this.frozen);
  @override
  TestState build(TestLaunch launch) => frozen;
}

TestState _testState({required bool answered}) {
  final attempt = Attempt.fromJson({
    'id': 77, 'test_type': 'topic_test', 'reference_id': 5, 'is_timed': true, 'shows_feedback': true,
    'questions': [
      for (var i = 1; i <= 10; i++)
        {'id': i, 'question_type': 'single', 'max_points': 1, 'difficulty': 'medium',
          'text': 'Найдите значение выражения: 2 · log₃ 9 + √49 − 3².',
          'options': ['2', '4', '−2', '11']},
    ],
  });
  const ok = AnswerFeedback(answer: 0, isCorrect: true, points: 1, correctIndex: 0);
  const bad = AnswerFeedback(answer: 1, isCorrect: false, points: 0, correctIndex: 2);
  return TestState(
    attempt: attempt,
    index: 3,
    answers: {
      1: ok, 2: bad, 3: ok,
      if (answered)
        4: const AnswerFeedback(answer: 0, isCorrect: true, points: 1, correctIndex: 0,
            explanation: 'log₃ 9 = 2, √49 = 7, 3² = 9, значит 2 · 2 + 7 − 9 = 2.'),
    },
    marked: {4},
    score: answered ? 45 : 35,
    streak: answered ? 3 : 0,
    remaining: const Duration(minutes: 7, seconds: 42),
  );
}

List<Override> _test({required bool answered}) =>
    [testControllerProvider.overrideWith(() => _FrozenTest(_testState(answered: answered)))];

const _launch = TestLaunch(testType: 'topic_test', referenceId: 5, timed: true, title: 'Логарифмы');

/// Pack store where the first subject is already downloaded.
class _FakePacks extends PackStore {
  _FakePacks(super.api);
  @override
  Map<int, InstalledPack> get installed =>
      {1: InstalledPack(1, 'v3', 4200000, DateTime(2026, 9, 1), const {}, const {})};
}

final _manifest = PackManifest.fromJson({
  'packs': [
    for (final (id, ru, size, q) in [
      (1, 'Таджикский язык', 4200000, 820),
      (2, 'Математика', 9800000, 1450),
      (3, 'Химия', 6100000, 910),
      (4, 'Физика', 7300000, 1040),
    ])
      {'subject_id': id, 'title_ru': ru, 'title_tj': '', 'version': 'v3', 'size_bytes': size, 'questions': q},
  ],
});

final _lesson = Lesson.fromJson({
  'id': 12, 'topic_id': 5, 'title': 'Логарифмы и их свойства', 'check_questions_count': 4, 'completed': false,
  'content': '## Что такое логарифм\n\n'
      'Логарифм числа **b** по основанию **a** — это показатель степени, в которую нужно возвести a, '
      'чтобы получить b.\n\n'
      '> log₂ 8 = 3, потому что 2³ = 8\n\n'
      '## Основные свойства\n\n'
      '- log_a (xy) = log_a x + log_a y\n'
      '- log_a (x/y) = log_a x − log_a y\n'
      '- log_a xⁿ = n · log_a x\n\n'
      '## Пример\n\n'
      'Вычислите log₂ 48 − log₂ 3. По второму свойству получаем log₂ 16 = 4.\n',
});

final _clusters = [
  Cluster.fromJson({'id': 1, 'code': 'c1', 'title': 'Кластер 1 — естественные и технические науки', 'icon': 'engineering',
      'subjects': fx.subjects}),
  Cluster.fromJson({'id': 2, 'code': 'c2', 'title': 'Кластер 2 — экономика и география', 'icon': 'account_balance',
      'subjects': fx.subjects.take(3).toList()}),
  Cluster.fromJson({'id': 3, 'code': 'c3', 'title': 'Кластер 3 — филология и педагогика', 'icon': 'auto_stories',
      'subjects': fx.subjects.take(2).toList()}),
];

final screens = [
  ScreenShot('splash', () => const SplashScreen(), branch: Branch.neutral),
  ScreenShot('onboarding', () => const OnboardingScreen(), branch: Branch.neutral),
  ScreenShot('login', () => const LoginScreen(), branch: Branch.neutral),
  ScreenShot('register', () => const RegisterScreen(), branch: Branch.neutral, height: 1000),
  ScreenShot('role', () => const RoleSelectionScreen(), branch: Branch.neutral),
  ScreenShot('survey', () => const SurveyScreen(role: 'abiturient'), height: 1200, overrides: [
    clustersProvider.overrideWith((ref) async => _clusters),
    regionsProvider.overrideWith((ref) async => const <Region>[]),
  ]),
  ScreenShot('survey_school', () => const SurveyScreen(role: 'schoolboy'), branch: Branch.schoolboy),
  ScreenShot('profile_created', () => const ProfileCreatedScreen()),
  ScreenShot('lesson', () => const LessonScreen(lessonId: 12), height: 1200,
      overrides: [lessonProvider.overrideWith((ref, id) async => _lesson)]),
  ScreenShot('downloads', () => const DownloadsScreen(), overrides: [
    packManifestProvider.overrideWith((ref) async => _manifest),
    packStoreProvider.overrideWith((ref) => _FakePacks(ref.watch(apiClientProvider))),
    pendingSyncProvider.overrideWith((ref) => 2),
  ]),
  ScreenShot('test', () => const TestScreen(launch: _launch), overrides: _test(answered: false)),
  ScreenShot('test_feedback', () => const TestScreen(launch: _launch), overrides: _test(answered: true)),
  ScreenShot('profile', () => inShell(const ProfileScreen(), 2), overrides: _profileData),
  ScreenShot('profile_full', () => const ProfileScreen(), overrides: _profileData, height: 2000),
  ScreenShot('profile_dark', () => const ProfileScreen(), overrides: _profileData, dark: true),
  ScreenShot('home', () => inShell(const HomeScreen(), 0), overrides: _home),
  ScreenShot('home_full', () => const HomeScreen(), overrides: _home, height: 1900),
  ScreenShot('rating', () => inShell(const LeaderboardScreen(), 1),
      overrides: [leaderboardProvider.overrideWith((ref, key) async => fx.leaderboard)]),
  ScreenShot('settings', () => const SettingsScreen()),
  ScreenShot('result', () => ResultScreen(attemptId: 501, initial: fx.result), height: 2100),
  ScreenShot('subject', () => const SubjectScreen(subjectId: 2),
      overrides: [subjectTreeProvider.overrideWith((ref, id) async => fx.subjectTree)], height: 1400),
];
