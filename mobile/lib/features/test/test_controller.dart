import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_config.dart';
import '../../core/api/api_client.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../offline/offline_testing.dart';
import '../../offline/sync_service.dart';
import '../auth/session_controller.dart';

/// What to start: test type + reference (topic/section/subject/exam/lesson id).
class TestLaunch {
  final String testType;
  final int? referenceId;
  final bool timed;
  final int? questionCount;
  final String? title;
  const TestLaunch({required this.testType, this.referenceId, this.timed = false, this.questionCount, this.title});

  String get storageKey => 'attempt_${testType}_${referenceId ?? 0}';

  @override
  bool operator ==(Object other) =>
      other is TestLaunch &&
      other.testType == testType &&
      other.referenceId == referenceId &&
      other.timed == timed &&
      other.questionCount == questionCount;

  @override
  int get hashCode => Object.hash(testType, referenceId, timed, questionCount);
}

enum TestEvent { none, correct, partial, wrong, saved, queued }

class TestState {
  final Attempt? attempt;
  final int index;
  final Map<int, AnswerFeedback> answers;
  final Set<int> marked;
  final int score;
  final int streak;
  final Duration? remaining;
  final bool submitting;
  final bool finishing;
  final Object? error;
  final String? finishError;
  final AttemptResult? result;
  final TestEvent event;
  final int eventTick; // increments on every answer to trigger animations
  final int lastPoints;
  final bool lastStreakBonus;

  const TestState({
    this.attempt,
    this.index = 0,
    this.answers = const {},
    this.marked = const {},
    this.score = 0,
    this.streak = 0,
    this.remaining,
    this.submitting = false,
    this.finishing = false,
    this.error,
    this.finishError,
    this.result,
    this.event = TestEvent.none,
    this.eventTick = 0,
    this.lastPoints = 0,
    this.lastStreakBonus = false,
  });

  bool get loading => attempt == null && error == null;
  List<Question> get questions => attempt?.questions ?? const [];
  Question? get current => index < questions.length ? questions[index] : null;
  AnswerFeedback? get currentAnswer => current == null ? null : answers[current!.id];
  bool get showsFeedback => attempt?.showsFeedback ?? true;
  bool get allAnswered => questions.isNotEmpty && answers.length >= questions.length;

  TestState copyWith({
    Attempt? attempt,
    int? index,
    Map<int, AnswerFeedback>? answers,
    Set<int>? marked,
    int? score,
    int? streak,
    Duration? remaining,
    bool? submitting,
    bool? finishing,
    Object? error,
    String? finishError,
    bool clearFinishError = false,
    AttemptResult? result,
    TestEvent? event,
    int? eventTick,
    int? lastPoints,
    bool? lastStreakBonus,
  }) =>
      TestState(
        attempt: attempt ?? this.attempt,
        index: index ?? this.index,
        answers: answers ?? this.answers,
        marked: marked ?? this.marked,
        score: score ?? this.score,
        streak: streak ?? this.streak,
        remaining: remaining ?? this.remaining,
        submitting: submitting ?? this.submitting,
        finishing: finishing ?? this.finishing,
        error: error ?? this.error,
        finishError: clearFinishError ? null : (finishError ?? this.finishError),
        result: result ?? this.result,
        event: event ?? this.event,
        eventTick: eventTick ?? this.eventTick,
        lastPoints: lastPoints ?? this.lastPoints,
        lastStreakBonus: lastStreakBonus ?? this.lastStreakBonus,
      );
}

/// Runs one attempt: loading/resuming, answering (queued offline), timer and finishing.
///
/// When the packs of the test are downloaded the attempt runs on the device ([OfflineTesting]):
/// instant feedback without internet, the result is uploaded later by [SyncService].
class TestController extends AutoDisposeFamilyNotifier<TestState, TestLaunch> {
  Timer? _timer;
  Duration _clockOffset = Duration.zero;
  bool _local = false;

  Box<String> get _box => Hive.box<String>(AppConfig.attemptsBox);
  TestingRepository get _repo => ref.read(testingRepositoryProvider);
  OfflineTesting get _offline => ref.read(offlineTestingProvider);

  String get _lang => ref.read(sessionProvider).profile?.contentLanguage ?? 'tj';

  @override
  TestState build(TestLaunch launch) {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(load);
    return const TestState();
  }

  String get _pendingKey => 'pending_${state.attempt?.id}';

  Future<void> load() async {
    state = const TestState();
    Map<String, dynamic>? raw;
    try {
      raw = await _offline.start(arg.testType, arg.referenceId,
          lang: _lang, timed: arg.timed, questionCount: arg.questionCount);
    } catch (_) {
      raw = null; // a broken pack must not block the test: fall back to the server
    }
    _local = raw != null;
    if (_local) {
      _show(Attempt.fromJson(raw!));
      return;
    }
    try {
      raw = await _repo.start(arg.testType,
          referenceId: arg.referenceId, timed: arg.timed, questionCount: arg.questionCount);
      await _box.put(arg.storageKey, jsonEncode(raw));
    } on ApiException catch (e) {
      // Offline: resume the attempt saved on this device, if any
      final saved = e.offline ? _box.get(arg.storageKey) : null;
      if (saved == null) {
        state = TestState(error: e);
        return;
      }
      raw = Map<String, dynamic>.from(jsonDecode(saved));
    }
    _show(Attempt.fromJson(raw));
  }

  void _show(Attempt attempt) {
    _clockOffset = attempt.serverTime.difference(DateTime.now());

    final answers = Map<int, AnswerFeedback>.from(attempt.answers);
    for (final p in _pending(attempt.id)) {
      answers[p.$1] = AnswerFeedback(answer: p.$2, pending: true);
    }
    final firstOpen = attempt.questions.indexWhere((q) => !answers.containsKey(q.id));
    state = TestState(
      attempt: attempt,
      answers: answers,
      marked: {for (final q in attempt.questions) if (q.isMarked) q.id},
      index: firstOpen < 0 ? 0 : firstOpen,
      score: attempt.score,
      streak: attempt.answerStreak,
    );
    _startTimer();
    if (!_local) unawaited(_flushPending());
  }

  void _startTimer() {
    _timer?.cancel();
    final expires = state.attempt?.expiresAt;
    if (expires == null) return;
    void tick() {
      final left = expires.difference(DateTime.now().add(_clockOffset));
      state = state.copyWith(remaining: left.isNegative ? Duration.zero : left);
      if (left <= Duration.zero) {
        _timer?.cancel();
        finish();
      }
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  List<(int, Object)> _pending(int attemptId) {
    final raw = _box.get('pending_$attemptId');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) {
      final value = e[1];
      return (e[0] as int, value is List ? List<int>.from(value) : value as Object);
    }).toList();
  }

  Future<void> _savePending(List<(int, Object)> items) async {
    if (items.isEmpty) {
      await _box.delete(_pendingKey);
    } else {
      await _box.put(_pendingKey, jsonEncode([for (final p in items) [p.$1, p.$2]]));
    }
  }

  /// Sends answers given offline. Returns true when nothing is left in the queue.
  Future<bool> _flushPending() async {
    final attempt = state.attempt;
    if (attempt == null || _local) return true;
    final queue = _pending(attempt.id);
    while (queue.isNotEmpty) {
      final (qid, option) = queue.first;
      try {
        final r = await _repo.answer(attempt.id, qid, option);
        final answers = Map<int, AnswerFeedback>.from(state.answers)..[qid] = AnswerFeedback.fromJson(r, option);
        state = state.copyWith(answers: answers, score: r['attempt_score'] ?? state.score);
      } on ApiException catch (e) {
        if (e.offline) {
          await _savePending(queue);
          return false;
        }
        // 409 (already answered / time is up) — nothing more to send for it
      }
      queue.removeAt(0);
    }
    await _savePending(queue);
    return true;
  }

  /// [option]: option index (single), option indices for A–D (matching) or digits (numeric).
  Future<void> answer(Object option) async {
    final attempt = state.attempt;
    final q = state.current;
    if (attempt == null || q == null || state.answers.containsKey(q.id) || state.submitting) return;
    state = state.copyWith(submitting: true);
    try {
      await _flushPending();
      final r = _local ? await _offline.answer(attempt.id, q.id, option) : await _repo.answer(attempt.id, q.id, option);
      final fb = AnswerFeedback.fromJson(r, option);
      final answers = Map<int, AnswerFeedback>.from(state.answers)..[q.id] = fb;
      state = state.copyWith(
        answers: answers,
        submitting: false,
        score: r['attempt_score'] ?? state.score,
        streak: r['answer_streak'] ?? state.streak,
        event: fb.isCorrect == null
            ? TestEvent.saved
            : (fb.isCorrect! ? TestEvent.correct : ((fb.points ?? 0) > 0 ? TestEvent.partial : TestEvent.wrong)),
        eventTick: state.eventTick + 1,
        lastPoints: fb.pointsAwarded,
        lastStreakBonus: fb.streakBonus,
      );
    } on ApiException catch (e) {
      if (e.offline) {
        final queue = _pending(attempt.id)..add((q.id, option));
        await _savePending(queue);
        final answers = Map<int, AnswerFeedback>.from(state.answers)
          ..[q.id] = AnswerFeedback(answer: option, pending: true);
        state = state.copyWith(
            answers: answers, submitting: false, event: TestEvent.queued, eventTick: state.eventTick + 1);
      } else if (e.statusCode == 409) {
        state = state.copyWith(submitting: false);
        await finish(); // time is up or attempt closed
      } else {
        state = state.copyWith(submitting: false, finishError: e.message);
      }
    }
    if (!state.showsFeedback) {
      // Exam mode: move on right away, like on paper
      await Future<void>.delayed(const Duration(milliseconds: 250));
      next();
    }
  }

  void next() {
    final qs = state.questions;
    if (qs.isEmpty) return;
    // Next unanswered question after the current one, wrapping around
    for (var step = 1; step <= qs.length; step++) {
      final i = (state.index + step) % qs.length;
      if (!state.answers.containsKey(qs[i].id)) {
        state = state.copyWith(index: i, event: TestEvent.none);
        return;
      }
    }
    if (state.index < qs.length - 1) state = state.copyWith(index: state.index + 1, event: TestEvent.none);
  }

  void goTo(int index) => state = state.copyWith(index: index, event: TestEvent.none);

  Future<void> toggleMark() async {
    final q = state.current;
    if (q == null) return;
    final marked = Set<int>.from(state.marked);
    final nowMarked = !marked.contains(q.id);
    nowMarked ? marked.add(q.id) : marked.remove(q.id);
    state = state.copyWith(marked: marked);
    try {
      await _repo.mark(q.id, nowMarked);
    } on ApiException catch (e) {
      if (e.offline) {
        await ref.read(syncServiceProvider).queueMark(q.id, nowMarked); // sent with the next sync
        return;
      }
      final revert = Set<int>.from(state.marked);
      nowMarked ? revert.remove(q.id) : revert.add(q.id);
      state = state.copyWith(marked: revert);
    } catch (_) {
      final revert = Set<int>.from(state.marked);
      nowMarked ? revert.remove(q.id) : revert.add(q.id);
      state = state.copyWith(marked: revert);
    }
  }

  Future<void> finish() async {
    final attempt = state.attempt;
    if (attempt == null || state.finishing || state.result != null) return;
    state = state.copyWith(finishing: true, clearFinishError: true);
    _timer?.cancel();
    if (_local) {
      final result = AttemptResult.fromJson(await _offline.finish(attempt.id));
      state = state.copyWith(finishing: false, result: result);
      unawaited(ref.read(syncServiceProvider).run());
      return;
    }
    if (!await _flushPending()) {
      state = state.copyWith(finishing: false, finishError: 'offline');
      return;
    }
    try {
      final result = await _repo.finish(attempt.id);
      await _box.delete(arg.storageKey);
      await _box.delete(_pendingKey);
      state = state.copyWith(finishing: false, result: result);
    } on ApiException catch (e) {
      state = state.copyWith(finishing: false, finishError: e.offline ? 'offline' : e.message);
    }
  }
}

final testControllerProvider =
    NotifierProvider.autoDispose.family<TestController, TestState, TestLaunch>(TestController.new);
