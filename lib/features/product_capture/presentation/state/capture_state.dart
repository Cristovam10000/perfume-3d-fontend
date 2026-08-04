import 'dart:io';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/image_quality_analyzer.dart';

/// Estado da captura guiada por vista cardeal.
///
/// Substitui a abordagem antiga (`List<File>` sem rótulo) por um mapa
/// vista→arquivo para as 4 cardeais, um campo próprio para o topo opcional e
/// uma lista para extras. Isso casa com o contrato `views` paralelo a
/// `images` no POST /captures.
class CaptureState {
  /// Mapa vista cardeal -> arquivo capturado. Chaves possíveis:
  /// `front`, `left`, `back`, `right`. Valor null = ainda não capturado.
  final Map<String, File?> cardinals;

  /// Foto opcional da tampa. Fica fora de [cardinals] para não participar do
  /// critério das 4 vistas obrigatórias.
  final File? top;

  /// Fotos extras sem rótulo cardeal (até `AppConstants.maxExtras`).
  /// Não obrigatórias; o CLIPViewRouter no backend pode aproveitar.
  final List<File> extras;

  final List<QualityMessage> qualityMessages;
  final bool uploading;

  /// Impede duas câmeras/galerias de serem abertas ao mesmo tempo.
  final bool selectingImage;
  final double uploadProgress;
  final String? error;
  final int? productId;

  /// Material do frasco escolhido pelo usuário: `glass`, `opaque` ou null.
  ///
  /// Null significa "não informado" — o backend cai no classificador CLIP.
  /// A pergunta existe porque esse classificador não separa as duas classes de
  /// forma confiável: medido em 6 frascos reais, um de vidro pontuou abaixo de
  /// um opaco, então nenhum limiar acerta os dois. Um toque acerta sempre.
  final String? material;

  const CaptureState({
    this.cardinals = const {
      'front': null,
      'left': null,
      'back': null,
      'right': null,
    },
    this.top,
    this.extras = const [],
    this.qualityMessages = const [],
    this.uploading = false,
    this.selectingImage = false,
    this.uploadProgress = 0,
    this.error,
    this.productId,
    this.material,
  });

  CaptureState copyWith({
    Map<String, File?>? cardinals,
    File? top,
    bool clearTop = false,
    List<File>? extras,
    List<QualityMessage>? qualityMessages,
    bool? uploading,
    bool? selectingImage,
    double? uploadProgress,
    String? error,
    bool clearError = false,
    int? productId,
    bool clearProductId = false,
    String? material,
    bool clearMaterial = false,
  }) {
    return CaptureState(
      cardinals: cardinals ?? this.cardinals,
      top: clearTop ? null : (top ?? this.top),
      extras: extras ?? this.extras,
      qualityMessages: qualityMessages ?? this.qualityMessages,
      uploading: uploading ?? this.uploading,
      selectingImage: selectingImage ?? this.selectingImage,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
      productId: clearProductId ? null : (productId ?? this.productId),
      material: clearMaterial ? null : (material ?? this.material),
    );
  }

  /// Quantidade de cardeais já capturadas (0..4).
  int get cardinalCount => cardinals.values.where((f) => f != null).length;

  /// Total de imagens (cardeais + topo opcional + extras).
  int get totalCount => cardinalCount + (top == null ? 0 : 1) + extras.length;

  /// True quando todas as 4 cardeais estão preenchidas.
  bool get allCardinalsFilled =>
      AppConstants.cardinalViews.every((v) => cardinals[v] != null);

  /// Pronto para enviar = todas as cardeais preenchidas.
  bool get canSubmit => allCardinalsFilled && !uploading && !selectingImage;

  /// True se ainda cabem extras.
  bool get canAddExtra => extras.length < AppConstants.maxExtras;

  /// Lista plana de arquivos + views paralela, na ordem cardinais + topo +
  /// extras.
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
    if (top != null) {
      files.add(top!);
      views.add(AppConstants.topView);
    }
    for (final f in extras) {
      files.add(f);
      views.add('extra');
    }
    return (files: files, views: views);
  }
}
