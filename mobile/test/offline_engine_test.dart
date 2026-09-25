import 'dart:math';

import 'package:eduapp/offline/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _q(int id, String type, {int? topic, int? lesson, int? subject = 1, String lang = 'ru'}) => {
      'id': id,
      'topic_id': topic,
      'lesson_id': lesson,
      'subject_id': subject,
      'language': lang,
      'type': type,
      'text': 'q$id',
      'options': type == 'numeric' ? <String>[] : ['a', 'b', 'c', 'd', 'e'],
      'matching_left': type == 'matching' ? ['A', 'B', 'C', 'D'] : null,
      'answer': switch (type) { 'single' => [1], 'matching' => [1, 0, 3, 2], _ => '12.5' },
      'max_points': switch (type) { 'single' => 1, 'matching' => 4, _ => 2 },
    };

SubjectPack _pack(int subjectId, List<Map<String, dynamic>> questions, {Map<String, int>? structure}) =>
    SubjectPack.fromJson({
      'version': 'v1',
      'subject': {'id': subjectId, 'code': 's$subjectId', 'title_ru': 'Предмет', 'title_tj': 'Фан',
                  'exam_structure': structure},
      'topics': [
        {'id': 10, 'parent_id': null, 'title_ru': 'Раздел', 'title_tj': '', 'order': 0},
        {'id': 11, 'parent_id': 10, 'title_ru': 'Тема', 'title_tj': 'Мавзӯъ', 'order': 1},
      ],
      'lessons': [
        {'id': 5, 'topic_id': 11, 'language': 'ru', 'title': 'Урок', 'content': '...', 'order': 0},
      ],
      'questions': questions,
    });

void main() {
  test('grading follows the official rules', () {
    final pack = _pack(1, [_q(1, 'single'), _q(2, 'matching'), _q(3, 'numeric')]);
    final single = pack.byId[1]!, matching = pack.byId[2]!, numeric = pack.byId[3]!;
    expect(grade(single, 1), (1, true));
    expect(grade(single, 0), (0, false));
    expect(grade(matching, [1, 0, 3, 2]), (4, true));
    expect(grade(matching, [1, 0, 0, 0]), (2, false)); // one point per correct pair
    expect(grade(numeric, '12,50'), (2, true));
    expect(grade(numeric, '012.5'), (2, true));
    expect(grade(numeric, '13'), (0, false));
    expect(isValidAnswer(single, 7), isFalse);
    expect(isValidAnswer(matching, [1, 2]), isFalse);
    expect(isValidAnswer(numeric, '1e3'), isFalse);
    expect(correctSingleIndex(single), 1);
  });

  test('points: x10 per official point, x1.5 after a streak of five', () {
    expect(pointsForAnswer(true, 0, 1), (10, 0));
    expect(pointsForAnswer(true, 5, 1), (10, 5));
    expect(pointsForAnswer(true, 5, 2), (20, 10));
    expect(pointsForAnswer(false, 9, 2), (20, 0)); // partially correct matching: no streak bonus
    expect(roundHalfEven(2.5), 2);
    expect(roundHalfEven(3.5), 4);
    expect(roundHalfEven(2.4), 2);
    expect(scaleSubtest(20, 40, 75), 37.5);
  });

  test('topic test takes topic questions in the content language, without lesson checks', () {
    final pack = _pack(1, [
      for (var i = 1; i <= 30; i++) _q(i, 'single', topic: 11, lang: i <= 25 ? 'ru' : 'tj'),
      _q(100, 'single', lesson: 5),
    ]);
    final ids = selectTopicTest(pack, 11, 'ru', null, Random(1));
    expect(ids.length, topicTestMax);
    expect(ids.every((id) => id <= 25), isTrue);
    expect(selectTopicTest(pack, 11, 'tj', 3, Random(1)).every((id) => id > 25), isTrue);
    expect(selectLessonCheck(pack, 5), [100]);
    expect(selectSectionTest(pack, 10, 'ru', null, Random(1)).length, 25);
  });

  test('mock exam follows the structure and picks the subtest of the exam language', () {
    SubjectPack bank(int subjectId) => _pack(subjectId, [
          for (var i = 0; i < 25; i++) _q(subjectId * 1000 + i, 'single', topic: 11, subject: subjectId),
          for (var i = 0; i < 5; i++) _q(subjectId * 1000 + 100 + i, 'matching', topic: 11, subject: subjectId),
          _q(subjectId * 1000 + 200, 'numeric', topic: 11, subject: subjectId), // only one open task
        ]);
    final cluster = ClusterStructure.fromJson({
      'id': 3,
      'code': 'c3',
      'title_ru': 'Кластер',
      'title_tj': '',
      'duration_minutes': 190,
      'subtests': [
        {'subject_id': 1, 'position': 1, 'max_score': 75, 'language_track': null},
        {'subject_id': 2, 'position': 2, 'max_score': 150, 'language_track': 'tj'},
        {'subject_id': 3, 'position': 2, 'max_score': 150, 'language_track': 'ru'},
      ],
    });
    expect(cluster.examSubtests('ru').map((s) => s.subjectId), [1, 3]);
    expect(cluster.examSubtests('tj').map((s) => s.subjectId), [1, 2]);

    final packs = {1: bank(1), 2: bank(2), 3: bank(3)};
    final ids = selectMockExam(cluster, packs, 'ru', Random(2));
    expect(ids.length, 52); // 2 subtests × 26 tasks: the missing open task is replaced by a single-choice one
    expect(ids.where((id) => id ~/ 1000 == 3).length, 26);
    expect(ids.where((id) => id ~/ 1000 == 2), isEmpty);
    expect(ids.toSet().length, ids.length);
  });
}
