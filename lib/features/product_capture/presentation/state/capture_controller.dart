import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_quality_analyzer.dart';
import '../../data/capture_repository.dart';
import '../../data/capture_session_store.dart';
import 'capture_state.dart';

/// Controla a captura guiada e mantém um rascunho recuperável no dispositivo.
class CaptureController extends StateNotifier<CaptureState> {
  CaptureController({
    required CaptureRepository repository,
    required ImagePicker picker,
    required CaptureSessionStore sessionStore,
    required bool enableLostDataRecovery,
  })  : _repository = repository,
        _picker = picker,
        _sessionStore = sessionStore,
        _enableLostDataRecovery = enableLostDataRecovery,
        super(const CaptureState()) {
    _recomputeQuality();
    ready = _initialize();
  }

  final CaptureRepository _repository;
  final ImagePicker _picker;
  final CaptureSessionStore _sessionStore;
  final bool _enableLostDataRecovery;
  static const _analyzer = ImageQualityAnalyzer();

  late final Future<void> ready;
  String? _pendingTarget;
  bool _recovering = false;

  Future<void> _initialize() async {
    try {
      final draft = await _sessionStore.load();
      _pendingTarget =
          _isValidTarget(draft.pendingTarget) ? draft.pendingTarget : null;

      final cardinals = <String, File?>{
        for (final view in AppConstants.cardinalViews) view: null,
      };
      for (final view in AppConstants.cardinalViews) {
        final path = draft.cardinalPaths[view];
        if (path != null && await File(path).exists()) {
          cardinals[view] = File(path);
        }
      }

      File? top;
      final topPath = draft.topPath;
      if (topPath != null && await File(topPath).exists()) {
        top = File(topPath);
      }

      final extras = <File>[];
      for (final path in draft.extraPaths.take(AppConstants.maxExtras)) {
        if (await File(path).exists()) extras.add(File(path));
      }

      state = state.copyWith(
        cardinals: cardinals,
        top: top,
        clearTop: top == null,
        extras: extras,
      );
      state = state.copyWith(
        productId: draft.productId,
        clearProductId: draft.productId == null,
        material: draft.material,
        clearMaterial: draft.material == null,
      );
      _recomputeQuality();
      await recoverLostSelection();
      await _persistDraft();
    } catch (error) {
      state = state.copyWith(
        selectingImage: false,
        error: 'Falha ao restaurar a captura anterior: $error',
      );
    }
  }

  void _recomputeQuality() {
    state = state.copyWith(
      qualityMessages: _analyzer.evaluate(
        cardinalCount: state.cardinalCount,
        hasTop: state.top != null,
        extrasCount: state.extras.length,
      ),
    );
  }

  Future<void> setProductId(int? productId) async {
    await ready;
    if (state.productId == productId) return;
    final hasImages = state.totalCount > 0;
    if (hasImages) {
      await _sessionStore.clear();
    }
    state = hasImages
        ? CaptureState(productId: productId)
        : state.copyWith(
            productId: productId,
            clearProductId: productId == null,
          );
    _recomputeQuality();
    await _persistDraftSafely();
  }

  /// Declara o material do frasco (`glass` / `opaque`) ou limpa a escolha.
  ///
  /// Sem escolha o backend classifica sozinho pelo CLIP — que erra, e é o
  /// motivo desta pergunta existir. Tocar na opção já marcada desmarca.
  void setMaterial(String? material) {
    if (material != null &&
        !AppConstants.materialLabels.containsKey(material)) {
      state = state.copyWith(error: 'Material inválido: $material');
      return;
    }
    state = state.copyWith(
      material: material,
      clearMaterial: material == null,
    );
    _persistLater();
  }

  void setCardinal(String view, File file) {
    if (view == 'extra') {
      addExtra(file);
      return;
    }
    if (!AppConstants.cardinalViews.contains(view)) {
      state = state.copyWith(error: 'Vista inválida: $view');
      return;
    }
    _setTargetFile(view, file);
  }

  void removeCardinal(String view) {
    if (!AppConstants.cardinalViews.contains(view)) return;
    final updated = Map<String, File?>.from(state.cardinals);
    updated[view] = null;
    state = state.copyWith(cardinals: updated);
    _recomputeQuality();
    _persistLater();
  }

  void setTop(File file) {
    _setTargetFile(AppConstants.topView, file);
  }

  void removeTop() {
    if (state.top == null) return;
    state = state.copyWith(clearTop: true);
    _recomputeQuality();
    _persistLater();
  }

  void addExtra(File file) {
    if (!state.canAddExtra) return;
    _setTargetFile('extra', file);
  }

  void removeExtraAt(int index) {
    if (index < 0 || index >= state.extras.length) return;
    final updated = [...state.extras]..removeAt(index);
    state = state.copyWith(extras: updated);
    _recomputeQuality();
    _persistLater();
  }

  Future<void> captureForView(String view) {
    return _pickForTarget(view, ImageSource.camera);
  }

  Future<void> pickFromGalleryForView(String view) {
    return _pickForTarget(view, ImageSource.gallery);
  }

  Future<void> pickExtra(ImageSource source) {
    return _pickForTarget('extra', source);
  }

  Future<void> _pickForTarget(String target, ImageSource source) async {
    await ready;
    if (state.uploading || state.selectingImage) return;
    if (!_isValidTarget(target)) {
      state = state.copyWith(error: 'Vista inválida: $target');
      return;
    }
    if (target == 'extra' && !state.canAddExtra) return;

    _pendingTarget = target;
    state = state.copyWith(selectingImage: true, clearError: true);
    try {
      // O alvo precisa chegar ao disco antes de o Android abrir outra Activity.
      await _persistDraft();

      // Sem imageQuality/maxWidth/maxHeight: o plugin devolve o JPEG original
      // sem decodificar uma foto de 50 MP apenas para recomprimi-la.
      final picked = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      final stored = await _sessionStore.importFile(
        File(picked.path),
        target,
      );
      _setTargetFile(target, stored, persist: false);
    } on PlatformException catch (error) {
      final message = error.code == 'already_active'
          ? 'A câmera ou galeria ainda está aberta. Aguarde e tente novamente.'
          : _pickerErrorMessage(source, error);
      state = state.copyWith(error: message);
    } catch (error) {
      state = state.copyWith(error: _pickerErrorMessage(source, error));
    } finally {
      _pendingTarget = null;
      state = state.copyWith(selectingImage: false);
      await _persistDraftSafely();
    }
  }

  /// Recupera o resultado salvo pelo `image_picker` após morte da Activity.
  Future<bool> recoverLostSelection() async {
    if (!_enableLostDataRecovery || _recovering) return false;
    _recovering = true;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        _pendingTarget = null;
        return false;
      }
      if (response.exception != null) {
        throw response.exception!;
      }
      if (response.type != null && response.type != RetrieveType.image) {
        throw StateError('O item recuperado não é uma imagem.');
      }

      final files = response.files;
      final picked = response.file ??
          (files != null && files.isNotEmpty ? files.last : null);
      final target = _pendingTarget;
      if (picked == null) return false;
      if (!_isValidTarget(target)) {
        throw StateError(
          'A imagem foi recuperada, mas a vista pendente não foi identificada.',
        );
      }

      final stored = await _sessionStore.importFile(
        File(picked.path),
        target!,
      );
      _setTargetFile(target, stored, persist: false);
      _pendingTarget = null;
      await _persistDraft();
      return true;
    } on UnimplementedError {
      _pendingTarget = null;
      return false;
    } catch (error) {
      _pendingTarget = null;
      state = state.copyWith(
        error: 'Falha ao recuperar a imagem selecionada: $error',
      );
      return false;
    } finally {
      _recovering = false;
      state = state.copyWith(selectingImage: false);
    }
  }

  void _setTargetFile(String target, File file, {bool persist = true}) {
    if (target == 'extra') {
      if (!state.canAddExtra) return;
      state = state.copyWith(
        extras: [...state.extras, file],
        clearError: true,
      );
    } else if (target == AppConstants.topView) {
      state = state.copyWith(top: file, clearError: true);
    } else {
      final updated = Map<String, File?>.from(state.cardinals);
      updated[target] = file;
      state = state.copyWith(cardinals: updated, clearError: true);
    }
    _recomputeQuality();
    if (persist) _persistLater();
  }

  bool _isValidTarget(String? target) {
    return target == 'extra' ||
        target == AppConstants.topView ||
        AppConstants.cardinalViews.contains(target);
  }

  String _pickerErrorMessage(ImageSource source, Object error) {
    return source == ImageSource.camera
        ? 'Falha ao acessar a câmera: $error'
        : 'Falha ao selecionar imagem: $error';
  }

  CaptureSessionDraft _currentDraft() {
    return CaptureSessionDraft(
      cardinalPaths: {
        for (final entry in state.cardinals.entries)
          if (entry.value != null) entry.key: entry.value!.path,
      },
      topPath: state.top?.path,
      extraPaths: state.extras.map((file) => file.path).toList(growable: false),
      pendingTarget: _pendingTarget,
      productId: state.productId,
      material: state.material,
    );
  }

  Future<void> _persistDraft() {
    return _sessionStore.save(_currentDraft());
  }

  Future<void> _persistDraftSafely() async {
    try {
      await _persistDraft();
    } catch (error) {
      state = state.copyWith(
        error: 'A foto foi mantida, mas a sessão não pôde ser salva: $error',
      );
    }
  }

  void _persistLater() {
    unawaited(_persistDraftSafely());
  }

  void clear() {
    _pendingTarget = null;
    state = const CaptureState();
    _recomputeQuality();
    unawaited(_clearStoredDraft());
  }

  Future<void> _clearStoredDraft() async {
    try {
      await _sessionStore.clear();
    } catch (error) {
      state =
          state.copyWith(error: 'Falha ao limpar fotos temporárias: $error');
    }
  }

  Future<String?> submit() async {
    await ready;
    if (!state.allCardinalsFilled) {
      state = state.copyWith(
        error:
            'Capture as 4 vistas (frente, esquerda, trás, direita) antes de enviar.',
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
      final result = await _repository.uploadImages(
        upload.files,
        views: upload.views,
        productId: state.productId,
        material: state.material,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: progress);
        },
      );
      await _sessionStore.clear();
      state = const CaptureState();
      _recomputeQuality();
      return result.jobId;
    } catch (error) {
      state = state.copyWith(uploading: false, error: error.toString());
      return null;
    }
  }
}

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final captureSessionStoreProvider = Provider<CaptureSessionStore>((ref) {
  return FileCaptureSessionStore();
});

final captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>((ref) {
  return CaptureController(
    repository: ref.watch(captureRepositoryProvider),
    picker: ref.watch(imagePickerProvider),
    sessionStore: ref.watch(captureSessionStoreProvider),
    enableLostDataRecovery: Platform.isAndroid,
  );
});
