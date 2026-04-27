import 'package:camera/camera.dart';

enum AngleVerdict {
  noReference,
  newAngle,
  partialOverlap,
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

class OrbSimilarityTracker {
  int _capturesCount = 0;

  int get capturesCount => _capturesCount;

  void registerCaptureFromFile(String path) {
    _capturesCount++;
  }

  SimilarityResult classifyFrame(CameraImage frame) {
    return SimilarityResult(
      verdict: _capturesCount == 0
          ? AngleVerdict.noReference
          : AngleVerdict.newAngle,
      bestMatches: 0,
      capturesCount: _capturesCount,
    );
  }

  void reset() {
    _capturesCount = 0;
  }

  void dispose() {}
}
