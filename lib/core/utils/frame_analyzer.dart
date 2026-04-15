import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Resultado da análise de um frame da pré-visualização.
class FrameQuality {
  /// Brilho médio do plano Y (0..255).
  final double brightness;

  /// Estimativa de nitidez (variância do Laplaciano amostrado). Valores
  /// mais altos indicam imagem mais nítida. Muito baixo ≈ desfoque/tremido.
  final double sharpness;

  /// % de pixels saturados (muito claros) — indica reflexo/superexposição.
  final double saturatedRatio;

  const FrameQuality({
    required this.brightness,
    required this.sharpness,
    required this.saturatedRatio,
  });
}

/// Analisa frames da câmera para produzir feedback de qualidade em tempo real.
///
/// Trabalha apenas sobre o plano Y (luminância) do formato YUV420 do Android,
/// que é a forma nativa entregue pelo plugin `camera` no Android. Em iOS
/// o formato é BGRA — o analisador degrada graciosamente ignorando a métrica
/// de nitidez nesse caso.
class FrameAnalyzer {
  /// Subamostragem: para performance, olhamos 1 pixel a cada [_step].
  static const int _step = 8;
  static const int _saturationThreshold = 245;

  FrameQuality analyze(CameraImage image) {
    if (image.planes.isEmpty) {
      return const FrameQuality(
        brightness: 0,
        sharpness: 0,
        saturatedRatio: 0,
      );
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final rowStride = plane.bytesPerRow;

    // 1) Brilho médio e saturação
    int sum = 0;
    int saturated = 0;
    int count = 0;

    for (int y = 0; y < height; y += _step) {
      final rowStart = y * rowStride;
      for (int x = 0; x < width; x += _step) {
        final idx = rowStart + x;
        if (idx >= bytes.length) break;
        final v = bytes[idx];
        sum += v;
        if (v >= _saturationThreshold) saturated++;
        count++;
      }
    }
    if (count == 0) {
      return const FrameQuality(
        brightness: 0,
        sharpness: 0,
        saturatedRatio: 0,
      );
    }
    final brightness = sum / count;
    final saturatedRatio = saturated / count;

    // 2) Nitidez via variância de um Laplaciano 3x3 amostrado.
    final sharpness = _laplacianVariance(bytes, width, height, rowStride);

    return FrameQuality(
      brightness: brightness,
      sharpness: sharpness,
      saturatedRatio: saturatedRatio,
    );
  }

  double _laplacianVariance(
    Uint8List bytes,
    int width,
    int height,
    int rowStride,
  ) {
    // Kernel: [0,1,0; 1,-4,1; 0,1,0]
    double mean = 0;
    double m2 = 0;
    int n = 0;

    for (int y = _step; y < height - _step; y += _step) {
      final rowPrev = (y - 1) * rowStride;
      final row = y * rowStride;
      final rowNext = (y + 1) * rowStride;
      for (int x = _step; x < width - _step; x += _step) {
        final iPrev = rowPrev + x;
        final i = row + x;
        final iNext = rowNext + x;
        if (iNext >= bytes.length || i + 1 >= bytes.length) break;
        final lap = bytes[i - 1] +
            bytes[i + 1] +
            bytes[iPrev] +
            bytes[iNext] -
            4 * bytes[i];
        n++;
        final delta = lap - mean;
        mean += delta / n;
        final delta2 = lap - mean;
        m2 += delta * delta2;
      }
    }
    if (n < 2) return 0;
    return m2 / (n - 1);
  }
}
