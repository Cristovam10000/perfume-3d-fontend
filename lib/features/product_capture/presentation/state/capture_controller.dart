import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

  int _addPickedFiles(List<XFile> files) {
    if (files.isEmpty) return 0;
    final remaining = AppConstants.maxImages - state.images.length;
    if (remaining <= 0) return 0;

    final selected = files.take(remaining).map((x) => File(x.path)).toList();
    final merged = [...state.images, ...selected];
    final capped = merged.length > AppConstants.maxImages
        ? merged.sublist(0, AppConstants.maxImages)
        : merged;
    state = state.copyWith(images: capped, clearError: true);
    _recomputeQuality();
    return selected.length;
  }

  Future<int> pickFromGallery() async {
    if (state.selectingFromGallery) return 0;
    state = state.copyWith(selectingFromGallery: true, clearError: true);
    try {
      final files = await _picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) {
        state = state.copyWith(selectingFromGallery: false);
        return 0;
      }

      final added = _addPickedFiles(files);
      state = state.copyWith(selectingFromGallery: false);
      return added;
    } on PlatformException catch (e) {
      final message = e.code == 'already_active'
          ? 'A galeria ainda está aberta ou processando a seleção anterior. Aguarde alguns segundos e tente novamente.'
          : 'Falha ao selecionar imagens: $e';
      state = state.copyWith(
        selectingFromGallery: false,
        error: message,
      );
      return 0;
    } catch (e) {
      state = state.copyWith(
        selectingFromGallery: false,
        error: 'Falha ao selecionar imagens: $e',
      );
      return 0;
    }
  }

  Future<int> recoverLostGallerySelection() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return 0;
      if (response.exception != null) {
        state = state.copyWith(
          error:
              'Falha ao recuperar imagens selecionadas: ${response.exception}',
        );
        return 0;
      }

      final files = response.files;
      if (files == null || files.isEmpty) return 0;
      return _addPickedFiles(files);
    } catch (e) {
      state = state.copyWith(
        error: 'Falha ao recuperar imagens selecionadas: $e',
      );
      return 0;
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
    state =
        state.copyWith(uploading: true, uploadProgress: 0, clearError: true);
    try {
      final repo = _ref.read(captureRepositoryProvider);
      final result = await repo.uploadImages(
        state.images,
        onProgress: (p) => state = state.copyWith(uploadProgress: p),
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
