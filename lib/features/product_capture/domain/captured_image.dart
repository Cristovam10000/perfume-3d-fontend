import 'dart:io';

/// Foto capturada com seu rótulo de vista.
///
/// O Hunyuan3D-2mv espera as vistas `front`, `left`, `back` e `right`. O app
/// também pode enviar `top`, usado pelo pós-processamento da tampa, e `extra`.
/// O backend usa esses rótulos para rotear cada imagem corretamente.
class CapturedImage {
  final File file;
  final DateTime capturedAt;

  /// Rótulo: `front`, `left`, `back`, `right`, `top` ou `extra`.
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
