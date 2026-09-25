// Sample data for screenshot tests: what a real abiturient sees after a couple of weeks of study.
import 'package:eduapp/data/models.dart';

final level = {'number': 3, 'code': 'advanced', 'min_points': 1500, 'next_level_points': 3000, 'progress': 0.62};

Map<String, dynamic> profileJson({String role = 'abiturient'}) => {
      'id': 7,
      'email': 'farzona@example.tj',
      'name': 'Фарзона',
      'avatar_id': 'fox',
      'language': 'ru',
      'theme': 'light',
      'notifications_enabled': true,
      'roles': [role],
      'active_role': role,
      'abiturient': role == 'abiturient'
          ? {'cluster_id': 1, 'cluster_title': 'Естественно-технические науки', 'target_year': 2026, 'region': 'dushanbe'}
          : null,
      'school': role == 'schoolboy' ? {'grade': 3, 'school_name': 'Школа №5', 'language_of_study': 'ru'} : null,
      'total_points': 2430,
      'role_points': 2430,
      'level': level,
      'current_streak': 12,
      'longest_streak': 19,
    };

final profile = Profile.fromJson(profileJson());

final subjects = [
  {'id': 1, 'title': 'Таджикский язык', 'icon': 'translate', 'color': '#0EA5E9', 'position': 1, 'progress_percent': 46},
  {'id': 2, 'title': 'Математика', 'icon': 'calculate', 'color': '#6366F1', 'position': 2, 'progress_percent': 72},
  {'id': 3, 'title': 'Химия', 'icon': 'science', 'color': '#10B981', 'position': 3, 'progress_percent': 31},
  {'id': 4, 'title': 'Физика', 'icon': 'bolt', 'color': '#F59E0B', 'position': 4, 'progress_percent': 58},
];

final dashboard = Dashboard.fromJson({
  'role': 'abiturient',
  'profile': profileJson(),
  'subjects': subjects,
  'unfinished_attempt': {
    'id': 91, 'test_type': 'topic_test', 'reference_id': 12, 'title': 'Тригонометрия',
    'correct_count': 5, 'total_count': 12, 'answered_count': 7,
  },
  'rank': 4,
  'cluster': {'id': 1, 'title': 'Естественно-технические науки'},
});

final clusterScreen = ClusterScreenData.fromJson({
  'id': 1,
  'code': 'c1',
  'title': 'Естественно-технические науки',
  'duration_minutes': 200,
  'subjects': subjects,
  'mock_exam': {
    'cluster_id': 1, 'duration_minutes': 200, 'questions': 104, 'max_score': 500,
    'subtests': [
      {'position': 1, 'title': 'Таджикский язык', 'questions': 25, 'max_score': 75},
      {'position': 2, 'title': 'Математика', 'questions': 27, 'max_score': 175},
      {'position': 3, 'title': 'Химия', 'questions': 27, 'max_score': 100},
      {'position': 4, 'title': 'Физика', 'questions': 27, 'max_score': 150},
    ],
  },
  'exam_tests': [
    {'id': 1, 'year': 2026, 'title': 'Образец ЦВЭ-2026', 'duration_minutes': 200, 'total_questions': 104,
      'best_mmt_score': 362},
  ],
});

final progress = [
  for (final (i, s) in subjects.indexed)
    SubjectProgress.fromJson({
      'subject_id': s['id'], 'title': s['title'], 'color': s['color'], 'percent': s['progress_percent'],
      'accuracy': [81, 74, 63, 69][i], 'answered': [120, 340, 95, 210][i],
    }),
];

final now = DateTime.now();

final history = [
  for (final (i, h) in [
    ('mock_exam', 'Пробный ЦВЭ', 71, 74, 104, 820, 388, 0),
    ('topic_test', 'Тригонометрия', 83, 10, 12, 140, null, 0),
    ('practice', 'Тренировка: Химия', 60, 9, 15, 95, null, 1),
    ('lesson_check', 'Мини-проверка: Производная', 100, 3, 3, 45, null, 1),
    ('topic_test', 'Логарифмы', 42, 5, 12, 60, null, 2),
    ('section_test', 'Итоговый тест: Алгебра', 90, 18, 20, 260, null, 3),
    ('practice', 'Тренировка: Физика', 75, 12, 16, 150, null, 5),
    ('topic_test', 'Кинематика', 66, 8, 12, 110, null, 5),
  ].indexed)
    HistoryItem.fromJson({
      'id': 100 + i, 'test_type': h.$1, 'title': h.$2, 'accuracy': h.$3, 'correct_count': h.$4,
      'total_count': h.$5, 'score': h.$6, 'mmt_score': h.$7,
      'finished_at': now.subtract(Duration(days: h.$8, hours: i)).toIso8601String(),
    }),
];

final achievements = [
  for (final (code, title, desc, icon, reward, unlocked) in [
    ('first_test', 'Первый тест', 'Пройдите первый тест', 'flag', 10, true),
    ('streak_7', 'Неделя подряд', 'Занимайтесь 7 дней подряд', 'fire', 50, true),
    ('perfect', 'Без ошибок', 'Пройдите тест на 100%', 'star', 30, true),
    ('mock', 'Пробный ЦВЭ', 'Пройдите пробный ЦВЭ целиком', 'graduation', 100, true),
    ('streak_30', 'Месяц подряд', 'Занимайтесь 30 дней подряд', 'crown', 200, false),
    ('points_5000', '5000 баллов', 'Наберите 5000 баллов', 'gem', 150, false),
  ])
    AchievementInfo.fromJson({
      'code': code, 'title': title, 'description': desc, 'icon': icon, 'points_reward': reward, 'unlocked': unlocked,
    }),
];

final leaderboard = Leaderboard.fromJson({
  'entries': [
    for (final (i, (name, avatar, points)) in [
      ('Бахтиёр', 'lion', 5120), ('Мадина', 'cat', 4870), ('Сухроб', 'eagle', 4410), ('Фарзона', 'fox', 2430),
      ('Нилуфар', 'rabbit', 2210), ('Рустам', 'bear', 1980), ('Шахзода', 'panda', 1760), ('Далер', 'tiger', 1540),
    ].indexed)
      {'rank': i + 1, 'user_id': i == 3 ? 7 : 20 + i, 'name': name, 'avatar_id': avatar, 'points': points,
        'level': 3},
  ],
  'me': {'rank': 4, 'user_id': 7, 'name': 'Фарзона', 'avatar_id': 'fox', 'points': 2430, 'level': 3},
});

Map<String, dynamic> _tp(int total, int done, int q, int? best, bool passed, int percent) => {
      'lessons_total': total, 'lessons_completed': done, 'questions_count': q, 'best_accuracy': best,
      'passed': passed, 'percent': percent,
    };

final subjectTree = SubjectTree.fromJson({
  'subject': subjects[1],
  'sections': [
    {
      'id': 10, 'title': 'Уроки и упражнения', 'has_final_test': true, 'progress': _tp(14, 6, 126, 78, false, 48),
      'topics': [
        {'id': 11, 'title': 'Как устроен субтест «Математика»', 'progress': _tp(1, 1, 6, 100, true, 100)},
        {'id': 12, 'title': 'Дроби, степени и корни', 'progress': _tp(1, 1, 6, 83, true, 100)},
        {'id': 13, 'title': 'Уравнения', 'progress': _tp(1, 1, 6, 67, false, 70)},
        {'id': 14, 'title': 'Неравенства и метод интервалов', 'progress': _tp(1, 0, 6, 50, false, 35)},
        {'id': 15, 'title': 'Тригонометрия', 'progress': _tp(1, 0, 6, null, false, 0)},
      ],
    },
    {
      'id': 20, 'title': 'Задания повышенной сложности', 'has_final_test': false, 'progress': _tp(0, 0, 216, 61, false, 22),
      'topics': [
        {'id': 21, 'title': 'Производная функции', 'progress': _tp(0, 0, 14, 61, false, 40)},
        {'id': 22, 'title': 'Стереометрия', 'progress': _tp(0, 0, 18, null, false, 0)},
      ],
    },
  ],
});


final result = AttemptResult.fromJson({
  'attempt_id': 501, 'test_type': 'mock_exam', 'reference_id': 1, 'correct_count': 74, 'total_count': 104,
  'accuracy': 81, 'points': 88, 'max_points': 124, 'score': 820, 'completion_bonus': 100, 'mmt_score': 388,
  'mmt_max': 500, 'total_points': 3250, 'level': level,
  'subjects': [
    {'title': 'Таджикский язык', 'position': 1, 'correct': 20, 'total': 25, 'points': 32, 'max_points': 40,
      'score': 60.0, 'max_score': 75},
    {'title': 'Математика', 'position': 2, 'correct': 19, 'total': 27, 'points': 26, 'max_points': 40,
      'score': 113.8, 'max_score': 175},
    {'title': 'Химия', 'position': 3, 'correct': 17, 'total': 27, 'points': 24, 'max_points': 40,
      'score': 60.0, 'max_score': 100},
    {'title': 'Физика', 'position': 4, 'correct': 18, 'total': 25, 'points': 27, 'max_points': 40,
      'score': 101.3, 'max_score': 150},
  ],
  'new_achievements': [
    {'code': 'mock', 'title': 'Пробный ЦВЭ', 'icon': 'graduation', 'points_reward': 100, 'unlocked': true},
  ],
  'review': [
    {'question_id': 1, 'question_type': 'single', 'text': 'Вычислите: log₂ 48 − log₂ 3.',
      'options': ['4', 'log₂ 45', '2', '16'], 'selected_option_index': 0, 'correct_option_index': 0,
      'is_correct': true, 'points': 1, 'max_points': 1,
      'explanation': 'log₂ 48 − log₂ 3 = log₂ (48 : 3) = log₂ 16 = 4.'},
    {'question_id': 2, 'question_type': 'numeric', 'text': 'Найдите сумму всех двузначных натуральных чисел, кратных 7.',
      'options': [], 'answer': '700', 'correct_answer': '728', 'is_correct': false, 'points': 0, 'max_points': 2,
      'explanation': 'Это 14, 21, …, 98 — 13 членов прогрессии. S = (14 + 98) · 13/2 = 728.'},
  ],
});
