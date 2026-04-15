import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/processing_job.dart';

abstract class ProcessingRepository {
  Future<ProcessingJob> fetchStatus(String jobId);
}

class ProcessingRepositoryImpl implements ProcessingRepository {
  final Dio _dio;
  ProcessingRepositoryImpl(this._dio);

  @override
  Future<ProcessingJob> fetchStatus(String jobId) async {
    try {
      final response = await _dio.get('/captures/$jobId/status');
      final data = response.data as Map<String, dynamic>;
      return ProcessingJob(
        jobId: jobId,
        status: ProcessingJob.parseStatus(data['status'] as String?),
        message: data['message'] as String?,
        modelUrl: data['modelUrl'] as String?,
        error: data['error'] as String?,
      );
    } on DioException catch (e) {
      throw ProcessingException(
        'Falha ao consultar status: ${e.message ?? e.type.name}',
        e,
      );
    }
  }
}

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  return ProcessingRepositoryImpl(ref.watch(dioClientProvider));
});
