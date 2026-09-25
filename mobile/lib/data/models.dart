// Plain data classes mirroring the API responses (see backend/app/schemas).

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? const []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

class Level {
  final int number;
  final String code;
  final int minPoints;
  final int? nextLevelPoints;
  final double progress;
  const Level(this.number, this.code, this.minPoints, this.nextLevelPoints, this.progress);

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        _int(j['number']),
        j['code'] ?? 'novice',
        _int(j['min_points']),
        _intOrNull(j['next_level_points']),
        (j['progress'] as num? ?? 0).toDouble(),
      );

  static const codes = ['novice', 'learner', 'advanced', 'expert', 'master'];
  String? get nextCode => number < codes.length ? codes[number] : null;
}

class AbiturientInfo {
  final int clusterId;
  final String? clusterTitle;
  final int? backupClusterId;
  final int targetYear;
  final String? region;
  const AbiturientInfo(this.clusterId, this.clusterTitle, this.backupClusterId, this.targetYear, this.region);

  factory AbiturientInfo.fromJson(Map<String, dynamic> j) => AbiturientInfo(
      _int(j['cluster_id']), j['cluster_title'], _intOrNull(j['backup_cluster_id']), _int(j['target_year']), j['region']);
}

class SchoolInfo {
  final int grade;
  final String? schoolName;
  final String languageOfStudy;
  const SchoolInfo(this.grade, this.schoolName, this.languageOfStudy);

  factory SchoolInfo.fromJson(Map<String, dynamic> j) =>
      SchoolInfo(_int(j['grade']), j['school_name'], j['language_of_study'] ?? 'tj');
}

class Profile {
  final int id;
  final String? email;
  final String? phone;
  final String name;
  final String avatarId;
  final String language;
  final String theme;
  final bool notificationsEnabled;
  final List<String> roles;
  final String? activeRole;
  final AbiturientInfo? abiturient;
  final SchoolInfo? school;
  final int totalPoints;
  final int rolePoints;
  final Level level;
  final int currentStreak;
  final int longestStreak;

  const Profile({
    required this.id,
    required this.email,
    required this.phone,
    required this.name,
    required this.avatarId,
    required this.language,
    required this.theme,
    required this.notificationsEnabled,
    required this.roles,
    required this.activeRole,
    required this.abiturient,
    required this.school,
    required this.totalPoints,
    required this.rolePoints,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
  });

  bool get isAbiturient => activeRole == 'abiturient';

  /// Language of lessons and tasks: a schoolboy's language of study, otherwise the interface language.
  String get contentLanguage => activeRole == 'schoolboy' && school != null ? school!.languageOfStudy : language;
  bool hasRole(String role) => roles.contains(role);

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: _int(j['id']),
        email: j['email'],
        phone: j['phone'],
        name: j['name'] ?? '',
        avatarId: j['avatar_id'] ?? 'owl',
        language: j['language'] ?? 'tj',
        theme: j['theme'] ?? 'system',
        notificationsEnabled: j['notifications_enabled'] ?? true,
        roles: List<String>.from(j['roles'] ?? const []),
        activeRole: j['active_role'],
        abiturient: j['abiturient'] == null ? null : AbiturientInfo.fromJson(Map<String, dynamic>.from(j['abiturient'])),
        school: j['school'] == null ? null : SchoolInfo.fromJson(Map<String, dynamic>.from(j['school'])),
        totalPoints: _int(j['total_points']),
        rolePoints: _int(j['role_points']),
        level: Level.fromJson(Map<String, dynamic>.from(j['level'] ?? const {})),
        currentStreak: _int(j['current_streak']),
        longestStreak: _int(j['longest_streak']),
      );
}

class Subject {
  final int id;
  final String? code;
  final int? position; // subtest A1..A4 within a cluster
  final String title;
  final String? icon;
  final String? color;
  final int? clusterId;
  final int? grade;
  final int? progressPercent;
  const Subject(this.id, this.title, this.icon, this.color, this.clusterId, this.grade, this.progressPercent,
      {this.code, this.position});

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(_int(j['id']), j['title'] ?? '', j['icon'], j['color'],
      _intOrNull(j['cluster_id']), _intOrNull(j['grade']), _intOrNull(j['progress_percent']),
      code: j['code'], position: _intOrNull(j['position']));
}

class Cluster {
  final int id;
  final String code;
  final String title;
  final String? description;
  final String? icon;
  final int durationMinutes;
  final List<Subject> subjects;
  const Cluster(this.id, this.code, this.title, this.description, this.icon, this.subjects, {this.durationMinutes = 200});

  factory Cluster.fromJson(Map<String, dynamic> j) => Cluster(_int(j['id']), j['code'] ?? '', j['title'] ?? '',
      j['description'], j['icon'], _list(j['subjects'], Subject.fromJson),
      durationMinutes: _int(j['duration_minutes'] ?? 200));
}

class ExamTestInfo {
  final int id;
  final int year;
  final String title;
  final int durationMinutes;
  final int totalQuestions;
  final int? bestMmtScore;
  const ExamTestInfo(this.id, this.year, this.title, this.durationMinutes, this.totalQuestions, this.bestMmtScore);

  factory ExamTestInfo.fromJson(Map<String, dynamic> j) => ExamTestInfo(_int(j['id']), _int(j['year']),
      j['title'] ?? '', _int(j['duration_minutes']), _int(j['total_questions']), _intOrNull(j['best_mmt_score']));
}

class TopicProgress {
  final int lessonsTotal;
  final int lessonsCompleted;
  final int questionsCount;
  final int? bestAccuracy;
  final bool passed;
  final int percent;
  const TopicProgress(
      this.lessonsTotal, this.lessonsCompleted, this.questionsCount, this.bestAccuracy, this.passed, this.percent);

  factory TopicProgress.fromJson(Map<String, dynamic>? j) => j == null
      ? const TopicProgress(0, 0, 0, null, false, 0)
      : TopicProgress(_int(j['lessons_total']), _int(j['lessons_completed']), _int(j['questions_count']),
          _intOrNull(j['best_accuracy']), j['passed'] == true, _int(j['percent']));
}

class Topic {
  final int id;
  final String title;
  final TopicProgress progress;
  const Topic(this.id, this.title, this.progress);

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
      _int(j['id']), j['title'] ?? '', TopicProgress.fromJson(j['progress'] == null ? null : Map<String, dynamic>.from(j['progress'])));
}

class Section {
  final int id;
  final String title;
  final bool hasFinalTest;
  final List<Topic> topics;
  final TopicProgress progress;
  const Section(this.id, this.title, this.hasFinalTest, this.topics, this.progress);

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        _int(j['id']),
        j['title'] ?? '',
        j['has_final_test'] == true,
        _list(j['topics'], Topic.fromJson),
        TopicProgress.fromJson(j['progress'] == null ? null : Map<String, dynamic>.from(j['progress'])),
      );
}

class SubjectTree {
  final Subject subject;
  final List<Section> sections;
  const SubjectTree(this.subject, this.sections);

  factory SubjectTree.fromJson(Map<String, dynamic> j) =>
      SubjectTree(Subject.fromJson(Map<String, dynamic>.from(j['subject'])), _list(j['sections'], Section.fromJson));
}

class Lesson {
  final int id;
  final int topicId;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final String? videoUrl;
  final int checkQuestionsCount;
  final bool completed;
  const Lesson(this.id, this.topicId, this.title, this.content, this.mediaUrls, this.videoUrl,
      this.checkQuestionsCount, this.completed);

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        _int(j['id']),
        _int(j['topic_id']),
        j['title'] ?? '',
        j['content'] ?? '',
        List<String>.from(j['media_urls'] ?? const []),
        j['video_url'],
        _int(j['check_questions_count']),
        j['completed'] == true,
      );
}

class TopicTestInfo {
  final int topicId;
  final String title;
  final int questionsCount;
  final int defaultQuestionCount;
  final int secondsPerQuestion;
  final int? bestAccuracy;
  final int attemptsCount;
  const TopicTestInfo(this.topicId, this.title, this.questionsCount, this.defaultQuestionCount, this.secondsPerQuestion,
      this.bestAccuracy, this.attemptsCount);

  factory TopicTestInfo.fromJson(Map<String, dynamic> j) => TopicTestInfo(
        _int(j['topic_id']),
        j['title'] ?? '',
        _int(j['questions_count']),
        _int(j['default_question_count']),
        _int(j['time_limit_seconds_per_question']),
        _intOrNull(j['best_accuracy']),
        _int(j['attempts_count']),
      );
}

/// Official ЦВЭ task types: choose one of A–D, match A–D with 1–5, or type a natural number.
enum QuestionType { single, matching, numeric }

QuestionType _qtype(dynamic v) => switch (v) {
      'matching' => QuestionType.matching,
      'numeric' => QuestionType.numeric,
      _ => QuestionType.single,
    };

class Question {
  final int id;
  final QuestionType type;
  final String? passage;
  final String text;
  final String? imageUrl;
  final List<String> options; // single: A–D; matching: right column 1–5
  final List<String>? matchingLeft; // matching: left column A–D
  final int maxPoints;
  final String difficulty;
  final int? subjectId;
  final String? source;
  final bool isMarked;
  const Question({
    required this.id,
    required this.type,
    required this.passage,
    required this.text,
    required this.imageUrl,
    required this.options,
    required this.matchingLeft,
    required this.maxPoints,
    required this.difficulty,
    required this.subjectId,
    required this.source,
    required this.isMarked,
  });

  /// Options are only letters when the task (with its options) is shown as an image.
  bool get optionsInImage => imageUrl != null && options.every((o) => o.length == 1);

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: _int(j['id']),
        type: _qtype(j['question_type']),
        passage: j['passage'],
        text: j['text'] ?? '',
        imageUrl: j['image_url'],
        options: List<String>.from(j['options'] ?? const []),
        matchingLeft: j['matching_left'] == null ? null : List<String>.from(j['matching_left']),
        maxPoints: _int(j['max_points'] ?? 1),
        difficulty: j['difficulty'] ?? 'medium',
        subjectId: _intOrNull(j['subject_id']),
        source: j['source'],
        isMarked: j['is_marked'] == true,
      );
}

/// A user's answer: option index (single), list of option indices for A–D (matching) or digits (numeric).
typedef AnswerValue = Object;

/// Server feedback for one answer (fields are null in exam mode or while queued offline).
class AnswerFeedback {
  final AnswerValue answer;
  final bool? isCorrect;
  final int? points;
  final int? correctIndex;
  final Object? correctAnswer;
  final String? explanation;
  final int pointsAwarded;
  final bool streakBonus;
  final bool pending;
  const AnswerFeedback({
    required this.answer,
    this.isCorrect,
    this.points,
    this.correctIndex,
    this.correctAnswer,
    this.explanation,
    this.pointsAwarded = 0,
    this.streakBonus = false,
    this.pending = false,
  });

  int? get selectedIndex => answer is int ? answer as int : null;
  List<int>? get matching => answer is List ? List<int>.from(answer as List) : null;
  List<int>? get correctMatching => correctAnswer is List ? List<int>.from(correctAnswer as List) : null;

  factory AnswerFeedback.fromJson(Map<String, dynamic> j, AnswerValue answer) => AnswerFeedback(
        answer: answer,
        isCorrect: j['is_correct'],
        points: _intOrNull(j['points']),
        correctIndex: _intOrNull(j['correct_option_index']),
        correctAnswer: j['correct_answer'],
        explanation: j['explanation'],
        pointsAwarded: _int(j['points_awarded']),
        streakBonus: j['streak_bonus'] == true,
      );
}

class Attempt {
  final int id;
  final String testType;
  final int? referenceId;
  final String status;
  final bool isTimed;
  final DateTime? expiresAt;
  final DateTime serverTime;
  final bool showsFeedback;
  final List<Question> questions;
  final Map<int, AnswerFeedback> answers;
  final int score;
  final int answerStreak;

  const Attempt({
    required this.id,
    required this.testType,
    required this.referenceId,
    required this.status,
    required this.isTimed,
    required this.expiresAt,
    required this.serverTime,
    required this.showsFeedback,
    required this.questions,
    required this.answers,
    required this.score,
    required this.answerStreak,
  });

  factory Attempt.fromJson(Map<String, dynamic> j) {
    final answers = <int, AnswerFeedback>{};
    for (final a in (j['answers'] as List? ?? const [])) {
      final m = Map<String, dynamic>.from(a as Map);
      final value = m['selected_option_index'] ?? m['answer'];
      answers[_int(m['question_id'])] = AnswerFeedback(
        answer: value is List ? List<int>.from(value) : (value ?? ''),
        isCorrect: m['is_correct'],
        points: _intOrNull(m['points']),
        correctIndex: _intOrNull(m['correct_option_index']),
        correctAnswer: m['correct_answer'],
        explanation: m['explanation'],
      );
    }
    return Attempt(
      id: _int(j['id']),
      testType: j['test_type'] ?? 'topic_test',
      referenceId: _intOrNull(j['reference_id']),
      status: j['status'] ?? 'in_progress',
      isTimed: j['is_timed'] == true,
      expiresAt: _date(j['expires_at']),
      serverTime: _date(j['server_time']) ?? DateTime.now(),
      showsFeedback: j['shows_feedback'] != false,
      questions: _list(j['questions'], Question.fromJson),
      answers: answers,
      score: _int(j['score']),
      answerStreak: _int(j['answer_streak']),
    );
  }
}

class ReviewItem {
  final int questionId;
  final QuestionType type;
  final String? passage;
  final String text;
  final String? imageUrl;
  final List<String> options;
  final List<String>? matchingLeft;
  final Object? answer; // int / List<int> / String, null = no answer
  final int? correctIndex;
  final Object? correctAnswer;
  final bool isCorrect;
  final int points;
  final int maxPoints;
  final String? explanation;
  final String? source;
  final bool isMarked;
  const ReviewItem({
    required this.questionId,
    required this.type,
    required this.passage,
    required this.text,
    required this.imageUrl,
    required this.options,
    required this.matchingLeft,
    required this.answer,
    required this.correctIndex,
    required this.correctAnswer,
    required this.isCorrect,
    required this.points,
    required this.maxPoints,
    required this.explanation,
    required this.source,
    required this.isMarked,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        questionId: _int(j['question_id']),
        type: _qtype(j['question_type']),
        passage: j['passage'],
        text: j['text'] ?? '',
        imageUrl: j['image_url'],
        options: List<String>.from(j['options'] ?? const []),
        matchingLeft: j['matching_left'] == null ? null : List<String>.from(j['matching_left']),
        answer: j['selected_option_index'] ?? j['answer'],
        correctIndex: _intOrNull(j['correct_option_index']),
        correctAnswer: j['correct_answer'],
        isCorrect: j['is_correct'] == true,
        points: _int(j['points']),
        maxPoints: _int(j['max_points'] ?? 1),
        explanation: j['explanation'],
        source: j['source'],
        isMarked: j['is_marked'] == true,
      );
}

class AchievementInfo {
  final String code;
  final String title;
  final String? description;
  final String? icon;
  final int pointsReward;
  final bool unlocked;
  const AchievementInfo(this.code, this.title, this.description, this.icon, this.pointsReward, this.unlocked);

  factory AchievementInfo.fromJson(Map<String, dynamic> j) => AchievementInfo(j['code'] ?? '', j['title'] ?? '',
      j['description'], j['icon'], _int(j['points_reward']), j['unlocked'] != false);
}

/// A subtest of an exam (A1–A4): official points («очки», max 40) and the scaled score («баллы»).
class SubjectBreakdown {
  final String title;
  final int position;
  final int correct;
  final int total;
  final int points;
  final int maxPoints;
  final double score;
  final int maxScore;
  const SubjectBreakdown(this.title, this.position, this.correct, this.total, this.points, this.maxPoints, this.score,
      this.maxScore);

  factory SubjectBreakdown.fromJson(Map<String, dynamic> j) => SubjectBreakdown(
        j['title'] ?? '',
        _int(j['position']),
        _int(j['correct']),
        _int(j['total']),
        _int(j['points']),
        _int(j['max_points']),
        (j['score'] as num? ?? 0).toDouble(),
        _int(j['max_score']),
      );
}

class AttemptResult {
  final int attemptId;
  final String testType;
  final int? referenceId;
  final int correctCount;
  final int totalCount;
  final int accuracy;
  final int points;
  final int maxPoints;
  final int score;
  final int completionBonus;
  final int? mmtScore;
  final int mmtMax;
  final List<SubjectBreakdown> subjects;
  final List<AchievementInfo> newAchievements;
  final int totalPoints;
  final Level level;
  final List<ReviewItem> review;

  /// Taken offline: shown from the device, bonuses and achievements come after the upload.
  final bool pendingSync;

  const AttemptResult({
    required this.attemptId,
    required this.testType,
    required this.referenceId,
    required this.correctCount,
    required this.totalCount,
    required this.accuracy,
    required this.points,
    required this.maxPoints,
    required this.score,
    required this.completionBonus,
    required this.mmtScore,
    required this.mmtMax,
    required this.subjects,
    required this.newAchievements,
    required this.totalPoints,
    required this.level,
    required this.review,
    this.pendingSync = false,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> j) => AttemptResult(
        attemptId: _int(j['attempt_id']),
        testType: j['test_type'] ?? '',
        referenceId: _intOrNull(j['reference_id']),
        correctCount: _int(j['correct_count']),
        totalCount: _int(j['total_count']),
        accuracy: _int(j['accuracy']),
        points: _int(j['points']),
        maxPoints: _int(j['max_points']),
        score: _int(j['score']),
        completionBonus: _int(j['completion_bonus']),
        mmtScore: _intOrNull(j['mmt_score']),
        mmtMax: _int(j['mmt_max'] ?? 500),
        subjects: _list(j['subjects'], SubjectBreakdown.fromJson),
        newAchievements: _list(j['new_achievements'], AchievementInfo.fromJson),
        totalPoints: _int(j['total_points']),
        level: Level.fromJson(Map<String, dynamic>.from(j['level'] ?? const {})),
        review: _list(j['review'], ReviewItem.fromJson),
        pendingSync: j['pending_sync'] == true,
      );
}

/// Full ЦВЭ simulation of a cluster: official subtests, number of tasks, duration, max score.
class MockExamInfo {
  final int clusterId;
  final int durationMinutes;
  final int questions;
  final int maxScore;
  final List<({int position, String title, int questions, int maxScore})> subtests;
  const MockExamInfo(this.clusterId, this.durationMinutes, this.questions, this.maxScore, this.subtests);

  factory MockExamInfo.fromJson(Map<String, dynamic> j) => MockExamInfo(
        _int(j['cluster_id']),
        _int(j['duration_minutes']),
        _int(j['questions']),
        _int(j['max_score']),
        [
          for (final s in (j['subtests'] as List? ?? const []))
            (
              position: _int(s['position']),
              title: '${s['title'] ?? ''}',
              questions: _int(s['questions']),
              maxScore: _int(s['max_score']),
            ),
        ],
      );
}

/// Cluster screen: subjects (subtests), the mock ЦВЭ and fixed exam tests.
class ClusterScreenData {
  final Cluster cluster;
  final MockExamInfo? mockExam;
  final List<ExamTestInfo> examTests;
  const ClusterScreenData(this.cluster, this.mockExam, this.examTests);

  factory ClusterScreenData.fromJson(Map<String, dynamic> j) => ClusterScreenData(
        Cluster.fromJson(j),
        j['mock_exam'] == null ? null : MockExamInfo.fromJson(Map<String, dynamic>.from(j['mock_exam'])),
        _list(j['exam_tests'], ExamTestInfo.fromJson),
      );
}

class HistoryItem {
  final int id;
  final String testType;
  final String title;
  final DateTime? finishedAt;
  final int correctCount;
  final int totalCount;
  final int accuracy;
  final int score;
  final int? mmtScore;
  const HistoryItem(this.id, this.testType, this.title, this.finishedAt, this.correctCount, this.totalCount,
      this.accuracy, this.score, this.mmtScore);

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        _int(j['id']),
        j['test_type'] ?? '',
        j['title'] ?? '',
        _date(j['finished_at']),
        _int(j['correct_count']),
        _int(j['total_count']),
        _int(j['accuracy']),
        _int(j['score']),
        _intOrNull(j['mmt_score']),
      );
}

class SubjectProgress {
  final int subjectId;
  final String title;
  final String? color;
  final int percent;
  final int accuracy;
  final int answered;
  const SubjectProgress(this.subjectId, this.title, this.color, this.percent, this.accuracy, this.answered);

  factory SubjectProgress.fromJson(Map<String, dynamic> j) => SubjectProgress(_int(j['subject_id']),
      j['title'] ?? '', j['color'], _int(j['percent']), _int(j['accuracy']), _int(j['answered']));
}

class LeaderboardEntry {
  final int rank;
  final int userId;
  final String name;
  final String avatarId;
  final int points;
  final int level;
  const LeaderboardEntry(this.rank, this.userId, this.name, this.avatarId, this.points, this.level);

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(_int(j['rank']), _int(j['user_id']),
      j['name'] ?? '', j['avatar_id'] ?? 'owl', _int(j['points']), _int(j['level'] ?? 1));
}

class Leaderboard {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? me;
  const Leaderboard(this.entries, this.me);

  factory Leaderboard.fromJson(Map<String, dynamic> j) => Leaderboard(_list(j['entries'], LeaderboardEntry.fromJson),
      j['me'] == null ? null : LeaderboardEntry.fromJson(Map<String, dynamic>.from(j['me'])));
}

class AttemptBrief {
  final int id;
  final String testType;
  final int? referenceId;
  final String title;
  final int correctCount;
  final int totalCount;
  final int answeredCount;
  final int? mmtScore;
  const AttemptBrief(this.id, this.testType, this.referenceId, this.title, this.correctCount, this.totalCount,
      this.answeredCount, this.mmtScore);

  factory AttemptBrief.fromJson(Map<String, dynamic> j) => AttemptBrief(_int(j['id']), j['test_type'] ?? '',
      _intOrNull(j['reference_id']), j['title'] ?? '', _int(j['correct_count']), _int(j['total_count']),
      _int(j['answered_count']), _intOrNull(j['mmt_score']));
}

class Dashboard {
  final String role;
  final Profile profile;
  final List<Subject> subjects;
  final AttemptBrief? unfinished;
  final AttemptBrief? last;
  final int? rank;
  final int? clusterId;
  final String? clusterTitle;
  final int? grade;
  final bool fromCache;

  const Dashboard({
    required this.role,
    required this.profile,
    required this.subjects,
    required this.unfinished,
    required this.last,
    required this.rank,
    required this.clusterId,
    required this.clusterTitle,
    required this.grade,
    this.fromCache = false,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j, {bool fromCache = false}) => Dashboard(
        role: j['role'] ?? '',
        profile: Profile.fromJson(Map<String, dynamic>.from(j['profile'])),
        subjects: _list(j['subjects'], Subject.fromJson),
        unfinished: j['unfinished_attempt'] == null
            ? null
            : AttemptBrief.fromJson(Map<String, dynamic>.from(j['unfinished_attempt'])),
        last: j['last_attempt'] == null ? null : AttemptBrief.fromJson(Map<String, dynamic>.from(j['last_attempt'])),
        rank: _intOrNull(j['rank']),
        clusterId: j['cluster'] == null ? null : _int(j['cluster']['id']),
        clusterTitle: j['cluster']?['title'],
        grade: _intOrNull(j['grade']),
        fromCache: fromCache,
      );
}

class Region {
  final String code;
  final String ru;
  final String tj;
  const Region(this.code, this.ru, this.tj);
  factory Region.fromJson(Map<String, dynamic> j) => Region(j['code'], j['ru'], j['tj']);
  String title(String lang) => lang == 'tj' ? tj : ru;
}
