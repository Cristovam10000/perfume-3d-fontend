import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';

/// Resultado do envio: jobId usado para acompanhar o processamento.
class UploadResult {
  final String jobId;
  const UploadResult(this.jobId);
}

abstract class CaptureRepository {
  /// Envia as imagens com rótulos de vista paralelos.
  ///
  /// [views] deve ter o mesmo tamanho de [images]. Cada valor é um dos:
  /// `front`, `left`, `back`, `right`, `extra` ou `''` (sem rótulo).
  /// Quando omitido ou vazio, o backend usa CLIPViewRouter.
  Future<UploadResult> uploadImages(
    List<File> images, {
    List<String>? views,
    int? productId,
    void Function(double progress)? onProgress,
  });
}

class CaptureRepositoryImpl implements CaptureRepository {
  final Dio _dio;
  CaptureRepositoryImpl(this._dio);

  @override
  Future<UploadResult> uploadImages(
    List<File> images, {
    List<String>? views,
    int? productId,
    void Function(double progress)? onProgress,
  }) async {
    if (views != null && views.length != images.length) {
      throw UploadException(
        'Quantidade de views (${views.length}) precisa bater com imagens (${images.length}).',
      );
    }
    try {
      final formMap = <String, dynamic>{
        'images': [
          for (final f in images)
            await MultipartFile.fromFile(
              f.path,
              filename: f.uri.pathSegments.last,
            ),
        ],
      };
      if (views != null && views.isNotEmpty) {
        formMap['views'] = views;
      }
      if (productId != null) {
        formMap['productId'] = productId;
      }
      final formData = FormData.fromMap(formMap);

      final response = await _dio.post(
        '/captures',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final data = response.data;
      if (data is Map && data['jobId'] is String) {
        return UploadResult(data['jobId'] as String);
      }
      throw const UploadException('Resposta de upload inválida do servidor.');
    } on DioException catch (e) {
      throw UploadException(
        'Falha ao enviar imagens: ${e.message ?? e.type.name}',
        e,
      );
    }
  }
}

final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return CaptureRepositoryImpl(ref.watch(dioClientProvider));
});
