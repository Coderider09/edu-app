import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
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

class ContentRepository {
  final ApiClient api;
  ContentRepository(this.api);

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

  Future<SubjectTree> subjectTree(int subjectId) async {
    final r = await api.get('/subjects/$subjectId/topics');
    return SubjectTree.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<List<Lesson>> lessons(int topicId) async {
    final r = await api.get('/topics/$topicId/lessons');
    return (r.data as List).map((e) => Lesson.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Lesson> lesson(int lessonId) async {
    final r = await api.get('/lessons/$lessonId');
    return Lesson.fromJson(Map<String, dynamic>.from(r.data));
  }

  Future<Lesson> completeLesson(int lessonId) async =>
      Lesson.fromJson(Map<String, dynamic>.from(await api.post('/lessons/$lessonId/complete')));

  Future<List<TopicTestInfo>> topicTests(int topicId) async {
    final r = await api.get('/topics/$topicId/tests');
    return (r.data as List).map((e) => TopicTestInfo.fromJson(Map<String, dynamic>.from(e))).toList();
  }
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
final contentRepositoryProvider = Provider((ref) => ContentRepository(ref.watch(apiClientProvider)));
final testingRepositoryProvider = Provider((ref) => TestingRepository(ref.watch(apiClientProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));
