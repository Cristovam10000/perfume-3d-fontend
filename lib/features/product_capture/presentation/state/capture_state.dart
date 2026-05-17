import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_quality_analyzer.dart';

/// Estado da captura guiada por vista cardeal.
///
/// Substitui a abordagem antiga (`List<File>` sem rótulo) por um mapa
/// vista→arquivo para as 4 cardeais + lista para extras. Isso casa com o
/// contrato `views` paralelo a `images` no POST /captures.
class CaptureState {
  /// Mapa vista cardeal -> arquivo capturado. Chaves possíveis:
  /// `front`, `left`, `back`, `right`. Valor null = ainda não capturado.
  final Map<String, File?> cardinals;

  /// Fotos extras sem rótulo cardeal (até `AppConstants.maxExtras`).
  /// Não obrigatórias; o CLIPViewRouter no backend pode aproveitar.
  final List<File> extras;

  final List<QualityMessage> qualityMessages;
  final bool uploading;
  final bool selectingFromGallery;
  final double uploadProgress;
  final String? error;

  const CaptureState({
    this.cardinals = const {
      'front': null,
      'left': null,
      'back': null,
      'right': null,
    },
    this.extras = const [],
    this.qualityMessages = const [],
    this.uploading = false,
    this.selectingFromGallery = false,
    this.uploadProgress = 0,
    this.error,
  });

  CaptureState copyWith({
    Map<String, File?>? cardinals,
    List<File>? extras,
    List<QualityMessage>? qualityMessages,
    bool? uploading,
    bool? selectingFromGallery,
    double? uploadProgress,
    String? error,
    bool clearError = false,
  }) {
    return CaptureState(
      cardinals: cardinals ?? this.cardinals,
      extras: extras ?? this.extras,
      qualityMessages: qualityMessages ?? this.qualityMessages,
      uploading: uploading ?? this.uploading,
      selectingFromGallery: selectingFromGallery ?? this.selectingFromGallery,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Quantidade de cardeais já capturadas (0..4).
  int get cardinalCount => cardinals.values.where((f) => f != null).length;

  /// Total de imagens (cardeais + extras).
  int get totalCount => cardinalCount + extras.length;

  /// True quando todas as 4 cardeais estão preenchidas.
  bool get allCardinalsFilled =>
      AppConstants.cardinalViews.every((v) => cardinals[v] != null);

  /// Pronto para enviar = todas as cardeais preenchidas.
  bool get canSubmit => allCardinalsFilled && !uploading;

  /// True se ainda cabem extras.
  bool get canAddExtra => extras.length < AppConstants.maxExtras;

  /// Lista plana de arquivos + views paralela, na ordem cardinal + extras.
  /// Usada pelo `CaptureRepository.uploadImages`.
  ({List<File> files, List<String> views}) flattenForUpload() {
    final files = <File>[];
    final views = <String>[];
    for (final v in AppConstants.cardinalViews) {
      final f = cardinals[v];
      if (f == null) continue;
      files.add(f);
      views.add(v);
    }
    for (final f in extras) {
      files.add(f);
      views.add('extra');
    }
    return (files: files, views: views);
  }
}
