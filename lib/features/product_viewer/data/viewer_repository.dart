import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/product_model.dart';

abstract class ViewerRepository {
  /// Retorna metadados do produto associado a um modelo 3D, quando disponíveis.
  Future<ProductModel> loadModel(String modelUrl);
}

class ViewerRepositoryImpl implements ViewerRepository {
  final Dio _dio;
  ViewerRepositoryImpl(this._dio);

  @override
  Future<ProductModel> loadModel(String modelUrl) async {
    // No MVP, o backend não expõe metadados: retornamos apenas a URL.
    // Caso passe a expor, basta consultar /models/<id> aqui.
    try {
      return ProductModel(modelUrl: modelUrl);
    } on DioException catch (e) {
      throw NetworkException('Falha ao carregar modelo: ${e.message}', e);
    }
  }
}

final viewerRepositoryProvider = Provider<ViewerRepository>((ref) {
  return ViewerRepositoryImpl(ref.watch(dioClientProvider));
});
