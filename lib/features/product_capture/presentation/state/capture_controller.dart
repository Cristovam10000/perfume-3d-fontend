import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_quality_analyzer.dart';
import '../../data/capture_repository.dart';
import 'capture_state.dart';

/// Controla a captura guiada por vista cardeal.
///
/// API principal:
/// - [captureForView]: abre a câmera e atribui o resultado a uma vista.
/// - [setCardinal] / [removeCardinal]: gerenciam slots de vistas cardeais.
/// - [addExtra] / [removeExtraAt]: gerenciam fotos extras.
/// - [submit]: envia ao backend com o campo `views` paralelo a `images`.
class CaptureController extends StateNotifier<CaptureState> {
  CaptureController(this._ref) : super(const CaptureState()) {
    _recomputeQuality();
  }

  final Ref _ref;
  final ImagePicker _picker = ImagePicker();
  static const _analyzer = ImageQualityAnalyzer();

  void _recomputeQuality() {
    state = state.copyWith(
      qualityMessages: _analyzer.evaluate(
        cardinalCount: state.cardinalCount,
        extrasCount: state.extras.length,
      ),
    );
  }

  /// Atribui um arquivo capturado a uma vista cardeal específica.
  ///
  /// Se [view] for `extra`, adiciona à lista de extras (respeitando o limite).
  /// Se for uma cardeal, substitui o slot — útil para "refazer".
  void setCardinal(String view, File file) {
    if (view == 'extra') {
      addExtra(file);
      return;
    }
    if (!AppConstants.cardinalViews.contains(view)) {
      state = state.copyWith(error: 'Vista inválida: $view');
      return;
    }
    final updated = Map<String, File?>.from(state.cardinals);
    updated[view] = file;
    state = state.copyWith(cardinals: updated, clearError: true);
    _recomputeQuality();
  }

  /// Remove a foto de uma vista cardeal (volta o slot a vazio).
  void removeCardinal(String view) {
    if (!AppConstants.cardinalViews.contains(view)) return;
    final updated = Map<String, File?>.from(state.cardinals);
    updated[view] = null;
    state = state.copyWith(cardinals: updated);
    _recomputeQuality();
  }

  /// Adiciona uma foto extra (não rotulada), se houver espaço.
  void addExtra(File file) {
    if (!state.canAddExtra) return;
    state = state.copyWith(
      extras: [...state.extras, file],
      clearError: true,
    );
    _recomputeQuality();
  }

  void removeExtraAt(int index) {
    if (index < 0 || index >= state.extras.length) return;
    final updated = [...state.extras]..removeAt(index);
    state = state.copyWith(extras: updated);
    _recomputeQuality();
  }

  /// Captura via câmera nativa (image_picker) e atribui à vista alvo.
  /// Útil para fluxos sem o `CameraController` customizado.
  Future<void> captureForView(String view) async {
    if (state.uploading) return;
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (xfile == null) return;
      setCardinal(view, File(xfile.path));
    } catch (e) {
      state = state.copyWith(error: 'Falha ao acessar a câmera: $e');
    }
  }

  /// Seleciona uma única imagem da galeria e atribui a uma vista.
  Future<void> pickFromGalleryForView(String view) async {
    if (state.selectingFromGallery) return;
    state = state.copyWith(selectingFromGallery: true, clearError: true);
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (xfile != null) {
        setCardinal(view, File(xfile.path));
      }
    } on PlatformException catch (e) {
      final message = e.code == 'already_active'
          ? 'A galeria ainda está aberta. Aguarde e tente novamente.'
          : 'Falha ao selecionar imagem: $e';
      state = state.copyWith(error: message);
    } catch (e) {
      state = state.copyWith(error: 'Falha ao selecionar imagem: $e');
    } finally {
      state = state.copyWith(selectingFromGallery: false);
    }
  }

  void clear() {
    state = const CaptureState();
    _recomputeQuality();
  }

  /// Envia as imagens com seus rótulos de vista e retorna o jobId.
  ///
  /// Não navega; a UI observa e decide. Exige que todas as 4 cardeais
  /// estejam preenchidas (`state.allCardinalsFilled`).
  Future<String?> submit() async {
    if (!state.allCardinalsFilled) {
      state = state.copyWith(
        error: 'Capture as 4 vistas (frente, esquerda, trás, direita) antes de enviar.',
      );
      return null;
    }
    final upload = state.flattenForUpload();
    state = state.copyWith(
      uploading: true,
      uploadProgress: 0,
      clearError: true,
    );
    try {
      final repo = _ref.read(captureRepositoryProvider);
      final result = await repo.uploadImages(
        upload.files,
        views: upload.views,
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
