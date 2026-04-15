import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.backendBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) {
        // Em MVP, usar debugPrint evita poluir em release.
        assert(() {
          // ignore: avoid_print
          print(obj);
          return true;
        }());
      },
    ),
  );

  return dio;
});
