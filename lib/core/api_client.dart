import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._({required this.baseUrl, required this.cookies}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'Accept': 'application/json',
          'X-MarketPlus-Client': 'flutter-mobile',
        },
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    dio.interceptors.add(CookieManager(cookies));
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.extra['startedAt'] = DateTime.now().microsecondsSinceEpoch;
            handler.next(options);
          },
          onResponse: (response, handler) {
            final started = response.requestOptions.extra['startedAt'] as int?;
            if (started != null) {
              final elapsedMs = (DateTime.now().microsecondsSinceEpoch - started) / 1000;
              debugPrint('[API] ${response.requestOptions.method} ${response.requestOptions.path} ${response.statusCode} ${elapsedMs.toStringAsFixed(1)}ms');
            }
            handler.next(response);
          },
        ),
      );
    }
  }

  static Future<ApiClient> create({String? baseUrl}) async {
    final support = await getApplicationSupportDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${support.path}/marketplus_cookies/'),
    );
    return ApiClient._(
      baseUrl: baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000'),
      cookies: cookieJar,
    );
  }

  final String baseUrl;
  final PersistCookieJar cookies;
  late final Dio dio;

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _guard(() => dio.get(path, queryParameters: queryParameters));

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _guard(() => dio.post(path, data: data));

  Future<Response<dynamic>> put(String path, {Object? data}) =>
      _guard(() => dio.put(path, data: data));

  Future<Response<dynamic>> delete(String path, {Object? data}) =>
      _guard(() => dio.delete(path, data: data));

  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 500;
      if (status >= 400) {
        final data = response.data;
        final message = data is Map
            ? (data['message'] ?? data['title'] ?? _fallbackMessage(status)).toString()
            : _fallbackMessage(status);
        throw ApiException(message, statusCode: status);
      }
      return response;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ApiException(
        status == null ? 'تعذر الاتصال بالخادم. تحقق من الشبكة وتشغيل MarketPlus.API.' : _fallbackMessage(status),
        statusCode: status,
      );
    }
  }

  static String _fallbackMessage(int status) => switch (status) {
        401 => 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.',
        403 => 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
        404 => 'العنصر المطلوب غير موجود.',
        409 => 'تعذر تنفيذ العملية بسبب تعارض في البيانات.',
        >= 500 => 'حدث خطأ في الخادم. حاول مرة أخرى.',
        _ => 'تعذر تنفيذ الطلب.',
      };

  dynamic unwrap(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) return raw['data'];
    return raw;
  }
}
