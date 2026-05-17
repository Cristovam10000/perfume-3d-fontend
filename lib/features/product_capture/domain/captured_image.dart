import 'dart:io';

/// Foto capturada com seu rótulo de vista cardeal.
///
/// O Hunyuan3D-2mv espera vistas nomeadas (`front`, `left`, `back`, `right`).
/// O app envia o `view` no campo `views` do POST /captures; o backend usa
/// esse rótulo para reordenar antes de chamar o servidor de inferência.
class CapturedImage {
  final File file;
  final DateTime capturedAt;

  /// Rótulo de vista: `front`, `left`, `back`, `right` ou `extra`.
  /// `null` só faz sentido para clientes legados; o app guiado sempre preenche.
  final String? view;

  const CapturedImage({
    required this.file,
    required this.capturedAt,
    this.view,
  });

  factory CapturedImage.now(File file, {String? view}) =>
      CapturedImage(file: file, capturedAt: DateTime.now(), view: view);

  CapturedImage copyWith({File? file, String? view}) => CapturedImage(
        file: file ?? this.file,
        capturedAt: capturedAt,
        view: view ?? this.view,
      );
}
