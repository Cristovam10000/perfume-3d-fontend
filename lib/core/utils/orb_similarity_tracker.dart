import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Veredito do comparador de similaridade para o frame atual.
enum AngleVerdict {
  /// Ainda não há nenhuma captura de referência.
  noReference,

  /// Poucas features em comum com qualquer captura anterior — ângulo novo.
  newAngle,

  /// Há sobreposição parcial com alguma captura — usuário perto de um ângulo
  /// já coberto.
  partialOverlap,

  /// Muitas features coincidem com uma captura anterior — mesmo ângulo.
  duplicate,
}

class SimilarityResult {
  final AngleVerdict verdict;
  final int bestMatches;
  final int capturesCount;

  const SimilarityResult({
    required this.verdict,
    required this.bestMatches,
    required this.capturesCount,
  });
}

/// Usa ORB + BFMatcher (Hamming) para decidir se o frame atual mostra um
/// ângulo distinto das capturas já realizadas.
///
/// A abordagem:
///  1. Para cada captura, guardamos um [cv.Mat] de descritores (32 bytes por
///     feature, ~500 features).
///  2. Para o frame ao vivo (Y plane do YUV420), extraímos descritores e
///     aplicamos knnMatch (k=2) + Lowe's ratio test contra cada captura.
///  3. Tomamos o **maior** número de matches bons como score e classificamos
///     por limiares.
class OrbSimilarityTracker {
  final int nFeatures;
  final int duplicateThreshold;
  final int partialThreshold;
  final int targetWidth;
  final double ratioThreshold;

  late final cv.ORB _orb;
  late final cv.BFMatcher _matcher;
  final List<cv.Mat> _captureDescriptors = [];
  bool _disposed = false;

  OrbSimilarityTracker({
    this.nFeatures = 500,
    this.duplicateThreshold = 90,
    this.partialThreshold = 40,
    this.targetWidth = 480,
    this.ratioThreshold = 0.75,
  }) {
    _orb = cv.ORB.create(nFeatures: nFeatures);
    _matcher = cv.BFMatcher.create(type: cv.NORM_HAMMING);
  }

  int get capturesCount => _captureDescriptors.length;

  /// Registra descritores de uma foto já capturada (JPEG no disco).
  void registerCaptureFromFile(String path) {
    final gray = cv.imread(path, flags: cv.IMREAD_GRAYSCALE);
    try {
      if (gray.isEmpty) return;
      final desc = _computeDescriptors(gray);
      if (desc != null) _captureDescriptors.add(desc);
    } finally {
      gray.dispose();
    }
  }

  /// Classifica o frame atual da câmera (YUV420) contra as capturas existentes.
  SimilarityResult classifyFrame(CameraImage frame) {
    if (_captureDescriptors.isEmpty) {
      return const SimilarityResult(
        verdict: AngleVerdict.noReference,
        bestMatches: 0,
        capturesCount: 0,
      );
    }
    final gray = _matFromYuv(frame);
    cv.Mat? desc;
    try {
      desc = _computeDescriptors(gray);
    } finally {
      gray.dispose();
    }
    if (desc == null) {
      return SimilarityResult(
        verdict: AngleVerdict.newAngle,
        bestMatches: 0,
        capturesCount: _captureDescriptors.length,
      );
    }
    int best = 0;
    try {
      for (final ref in _captureDescriptors) {
        if (ref.rows < 2 || desc.rows < 2) continue;
        final matches = _matcher.knnMatch(desc, ref, 2);
        try {
          int good = 0;
          for (final pair in matches) {
            if (pair.length < 2) continue;
            final m0 = pair[0];
            final m1 = pair[1];
            if (m0.distance < ratioThreshold * m1.distance) good++;
          }
          if (good > best) best = good;
        } finally {
          matches.dispose();
        }
      }
    } finally {
      desc.dispose();
    }
    final AngleVerdict v;
    if (best >= duplicateThreshold) {
      v = AngleVerdict.duplicate;
    } else if (best >= partialThreshold) {
      v = AngleVerdict.partialOverlap;
    } else {
      v = AngleVerdict.newAngle;
    }
    return SimilarityResult(
      verdict: v,
      bestMatches: best,
      capturesCount: _captureDescriptors.length,
    );
  }

  /// Converte o plano Y do frame YUV420 em Mat grayscale, removendo padding
  /// de stride caso exista.
  cv.Mat _matFromYuv(CameraImage frame) {
    final plane = frame.planes.first;
    final width = frame.width;
    final height = frame.height;
    final stride = plane.bytesPerRow;
    Uint8List bytes = plane.bytes;
    if (stride != width) {
      final tight = Uint8List(width * height);
      for (int y = 0; y < height; y++) {
        final src = y * stride;
        tight.setRange(y * width, (y + 1) * width, bytes, src);
      }
      bytes = tight;
    }
    return cv.Mat.fromList(height, width, cv.MatType.CV_8UC1, bytes);
  }

  /// Faz downscale para [targetWidth] e extrai descritores ORB.
  cv.Mat? _computeDescriptors(cv.Mat gray) {
    cv.Mat working = gray;
    bool ownsWorking = false;
    if (gray.cols > targetWidth) {
      final scale = targetWidth / gray.cols;
      final newH = (gray.rows * scale).round();
      working = cv.resize(gray, (targetWidth, newH));
      ownsWorking = true;
    }
    final mask = cv.Mat.empty();
    final result = _orb.detectAndCompute(working, mask);
    result.$1.dispose(); // VecKeyPoint — não precisamos
    final desc = result.$2;
    mask.dispose();
    if (ownsWorking) working.dispose();
    if (desc.isEmpty || desc.rows == 0) {
      desc.dispose();
      return null;
    }
    return desc;
  }

  void reset() {
    for (final d in _captureDescriptors) {
      d.dispose();
    }
    _captureDescriptors.clear();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    reset();
    _orb.dispose();
    _matcher.dispose();
  }
}
