import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_quality_analyzer.dart';
import '../../data/capture_repository.dart';
import 'capture_state.dart';

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController(this._ref) : super(const CaptureState()) {
    _recomputeQuality();
  }

  final Ref _ref;
  final ImagePicker _picker = ImagePicker();
  static const _analyzer = ImageQualityAnalyzer();

  void _recomputeQuality() {
    state = state.copyWith(
      qualityMessages: _analyzer.evaluate(imageCount: state.images.length),
    );
  }

  Future<void> captureFromCamera() async {
    if (state.images.length >= AppConstants.maxImages) return;
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (xfile == null) return;
      addCapturedFile(File(xfile.path));
    } catch (e) {
      state = state.copyWith(error: 'Falha ao acessar a câmera: $e');
    }
  }

  /// Adiciona ao estado um arquivo já capturado externamente (ex.: pelo
  /// CameraController da própria página de captura).
  void addCapturedFile(File file) {
    if (state.images.length >= AppConstants.maxImages) return;
    final updated = [...state.images, file];
    state = state.copyWith(images: updated, clearError: true);
    _recomputeQuality();
  }

  Future<void> pickFromGallery() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) return;
      final merged = [...state.images, ...files.map((x) => File(x.path))];
      final capped = merged.length > AppConstants.maxImages
          ? merged.sublist(0, AppConstants.maxImages)
          : merged;
      state = state.copyWith(images: capped, clearError: true);
      _recomputeQuality();
    } catch (e) {
      state = state.copyWith(error: 'Falha ao selecionar imagens: $e');
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.images.length) return;
    final updated = [...state.images]..removeAt(index);
    state = state.copyWith(images: updated);
    _recomputeQuality();
  }

  void clear() {
    state = const CaptureState();
    _recomputeQuality();
  }

  /// Envia as imagens e retorna o jobId para acompanhamento.
  /// Não realiza navegação; a UI observa e decide.
  Future<String?> submit() async {
    if (state.images.isEmpty) return null;
    state = state.copyWith(uploading: true, uploadProgress: 0, clearError: true);
    try {
      final repo = _ref.read(captureRepositoryProvider);
      final result = await repo.uploadImages(
        state.images,
        onProgress: (p) =>
            state = state.copyWith(uploadProgress: p),
      );
      state = state.copyWith(uploading: false, uploadProgress: 1);
      return result.jobId;
    } catch (e) {
      state = state.copyWith(
        uploading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

final captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>((ref) {
  return CaptureController(ref);
});
