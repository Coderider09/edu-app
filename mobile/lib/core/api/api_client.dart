import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool offline;
  const ApiException(this.message, {this.statusCode, this.offline = false});

  @override
  String toString() => message;
}

/// A GET response, possibly served from the offline cache.
class ApiResult<T> {
  final T data;
  final bool fromCache;
  const ApiResult(this.data, {this.fromCache = false});
}

/// HTTP client: JWT auth with transparent refresh, and a cache-on-failure strategy for GET
/// requests so lessons and already loaded content stay available without internet.
class ApiClient {
  final Dio _dio;
  final Dio _refreshDio;
  void Function()? onSessionExpired;

  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        )),
        _refreshDio = Dio(BaseOptions(baseUrl: '${AppConfig.apiBaseUrl}/api/v1')) {
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AppConfig.getAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthCall = error.requestOptions.path.startsWith('/auth/');
        if (error.response?.statusCode == 401 && !isAuthCall && error.requestOptions.extra['retried'] != true) {
          if (await _refresh()) {
            final opts = error.requestOptions..extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer ${await AppConfig.getAccessToken()}';
            try {
              return handler.resolve(await _dio.fetch(opts));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          onSessionExpired?.call();
        }
        handler.next(error);
      },
    ));
  }

  Box<String> get _cache => Hive.box<String>(AppConfig.cacheBox);

  Future<bool> _refresh() async {
    final refresh = await AppConfig.getRefreshToken();
    if (refresh == null) return false;
    try {
      final resp = await _refreshDio.post('/auth/refresh', data: {'refresh_token': refresh});
      await AppConfig.saveTokens(resp.data['access_token'], resp.data['refresh_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      (e.type == DioExceptionType.unknown && e.response == null);

  static ApiException _toApiException(DioException e) {
    if (_isNetworkError(e)) return const ApiException('offline', offline: true);
    final data = e.response?.data;
    var message = 'error';
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      message = detail is String ? detail : jsonEncode(detail);
    }
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  String _cacheKey(String path, Map<String, dynamic>? query) =>
      query == null || query.isEmpty ? path : '$path?${Uri(queryParameters: query.map((k, v) => MapEntry(k, '$v'))).query}';

  /// GET with offline fallback: on network failure returns the last cached response.
  Future<ApiResult<dynamic>> get(String path, {Map<String, dynamic>? query, bool cache = true}) async {
    final key = _cacheKey(path, query);
    try {
      final resp = await _dio.get(path, queryParameters: query);
      if (cache) await _cache.put(key, jsonEncode(resp.data));
      return ApiResult(resp.data);
    } on DioException catch (e) {
      final error = _toApiException(e);
      if (error.offline && cache) {
        final cached = _cache.get(key);
        if (cached != null) return ApiResult(jsonDecode(cached), fromCache: true);
      }
      throw error;
    }
  }

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post(path, data: data));

  /// Downloads a file (offline packs) to [savePath]; [onProgress] gets (received, total bytes).
  Future<void> download(String path, String savePath, {void Function(int, int)? onProgress}) =>
      _send(() => _dio.download(
            path,
            savePath,
            onReceiveProgress: onProgress,
            options: Options(receiveTimeout: const Duration(minutes: 10)),
          ));
  Future<dynamic> patch(String path, {Object? data}) => _send(() => _dio.patch(path, data: data));
  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  /// OAuth2 password form used by /auth/login.
  Future<dynamic> postForm(String path, Map<String, String> fields) => _send(() => _dio.post(
        path,
        data: fields,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
