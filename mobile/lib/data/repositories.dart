import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:math';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../offline/engine.dart';
import '../offline/pack_store.dart';
import '../offline/sync_service.dart';
import 'models.dart';

class AuthRepository {
  final ApiClient api;
  AuthRepository(this.api);

  /// Returns true when the user still has to choose a role.
  Future<bool> _store(dynamic data) async {
    await AppConfig.saveTokens(data['access_token'], data['refresh_token']);
    return data['needs_onboarding'] == true;
  }

  Future<bool> login(String login, String password) async =>
      _store(await api.postForm('/auth/login', {'username': login, 'password': password}));

  Future<bool> register({
    required String name,
    required String password,
    String? email,
    String? phone,
    required String language,
  }) async =>
      _store(await api.post('/auth/register', data: {
        'name': name,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'language': language,
      }));

  Future<bool> google(String idToken, String language) async =>
      _store(await api.post('/auth/oauth/google', data: {'id_token': idToken, 'language': language}));
}

/// Content from the API; without internet (and no cached response) — from downloaded packs.
class ContentRepository {
  final ApiClient api;
  final PackStore? packs;
  final SyncService? sync;
  final String Function()? language;
  ContentRepository(this.api, {this.packs, this.sync, this.language});

  String get _lang => language?.call() ?? 'tj';

  Future<T> _orPack<T>(Future<T> Function() online, Future<T?> Function(PackStore packs) offline) async {
    try {
      return await online();
    } on ApiException catch (e) {
      if (!e.offline || packs == null) rethrow;
      final local = await offline(packs!);
      if (local == null) rethrow;
      return local;
    }
  }

  Map<String, dynamic> _treeJson(SubjectPack pack) {
    final lang = _lang;
    final counts = <int, int>{};
    for (final q in pack.questions) {
      if (q.inTopicPool && q.topicId != null) counts[q.topicId!] = (counts[q.topicId!] ?? 0) + 1;
    }
    Map<String, dynamic> progress(int topicId) => {
          'lessons_total': _topicLessons(pack, topicId).length,
          'lessons_completed': 0,
          'questions_count': counts[topicId] ?? 0,
          'best_accuracy': null,
          'passed': false,
          'percent': 0,
        };
    Map<String, dynamic> topic(PackTopic t) => {'id': t.id, 'title': t.title(lang), 'progress': progress(t.id)};
    Map<String, dynamic> section(PackTopic root) {
      final children = pack.topics.where((t) => t.parentId == root.id).toList();
      final questions = children.fold<int>(counts[root.id] ?? 0, (sum, c) => sum + (counts[c.id] ?? 0));
      return {
        'id': root.id,
        'title': root.title(lang),
        'has_final_test': children.isNotEmpty && questions > 0,
        'topics': children.isEmpty ? [topic(root)] : children.map(topic).toList(),
        'progress': progress(root.id),
      };
    }

    return {
      'subject': {
        'id': pack.subjectId,
        'code': pack.code,
        'title': pack.title(lang),
        'icon': pack.icon,
        'color': pack.color,
        'grade': pack.grade,
      },
      'sections': [for (final root in pack.topics.where((t) => t.parentId == null)) section(root)],
    };
  }

  /// Lessons of a topic in the content language, falling back to the other language.
  List<PackLesson> _topicLessons(SubjectPack pack, int topicId) {
    final all = pack.lessons.where((l) => l.topicId == topicId).toList();
    final own = all.where((l) => l.language == _lang).toList();
    return own.isNotEmpty ? own : all;
  }

  Lesson _lessonFromPack(SubjectPack pack, PackLesson l, {bool completed = false}) => Lesson.fromJson({
        'id': l.id,
        'topic_id': l.topicId,
        'title': l.title,
        'content': l.content,
        'media_urls': l.mediaUrls,
        'video_url': l.videoUrl,
        'check_questions_count': pack.questions.where((q) => q.lessonId == l.id).length,
        'completed': completed || (sync?.queuedLessonIds.contains(l.id) ?? false),
      });

  Future<List<Cluster>> clusters(String lang) async {
    final r = await api.get('/clusters', query: {'lang': lang});
    return (r.data as List).map((e) => Cluster.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Region>> regions() async {
    final r = await api.get('/regions');
    return (r.data as List).map((e) => Region.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Dashboard> dashboard() async {
    final r = await api.get('/dashboard');
    return Dashboard.fromJson(Map<String, dynamic>.from(r.data), fromCache: r.fromCache);
  }

  Future<ClusterScreenData> clusterScreen(int clusterId) async {
    final r = await api.get('/clusters/$clusterId');
    return ClusterScreenData.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<List<ExamTestInfo>> examTests({int? clusterId}) async {
    final r = await api.get('/exam-tests', query: {if (clusterId != null) 'cluster_id': clusterId});
    return (r.data as List).map((e) => ExamTestInfo.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<SubjectTree> subjectTree(int subjectId) => _orPack(() async {
        final r = await api.get('/subjects/$subjectId/topics');
        return SubjectTree.fromJson(Map<String, dynamic>.from(r.data));
      }, (packs) async {
        final pack = await packs.load(subjectId);
        return pack == null ? null : SubjectTree.fromJson(_treeJson(pack));
      });

  Future<List<Lesson>> lessons(int topicId) => _orPack(() async {
        final r = await api.get('/topics/$topicId/lessons');
        return (r.data as List).map((e) => Lesson.fromJson(Map<String, dynamic>.from(e))).toList();
      }, (packs) async {
        final pack = await packs.forTopic(topicId);
        return pack == null ? null : [for (final l in _topicLessons(pack, topicId)) _lessonFromPack(pack, l)];
      });

  Future<Lesson> lesson(int lessonId) => _orPack(() async {
        final r = await api.get('/lessons/$lessonId');
        return Lesson.fromJson(Map<String, dynamic>.from(r.data));
      }, (packs) async {
        final pack = await packs.forLesson(lessonId);
        final l = pack?.lesson(lessonId);
        return l == null ? null : _lessonFromPack(pack!, l);
      });

  /// Offline the lesson is marked on the device and uploaded with the next sync.
  Future<Lesson> completeLesson(int lessonId) => _orPack(
          () async => Lesson.fromJson(Map<String, dynamic>.from(await api.post('/lessons/$lessonId/complete'))),
          (packs) async {
        final pack = await packs.forLesson(lessonId);
        final l = pack?.lesson(lessonId);
        if (l == null || sync == null) return null;
        await sync!.queueLesson(lessonId);
        return _lessonFromPack(pack!, l, completed: true);
      });

  Future<List<TopicTestInfo>> topicTests(int topicId) => _orPack(() async {
        final r = await api.get('/topics/$topicId/tests');
        return (r.data as List).map((e) => TopicTestInfo.fromJson(Map<String, dynamic>.from(e))).toList();
      }, (packs) async {
        final pack = await packs.forTopic(topicId);
        final topic = pack?.topic(topicId);
        if (topic == null) return null;
        final count = pack!.questions.where((q) => q.topicId == topicId && q.inTopicPool).length;
        if (count == 0) return <TopicTestInfo>[];
        return [
          TopicTestInfo.fromJson({
            'topic_id': topicId,
            'title': topic.title(_lang),
            'questions_count': count,
            'default_question_count': min(count, topicTestMax),
            'time_limit_seconds_per_question': 60,
            'best_accuracy': null,
            'attempts_count': 0,
          }),
        ];
      });
}

class TestingRepository {
  final ApiClient api;
  TestingRepository(this.api);

  /// Raw JSON so the attempt can be stored locally and resumed offline.
  Future<Map<String, dynamic>> start(String testType, {int? referenceId, bool timed = false, int? questionCount}) async =>
      Map<String, dynamic>.from(await api.post('/attempts', data: {
        'test_type': testType,
        if (referenceId != null) 'reference_id': referenceId,
        'timed': timed,
        if (questionCount != null) 'question_count': questionCount,
      }));

  /// [value]: option index (single), option indices for A–D (matching) or digits (numeric).
  Future<Map<String, dynamic>> answer(int attemptId, int questionId, Object value) async =>
      Map<String, dynamic>.from(await api.post('/attempts/$attemptId/answer', data: {
        'question_id': questionId,
        if (value is int) 'selected_option_index': value else 'answer': value,
      }));

  Future<AttemptResult> finish(int attemptId) async =>
      AttemptResult.fromJson(Map<String, dynamic>.from(await api.post('/attempts/$attemptId/finish')));

  Future<AttemptResult> result(int attemptId) async {
    final r = await api.get('/attempts/$attemptId/result');
    return AttemptResult.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<void> mark(int questionId, bool marked) async {
    if (marked) {
      await api.post('/questions/$questionId/mark');
    } else {
      await api.delete('/questions/$questionId/mark');
    }
  }
}

class ProfileRepository {
  final ApiClient api;
  ProfileRepository(this.api);

  Future<Profile> me() async {
    final r = await api.get('/profile/me');
    return Profile.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<Profile> update(Map<String, dynamic> changes) async =>
      Profile.fromJson(Map<String, dynamic>.from(await api.patch('/profile/me', data: changes)));

  Future<Profile> setRole(Map<String, dynamic> body) async =>
      Profile.fromJson(Map<String, dynamic>.from(await api.post('/profile/role', data: body)));

  Future<List<SubjectProgress>> progress() async {
    final r = await api.get('/profile/me/progress');
    return (r.data['subjects'] as List).map((e) => SubjectProgress.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<HistoryItem>> history() async {
    final r = await api.get('/profile/me/history');
    return (r.data as List).map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<AchievementInfo>> achievements() async {
    final r = await api.get('/profile/me/achievements');
    return (r.data as List).map((e) => AchievementInfo.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Leaderboard> leaderboard({required String scope, required String period}) async {
    final r = await api.get('/leaderboard', query: {'scope': scope, 'period': period});
    return Leaderboard.fromJson(Map<String, dynamic>.from(r.data));
  }
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final contentRepositoryProvider = Provider((ref) => ContentRepository(
      ref.watch(apiClientProvider),
      packs: ref.watch(packStoreProvider),
      sync: ref.watch(syncServiceProvider),
      language: () => ref.read(sessionProvider).profile?.contentLanguage ?? 'tj',
    ));
final testingRepositoryProvider = Provider((ref) => TestingRepository(ref.watch(apiClientProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));
