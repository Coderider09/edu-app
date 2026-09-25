// Offline test engine: the content of a downloaded pack and the same rules as the server
// (backend/app/services/testing.py, gamification.py). Pure Dart — no Flutter, no IO.
//
// Results computed here are shown right away; the server re-grades everything on /sync.
import 'dart:math';

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
int? _intOrNull(dynamic v) => v == null ? null : _int(v);

class PackQuestion {
  final int id;
  final int? topicId;
  final int? lessonId;
  final int? subjectId;
  final String language;
  final String type; // single | matching | numeric
  final String? passage;
  final String text;
  final String? image; // "images/<file>" inside the pack
  final List<String> options;
  final List<String>? matchingLeft;
  final Object? answer; // single: [index]; matching: [i, i, i, i]; numeric: "125"
  final String? explanation;
  final String difficulty;
  final String? source;
  final int maxPoints;

  const PackQuestion({
    required this.id,
    required this.topicId,
    required this.lessonId,
    required this.subjectId,
    required this.language,
    required this.type,
    required this.passage,
    required this.text,
    required this.image,
    required this.options,
    required this.matchingLeft,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    required this.source,
    required this.maxPoints,
  });

  /// Topic tests, practice and mock exams use these; lesson mini-checks are separate.
  bool get inTopicPool => lessonId == null;

  factory PackQuestion.fromJson(Map<String, dynamic> j) => PackQuestion(
        id: _int(j['id']),
        topicId: _intOrNull(j['topic_id']),
        lessonId: _intOrNull(j['lesson_id']),
        subjectId: _intOrNull(j['subject_id']),
        language: j['language'] ?? 'ru',
        type: j['type'] ?? 'single',
        passage: j['passage'],
        text: j['text'] ?? '',
        image: j['image'],
        options: List<String>.from(j['options'] ?? const []),
        matchingLeft: j['matching_left'] == null ? null : List<String>.from(j['matching_left']),
        answer: j['answer'],
        explanation: j['explanation'],
        difficulty: j['difficulty'] ?? 'medium',
        source: j['source'],
        maxPoints: _int(j['max_points'] ?? 1),
      );
}

class PackTopic {
  final int id;
  final int? parentId;
  final String titleRu;
  final String titleTj;
  final int order;
  const PackTopic(this.id, this.parentId, this.titleRu, this.titleTj, this.order);

  String title(String lang) => lang == 'tj' && titleTj.isNotEmpty ? titleTj : titleRu;

  factory PackTopic.fromJson(Map<String, dynamic> j) => PackTopic(
      _int(j['id']), _intOrNull(j['parent_id']), j['title_ru'] ?? '', j['title_tj'] ?? '', _int(j['order']));
}

class PackLesson {
  final int id;
  final int topicId;
  final String language;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final String? videoUrl;
  final int order;
  const PackLesson(
      this.id, this.topicId, this.language, this.title, this.content, this.mediaUrls, this.videoUrl, this.order);

  factory PackLesson.fromJson(Map<String, dynamic> j) => PackLesson(
        _int(j['id']),
        _int(j['topic_id']),
        j['language'] ?? 'ru',
        j['title'] ?? '',
        j['content'] ?? '',
        List<String>.from(j['media_urls'] ?? const []),
        j['video_url'],
        _int(j['order']),
      );
}

/// A downloaded subject: topics, lessons and questions with answer keys.
class SubjectPack {
  final int subjectId;
  final String? code;
  final String titleRu;
  final String titleTj;
  final String? icon;
  final String? color;
  final int? grade;
  final Map<String, int> examStructure;
  final String version;
  final List<PackTopic> topics;
  final List<PackLesson> lessons;
  final List<PackQuestion> questions;
  final Map<int, PackQuestion> byId;

  /// Directory of the unpacked pack (for images); null in tests.
  final String? dir;

  SubjectPack({
    required this.subjectId,
    required this.code,
    required this.titleRu,
    required this.titleTj,
    required this.icon,
    required this.color,
    required this.grade,
    required this.examStructure,
    required this.version,
    required this.topics,
    required this.lessons,
    required this.questions,
    this.dir,
  }) : byId = {for (final q in questions) q.id: q};

  String title(String lang) => lang == 'tj' && titleTj.isNotEmpty ? titleTj : titleRu;

  factory SubjectPack.fromJson(Map<String, dynamic> j, {String? dir}) {
    final s = Map<String, dynamic>.from(j['subject']);
    final structure = Map<String, dynamic>.from(s['exam_structure'] ?? const {});
    List<Map<String, dynamic>> list(String key) =>
        (j[key] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return SubjectPack(
      subjectId: _int(s['id']),
      code: s['code'],
      titleRu: s['title_ru'] ?? '',
      titleTj: s['title_tj'] ?? '',
      icon: s['icon'],
      color: s['color'],
      grade: _intOrNull(s['grade']),
      examStructure: structure.isEmpty ? defaultStructure : structure.map((k, v) => MapEntry(k, _int(v))),
      version: j['version'] ?? '',
      topics: list('topics').map(PackTopic.fromJson).toList(),
      lessons: list('lessons').map(PackLesson.fromJson).toList(),
      questions: list('questions').map(PackQuestion.fromJson).toList(),
      dir: dir,
    );
  }

  PackTopic? topic(int id) => topics.where((t) => t.id == id).firstOrNull;
  PackLesson? lesson(int id) => lessons.where((l) => l.id == id).firstOrNull;
}

/// A subtest A1..A4 of a cluster (from the pack manifest).
class ClusterSubtest {
  final int subjectId;
  final int position;
  final int maxScore;
  final String? languageTrack;
  const ClusterSubtest(this.subjectId, this.position, this.maxScore, this.languageTrack);

  factory ClusterSubtest.fromJson(Map<String, dynamic> j) =>
      ClusterSubtest(_int(j['subject_id']), _int(j['position']), _int(j['max_score']), j['language_track']);
}

class ClusterStructure {
  final int id;
  final String code;
  final String titleRu;
  final String titleTj;
  final int durationMinutes;
  final List<ClusterSubtest> subtests;
  const ClusterStructure(this.id, this.code, this.titleRu, this.titleTj, this.durationMinutes, this.subtests);

  factory ClusterStructure.fromJson(Map<String, dynamic> j) => ClusterStructure(
        _int(j['id']),
        j['code'] ?? '',
        j['title_ru'] ?? '',
        j['title_tj'] ?? '',
        _int(j['duration_minutes']),
        (j['subtests'] as List? ?? const [])
            .map((e) => ClusterSubtest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  /// A1..A4; at a position with alternatives the subject of the exam language is taken.
  List<ClusterSubtest> examSubtests(String lang) {
    final byPosition = <int, List<ClusterSubtest>>{};
    for (final s in subtests) {
      byPosition.putIfAbsent(s.position, () => []).add(s);
    }
    final positions = byPosition.keys.toList()..sort();
    return [
      for (final p in positions)
        () {
          final links = byPosition[p]!;
          final match = links.where((l) => l.languageTrack == lang).toList();
          if (match.isNotEmpty) return match.first;
          final neutral = links.where((l) => l.languageTrack == null).toList();
          return neutral.isNotEmpty ? neutral.first : links.first;
        }(),
    ];
  }
}

// ------------------------------------------------------------------ rules (mirror of the server)
const defaultStructure = {'single': 20, 'matching': 4, 'numeric': 2};
const topicTestMax = 20;
const sectionTestMax = 30;
const practiceDefault = 10;
const basePoints = 10;
const streakThreshold = 5;
const streakMultiplier = 1.5;
const mmtMax = 500;

String? normalizeNumber(Object? value) {
  var text = '${value ?? ''}'.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return null;
  text = text.replaceFirst(RegExp(r'^0+'), '');
  if (text.isEmpty) text = '0';
  if (text.contains('.')) text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return text;
}

/// Whether the answer has the right shape for the question (like validate_answer on the server).
bool isValidAnswer(PackQuestion q, Object? answer) {
  switch (q.type) {
    case 'single':
      return answer is int && answer >= 0 && answer < q.options.length;
    case 'matching':
      final left = q.matchingLeft ?? const [];
      return answer is List &&
          answer.length == left.length &&
          answer.every((a) => a is int && a >= 0 && a < q.options.length);
    default:
      return RegExp(r'^\d{1,9}([.,]\d{1,4})?$').hasMatch('${answer ?? ''}'.replaceAll(RegExp(r'\s+'), ''));
  }
}

/// Official points («очки») and whether the answer is fully correct.
(int, bool) grade(PackQuestion q, Object? answer) {
  final key = q.answer;
  if (key == null) return (0, false);
  switch (q.type) {
    case 'single':
      final ok = answer is int && key is List && key.contains(answer);
      return ok ? (1, true) : (0, false);
    case 'matching':
      if (answer is! List || key is! List) return (0, false);
      var points = 0;
      for (var i = 0; i < min(answer.length, key.length); i++) {
        if (answer[i] == key[i]) points++;
      }
      return (points, points == key.length);
    default:
      final expected = normalizeNumber(key);
      final ok = expected != null && normalizeNumber(answer) == expected;
      return ok ? (2, true) : (0, false);
  }
}

/// (base, streak bonus) in app points for one answer.
(int, int) pointsForAnswer(bool isCorrect, int streakBefore, int officialPoints) {
  final base = officialPoints * basePoints;
  if (!isCorrect || streakBefore < streakThreshold) return (base, 0);
  return (base, (base * streakMultiplier).toInt() - base);
}

/// Python's round(): halves go to the even neighbour.
int roundHalfEven(double x) {
  final r = x.roundToDouble();
  if ((x - x.truncateToDouble()).abs() == 0.5 && r % 2 != 0) return (r - x.sign).toInt();
  return r.toInt();
}

double scaleSubtest(int points, int maxPoints, int maxScore) => maxPoints <= 0 ? 0 : maxScore * points / maxPoints;

/// The single correct option of a single-choice question (for feedback).
int? correctSingleIndex(PackQuestion q) =>
    q.type == 'single' && q.answer is List && (q.answer as List).isNotEmpty ? _int((q.answer as List).first) : null;

// ------------------------------------------------------------------ question selection
List<int> _inLanguage(Iterable<PackQuestion> pool, String lang) {
  final all = pool.toList();
  final own = all.where((q) => q.language == lang).map((q) => q.id).toList();
  return own.isNotEmpty ? own : all.map((q) => q.id).toList();
}

List<int> _sample(List<int> ids, int limit, Random random) => (List<int>.from(ids)..shuffle(random)).take(limit).toList();

List<int> selectTopicTest(SubjectPack pack, int topicId, String lang, int? count, [Random? random]) => _sample(
    _inLanguage(pack.questions.where((q) => q.topicId == topicId && q.inTopicPool), lang),
    min(count ?? topicTestMax, topicTestMax),
    random ?? Random());

List<int> selectSectionTest(SubjectPack pack, int sectionId, String lang, int? count, [Random? random]) {
  final topicIds = {sectionId, ...pack.topics.where((t) => t.parentId == sectionId).map((t) => t.id)};
  return _sample(_inLanguage(pack.questions.where((q) => topicIds.contains(q.topicId) && q.inTopicPool), lang),
      min(count ?? sectionTestMax, sectionTestMax), random ?? Random());
}

List<int> selectPractice(SubjectPack pack, String lang, int? count, [Random? random]) => _sample(
    _inLanguage(pack.questions.where((q) => q.topicId != null && q.inTopicPool), lang),
    min(count ?? practiceDefault, 50),
    random ?? Random());

List<int> selectLessonCheck(SubjectPack pack, int lessonId) =>
    pack.questions.where((q) => q.lessonId == lessonId).map((q) => q.id).toList();

/// Full ЦВЭ simulation: for each subtest the official number of tasks of each type (exam tasks only),
/// in the exam language when the subject has it, so a subtest never mixes translations.
List<int> selectMockExam(ClusterStructure cluster, Map<int, SubjectPack> packs, String lang, [Random? random]) {
  random ??= Random();
  final ids = <int>[];
  for (final link in cluster.examSubtests(lang)) {
    final pack = packs[link.subjectId];
    if (pack == null) continue;
    var inSubject = pack.questions.where((q) => q.subjectId == link.subjectId && q.inTopicPool).toList();
    if (inSubject.any((q) => q.language == lang)) {
      inSubject = inSubject.where((q) => q.language == lang).toList();
    }
    final perType = <String, List<int>>{};
    var missing = 0;
    for (final type in const ['single', 'matching', 'numeric']) {
      final pool = inSubject.where((q) => q.type == type).map((q) => q.id).toList();
      final need = pack.examStructure[type] ?? 0;
      final picked = _sample(pool, need, random);
      missing += need - picked.length;
      perType[type] = picked;
    }
    if (missing > 0) {
      final pool =
          inSubject.where((q) => q.type == 'single' && !perType['single']!.contains(q.id)).map((q) => q.id).toList();
      perType['single'] = [...perType['single']!, ..._sample(pool, missing, random)];
    }
    ids.addAll([...perType['single']!, ...perType['matching']!, ...perType['numeric']!]);
  }
  return ids;
}
