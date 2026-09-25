import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import 'engine.dart';
import 'pack_store.dart';

/// Test types that can run from downloaded packs. Fixed official samples (exam_test) and
/// "Повторить ошибки" (needs the answer history on the server) stay online.
const offlineTestTypes = {'topic_test', 'section_test', 'practice', 'lesson_check', 'mock_exam'};
const _examTypes = {'mock_exam'};
const _secondsPerQuestion = 60;

String _newClientId() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

/// Tests taken from downloaded packs. Returns JSON shaped like the server responses, so the
/// test and result screens work the same online and offline. Finished attempts wait for /sync.
class OfflineTesting {
  final PackStore packs;
  OfflineTesting(this.packs);

  Box<String> get _box => Hive.box<String>(AppConfig.attemptsBox);

  // ------------------------------------------------------------------ storage
  Map<String, dynamic>? _record(int localId) {
    final raw = _box.get('local_$localId');
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> _save(Map<String, dynamic> record) => _box.put('local_${record['local_id']}', jsonEncode(record));

  int _nextLocalId() {
    final next = (int.tryParse(_box.get('local_seq') ?? '') ?? 0) + 1;
    _box.put('local_seq', '$next');
    return -next; // negative: never clashes with server attempt ids
  }

  /// Finished attempts that are not uploaded yet.
  List<Map<String, dynamic>> pendingAttempts() => [
        for (final key in _box.keys)
          if (RegExp(r'^local_-\d+$').hasMatch('$key')) Map<String, dynamic>.from(jsonDecode(_box.get(key)!))
      ].where((r) => r['finished_at'] != null).toList();

  Future<void> markSynced(String clientId) async {
    for (final r in pendingAttempts()) {
      if (r['client_id'] == clientId) {
        await _box.delete('local_${r['local_id']}');
        await _box.delete('result_${r['local_id']}');
      }
    }
  }

  // ------------------------------------------------------------------ packs of a test
  Future<Map<int, SubjectPack>?> _packsFor(String type, int? ref) async {
    if (!offlineTestTypes.contains(type) || ref == null) return null;
    SubjectPack? pack;
    switch (type) {
      case 'topic_test':
      case 'section_test':
        pack = await packs.forTopic(ref);
      case 'practice':
        pack = await packs.load(ref);
      case 'lesson_check':
        pack = await packs.forLesson(ref);
      case 'mock_exam':
        final cluster = packs.cluster(ref);
        if (cluster == null) return null;
        final result = <int, SubjectPack>{};
        for (final s in cluster.subtests) {
          final p = await packs.load(s.subjectId);
          if (p != null) result[s.subjectId] = p;
        }
        // Every subtest of the exam language must be downloaded
        final needed = cluster.examSubtests('tj').map((s) => s.subjectId).toSet()
          ..addAll(cluster.examSubtests('ru').map((s) => s.subjectId));
        return needed.every(result.containsKey) ? result : null;
    }
    return pack == null ? null : {pack.subjectId: pack};
  }

  /// Whether this test can run offline right now (its packs are downloaded).
  Future<bool> canRun(String type, int? ref) async => await _packsFor(type, ref) != null;

  PackQuestion? _question(Map<int, SubjectPack> packs, int id) {
    for (final p in packs.values) {
      final q = p.byId[id];
      if (q != null) return q;
    }
    return null;
  }

  SubjectPack? _packOf(Map<int, SubjectPack> packs, int questionId) =>
      packs.values.where((p) => p.byId.containsKey(questionId)).firstOrNull;

  // ------------------------------------------------------------------ attempt
  /// Starts (or resumes) an offline attempt; null when the test can't run from the downloaded packs.
  Future<Map<String, dynamic>?> start(String type, int? ref,
      {required String lang, bool timed = false, int? questionCount}) async {
    final subjectPacks = await _packsFor(type, ref);
    if (subjectPacks == null) return null;

    final resumeKey = 'local_ref_${type}_${ref ?? 0}';
    final resumeId = int.tryParse(_box.get(resumeKey) ?? '');
    final existing = resumeId == null ? null : _record(resumeId);
    if (existing != null && existing['finished_at'] == null) {
      if (!_expired(existing, DateTime.now())) return _attemptJson(existing, subjectPacks);
      await finish(resumeId!);
    }

    final pack = subjectPacks.values.first;
    final List<int> ids = switch (type) {
      'topic_test' => selectTopicTest(pack, ref!, lang, questionCount),
      'section_test' => selectSectionTest(pack, ref!, lang, questionCount),
      'practice' => selectPractice(pack, lang, questionCount),
      'lesson_check' => selectLessonCheck(pack, ref!),
      _ => selectMockExam(packs.cluster(ref!)!, subjectPacks, lang),
    };
    if (ids.isEmpty) return null;

    final now = DateTime.now().toUtc();
    DateTime? expires;
    if (type == 'mock_exam') {
      expires = now.add(Duration(minutes: packs.cluster(ref!)!.durationMinutes));
    } else if (timed && (type == 'topic_test' || type == 'section_test')) {
      expires = now.add(Duration(seconds: _secondsPerQuestion * ids.length));
    }
    final record = <String, dynamic>{
      'local_id': _nextLocalId(),
      'client_id': _newClientId(),
      'test_type': type,
      'reference_id': ref,
      'question_ids': ids,
      'started_at': _iso(now),
      'expires_at': expires == null ? null : _iso(expires),
      'finished_at': null,
      'lang': lang,
      'streak': 0,
      'score': 0,
      'answers': <Map<String, dynamic>>[],
    };
    await _save(record);
    await _box.put(resumeKey, '${record['local_id']}');
    return _attemptJson(record, subjectPacks);
  }

  bool _expired(Map<String, dynamic> r, DateTime now) {
    final expires = DateTime.tryParse('${r['expires_at']}');
    return expires != null && now.isAfter(expires.add(const Duration(seconds: 15)));
  }

  bool _showsFeedback(Map<String, dynamic> r) => !_examTypes.contains(r['test_type']);

  Map<String, dynamic> _questionJson(SubjectPack pack, PackQuestion q) => {
        'id': q.id,
        'question_type': q.type,
        'passage': q.passage,
        'text': q.text,
        'image_url': PackStore.imageUrl(pack, q),
        'options': q.options,
        'matching_left': q.matchingLeft,
        'max_points': q.maxPoints,
        'difficulty': q.difficulty,
        'subject_id': q.subjectId,
        'source': q.source,
        'is_marked': false,
      };

  Map<String, dynamic> _feedback(PackQuestion q, Map<String, dynamic> a) => {
        'is_correct': a['is_correct'],
        'points': a['points'],
        'correct_option_index': correctSingleIndex(q),
        'correct_answer': q.answer,
        'explanation': q.explanation,
      };

  Map<String, dynamic> _attemptJson(Map<String, dynamic> r, Map<int, SubjectPack> subjectPacks) {
    final feedback = _showsFeedback(r);
    final questions = <Map<String, dynamic>>[];
    for (final id in (r['question_ids'] as List).cast<int>()) {
      final pack = _packOf(subjectPacks, id);
      if (pack != null) questions.add(_questionJson(pack, pack.byId[id]!));
    }
    return {
      'id': r['local_id'],
      'test_type': r['test_type'],
      'reference_id': r['reference_id'],
      'status': r['finished_at'] == null ? 'in_progress' : 'finished',
      'is_timed': r['expires_at'] != null,
      'started_at': r['started_at'],
      'expires_at': r['expires_at'],
      'server_time': _iso(DateTime.now()),
      'shows_feedback': feedback,
      'questions': questions,
      'answers': [
        for (final a in (r['answers'] as List).cast<Map>())
          {
            'question_id': a['question_id'],
            'answer': a['answer'],
            if (feedback) ..._feedback(_question(subjectPacks, a['question_id'] as int)!, Map<String, dynamic>.from(a)),
          },
      ],
      'score': r['score'],
      'answer_streak': r['streak'],
      'offline': true,
    };
  }

  /// Grades an answer locally; the same JSON as POST /attempts/{id}/answer.
  Future<Map<String, dynamic>> answer(int localId, int questionId, Object value) async {
    final r = _record(localId);
    if (r == null || r['finished_at'] != null) throw const ApiException('Attempt is already finished', statusCode: 409);
    final now = DateTime.now();
    if (_expired(r, now)) throw const ApiException('Time is up', statusCode: 409);
    final answers = (r['answers'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (answers.any((a) => a['question_id'] == questionId)) {
      throw const ApiException('Question already answered', statusCode: 409);
    }
    final subjectPacks = await _packsFor(r['test_type'], r['reference_id']);
    final q = subjectPacks == null ? null : _question(subjectPacks, questionId);
    if (q == null || !isValidAnswer(q, value)) throw const ApiException('Invalid answer', statusCode: 422);

    final (official, correct) = grade(q, value);
    final streakBefore = r['streak'] as int;
    final (base, bonus) = pointsForAnswer(correct, streakBefore, official);
    final record = {
      'question_id': questionId,
      'answer': value,
      'answered_at': _iso(now),
      'is_correct': correct,
      'points': official,
      'points_awarded': base + bonus,
    };
    answers.add(record);
    r['answers'] = answers;
    r['streak'] = correct ? streakBefore + 1 : 0;
    r['score'] = (r['score'] as int) + base + bonus;
    await _save(r);

    final result = <String, dynamic>{
      'question_id': questionId,
      'answered_count': answers.length,
      'total_count': (r['question_ids'] as List).length,
    };
    if (_showsFeedback(r)) {
      result.addAll({
        ..._feedback(q, record),
        'max_points': q.maxPoints,
        'points_awarded': base + bonus,
        'streak_bonus': bonus > 0,
        'answer_streak': r['streak'],
        'attempt_score': r['score'],
      });
    }
    return result;
  }

  /// Closes the attempt and returns the result (same JSON as POST /attempts/{id}/finish).
  /// Bonuses and achievements are added by the server after the upload.
  Future<Map<String, dynamic>> finish(int localId) async {
    final r = _record(localId);
    if (r == null) throw const ApiException('Attempt not found', statusCode: 404);
    if (r['finished_at'] == null) {
      r['finished_at'] = _iso(DateTime.now());
      await _save(r);
      await _box.delete('local_ref_${r['test_type']}_${r['reference_id'] ?? 0}');
    }
    final result = await _resultJson(r);
    await _box.put('result_$localId', jsonEncode(result));
    return result;
  }

  Future<Map<String, dynamic>?> result(int localId) async {
    final saved = _box.get('result_$localId');
    if (saved != null) return Map<String, dynamic>.from(jsonDecode(saved));
    final r = _record(localId);
    return r == null ? null : _resultJson(r);
  }

  Future<Map<String, dynamic>> _resultJson(Map<String, dynamic> r) async {
    final subjectPacks = await _packsFor(r['test_type'], r['reference_id']) ?? const <int, SubjectPack>{};
    final lang = '${r['lang'] ?? 'tj'}';
    final answers = {
      for (final a in (r['answers'] as List).cast<Map>()) a['question_id'] as int: Map<String, dynamic>.from(a),
    };
    final review = <Map<String, dynamic>>[];
    var points = 0, maxPoints = 0, correct = 0;
    final bySubject = <int, Map<String, dynamic>>{};
    final cluster = r['test_type'] == 'mock_exam' ? packs.cluster(r['reference_id'] as int) : null;

    for (final id in (r['question_ids'] as List).cast<int>()) {
      final pack = _packOf(subjectPacks, id);
      if (pack == null) continue;
      final q = pack.byId[id]!;
      final a = answers[id];
      final got = (a?['points'] as int?) ?? 0;
      points += got;
      maxPoints += q.maxPoints;
      if (a?['is_correct'] == true) correct++;
      review.add({
        ..._questionJson(pack, q),
        'question_id': q.id,
        'answer': a?['answer'],
        'correct_option_index': correctSingleIndex(q),
        'correct_answer': q.answer,
        'is_correct': a?['is_correct'] == true,
        'points': got,
        'explanation': q.explanation,
      });
      if (cluster != null) {
        final link = cluster.subtests.where((s) => s.subjectId == pack.subjectId).firstOrNull;
        final e = bySubject.putIfAbsent(pack.subjectId, () => {
              'title': pack.title(lang),
              'position': link?.position ?? 9,
              'points': 0,
              'max_points': 0,
              'correct': 0,
              'total': 0,
              'max_score': link?.maxScore ?? 0,
            });
        e['points'] += got;
        e['max_points'] += q.maxPoints;
        e['correct'] += a?['is_correct'] == true ? 1 : 0;
        e['total'] += 1;
      }
    }
    final subjects = bySubject.values.toList()..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    for (final e in subjects) {
      final score = scaleSubtest(e['points'], e['max_points'], e['max_score']);
      e['score'] = (score * 10).round() / 10;
    }
    return {
      'attempt_id': r['local_id'],
      'test_type': r['test_type'],
      'reference_id': r['reference_id'],
      'correct_count': correct,
      'total_count': (r['question_ids'] as List).length,
      'answered_count': answers.length,
      'accuracy': maxPoints > 0 ? roundHalfEven(100 * points / maxPoints) : 0,
      'points': points,
      'max_points': maxPoints,
      'score': r['score'],
      'completion_bonus': 0,
      'mmt_score': cluster == null
          ? null
          : roundHalfEven(subjects.fold<double>(0, (sum, e) => sum + (e['score'] as num).toDouble())),
      'mmt_max': mmtMax,
      'subjects': subjects,
      'new_achievements': const [],
      'review': review,
      'pending_sync': true,
    };
  }
}

final offlineTestingProvider = Provider<OfflineTesting>((ref) => OfflineTesting(ref.watch(packStoreProvider)));
