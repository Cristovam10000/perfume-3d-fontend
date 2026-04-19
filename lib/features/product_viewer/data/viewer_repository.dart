import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product_model.dart';

abstract class ViewerRepository {
  /// Retorna metadados do produto associado a um modelo 3D, quando disponíveis.
  Future<ProductModel> loadModel(String modelUrl);
}

class ViewerRepositoryImpl implements ViewerRepository {
  ViewerRepositoryImpl();

  @override
  Future<ProductModel> loadModel(String modelUrl) async {
    // No MVP, o backend não expõe metadados: retornamos apenas a URL.
    // Caso passe a expor, basta consultar /models/<id> aqui.
    return ProductModel(modelUrl: modelUrl);
  }
}

final viewerRepositoryProvider = Provider<ViewerRepository>((ref) {
  return ViewerRepositoryImpl();
});
