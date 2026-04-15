import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/viewer_repository.dart';
import '../../domain/product_model.dart';

class ViewerState {
  final bool loading;
  final ProductModel? model;
  final String? error;

  const ViewerState({
    this.loading = false,
    this.model,
    this.error,
  });

  ViewerState copyWith({
    bool? loading,
    ProductModel? model,
    String? error,
    bool clearError = false,
  }) {
    return ViewerState(
      loading: loading ?? this.loading,
      model: model ?? this.model,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ViewerController extends StateNotifier<ViewerState> {
  ViewerController(this._ref) : super(const ViewerState());
  final Ref _ref;

  Future<void> load(String modelUrl) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final repo = _ref.read(viewerRepositoryProvider);
      final model = await repo.loadModel(modelUrl);
      state = state.copyWith(loading: false, model: model);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void reset() => state = const ViewerState();
}

final viewerControllerProvider =
    StateNotifierProvider<ViewerController, ViewerState>((ref) {
  return ViewerController(ref);
});
