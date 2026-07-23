import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/constants/app_constants.dart';
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
      final body = response.data;
      if (body is! Map) {
        throw const ProcessingException(
          'O servidor retornou um status em formato inválido.',
        );
      }
      final data = Map<String, dynamic>.from(body);
      return ProcessingJob(
        jobId: jobId,
        status: ProcessingJob.parseStatus(data['status'] as String?),
        message: data['message'] as String?,
        modelUrl: data['modelUrl'] is String
            ? AppConstants.resolveBackendUrl(data['modelUrl'] as String)
            : null,
        productId: (data['productId'] as num?)?.toInt(),
        error: data['error'] as String?,
      );
    } on DioException catch (e) {
      throw ProcessingException(
        _describeStatusFailure(e),
        e,
      );
    } on ProcessingException {
      rethrow;
    } catch (e) {
      throw ProcessingException(
        'Não foi possível interpretar o andamento retornado pelo servidor.',
        e,
      );
    }
  }
}

String _describeStatusFailure(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return 'Tempo limite ao conectar com o servidor.';
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'O servidor demorou para responder à consulta de andamento.';
    case DioExceptionType.connectionError:
      return 'Não foi possível alcançar o servidor pela rede local.';
    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;
      return statusCode == null
          ? 'O servidor recusou a consulta de andamento.'
          : 'O servidor respondeu com HTTP $statusCode ao consultar o andamento.';
    case DioExceptionType.cancel:
      return 'A consulta de andamento foi cancelada.';
    case DioExceptionType.badCertificate:
      return 'O certificado do servidor não pôde ser validado.';
    case DioExceptionType.unknown:
      return 'A conexão com o servidor foi interrompida temporariamente.';
  }
}

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  return ProcessingRepositoryImpl(ref.watch(dioClientProvider));
});
