import 'package:eduapp/core/l10n/strings.dart';
import 'package:eduapp/data/models.dart';
import 'package:eduapp/features/test/test_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Attempt parses questions and hidden exam feedback', () {
    final attempt = Attempt.fromJson({
      'id': 5,
      'test_type': 'exam_test',
      'reference_id': 1,
      'status': 'in_progress',
      'is_timed': true,
      'started_at': '2026-09-23T10:00:00Z',
      'expires_at': '2026-09-23T10:30:00Z',
      'server_time': '2026-09-23T10:01:00Z',
      'shows_feedback': false,
      'questions': [
        {'id': 1, 'text': '2+2?', 'image_url': null, 'options': ['3', '4'], 'difficulty': 'easy',
         'subject_id': 2, 'is_marked': true},
      ],
      'answers': [
        {'question_id': 1, 'selected_option_index': 1, 'is_correct': null, 'correct_option_index': null},
      ],
      'score': 0,
      'answer_streak': 0,
    });
    expect(attempt.showsFeedback, isFalse);
    expect(attempt.questions.single.isMarked, isTrue);
    expect(attempt.answers[1]!.selectedIndex, 1);
    expect(attempt.answers[1]!.isCorrect, isNull);
    expect(attempt.expiresAt!.difference(attempt.serverTime).inMinutes, 29);
  });

  test('Level exposes the next level code', () {
    final level = Level.fromJson({'number': 2, 'code': 'learner', 'min_points': 500, 'next_level_points': 2000,
      'progress': 0.1});
    expect(level.nextCode, 'advanced');
    expect(Level.fromJson({'number': 5, 'code': 'master', 'min_points': 10000, 'progress': 1}).nextCode, isNull);
  });

  test('Strings are available in both languages with substitution', () {
    const ru = Strings('ru');
    const tj = Strings('tj');
    expect(ru['login'], 'Войти');
    expect(tj['login'], 'Воридшавӣ');
    expect(ru.f('question_n_of', {'n': 3, 'total': 10}), 'Вопрос 3 из 10');
    expect(tj.level('master'), 'Устод');
    expect(ru['missing_key'], 'missing_key');
  });

  test('TestLaunch equality drives provider identity', () {
    const a = TestLaunch(testType: 'topic_test', referenceId: 1, title: 'A');
    const b = TestLaunch(testType: 'topic_test', referenceId: 1, title: 'B');
    expect(a, b);
    expect(a.storageKey, 'attempt_topic_test_1');
  });

  test('Matching and numeric questions and feedback', () {
    final q = Question.fromJson({
      'id': 7,
      'question_type': 'matching',
      'text': '',
      'image_url': '/static/ntc/math/matching-0-3.webp',
      'options': ['1', '2', '3', '4', '5'],
      'matching_left': ['A', 'B', 'C', 'D'],
      'max_points': 4,
    });
    expect(q.type, QuestionType.matching);
    expect(q.optionsInImage, isTrue);
    final fb = AnswerFeedback.fromJson(
        {'is_correct': false, 'points': 2, 'correct_answer': [4, 1, 2, 0], 'points_awarded': 20}, [4, 1, 0, 2]);
    expect(fb.matching, [4, 1, 0, 2]);
    expect(fb.correctMatching, [4, 1, 2, 0]);
    expect(fb.points, 2);
    expect(fb.selectedIndex, isNull);

    final numeric = Question.fromJson({'id': 8, 'question_type': 'numeric', 'text': '2+2', 'options': []});
    expect(numeric.type, QuestionType.numeric);
    final result = AttemptResult.fromJson({
      'attempt_id': 1,
      'mmt_score': 376,
      'mmt_max': 500,
      'subjects': [
        {'title': 'Математика', 'position': 2, 'points': 28, 'max_points': 40, 'score': 122.5, 'max_score': 175},
      ],
      'review': [],
      'new_achievements': [],
    });
    expect(result.mmtMax, 500);
    expect(result.subjects.single.score, 122.5);
  });
}
