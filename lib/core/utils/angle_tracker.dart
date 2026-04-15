import 'dart:math' as math;

/// Rastreia cobertura angular em torno do objeto a partir da rotação
/// acumulada do giroscópio (eixo vertical do aparelho).
///
/// Divide o círculo em [bins] fatias iguais. Quando o usuário captura
/// uma imagem, marca a fatia correspondente à orientação atual como coberta.
class AngleTracker {
  final int bins;
  final List<bool> _covered;
  double _yawRadians = 0;
  DateTime? _lastEventAt;

  AngleTracker({this.bins = 12}) : _covered = List.filled(12, false);

  /// Fatia atual (0..bins-1) com base no ângulo acumulado.
  int get currentBin {
    final normalized = _normalize(_yawRadians);
    final idx = (normalized / (2 * math.pi) * bins).floor();
    return idx.clamp(0, bins - 1);
  }

  /// Snapshot dos bins cobertos.
  List<bool> get coverage => List.unmodifiable(_covered);

  int get coveredCount => _covered.where((b) => b).length;
  double get coverageRatio => coveredCount / bins;

  /// Ângulo acumulado em graus (0..360).
  double get currentAngleDegrees => _normalize(_yawRadians) * 180 / math.pi;

  /// Consome um evento de giroscópio. [yawRate] em rad/s no eixo que representa
  /// o movimento de "giro em torno do objeto" (no aparelho em retrato, é o
  /// eixo Y: o usuário anda ao redor do perfume mantendo o celular apontado).
  void onGyro({required double yawRate}) {
    final now = DateTime.now();
    final last = _lastEventAt;
    _lastEventAt = now;
    if (last == null) return;
    final dt = now.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return; // descarta saltos
    _yawRadians += yawRate * dt;
  }

  /// Marca a fatia atual como capturada.
  void markCurrent() {
    _covered[currentBin] = true;
  }

  void reset() {
    _yawRadians = 0;
    _lastEventAt = null;
    for (int i = 0; i < _covered.length; i++) {
      _covered[i] = false;
    }
  }

  /// Sugere direção para o próximo ângulo ainda não coberto mais próximo.
  /// Retorna null se todos estiverem cobertos.
  String? nextSuggestion() {
    if (_covered.every((b) => b)) return null;
    final current = currentBin;
    for (int offset = 1; offset <= bins; offset++) {
      final right = (current + offset) % bins;
      final left = (current - offset + bins) % bins;
      if (!_covered[right]) {
        return 'Gire ~${(offset * 360 / bins).round()}° para a direita.';
      }
      if (!_covered[left]) {
        return 'Gire ~${(offset * 360 / bins).round()}° para a esquerda.';
      }
    }
    return null;
  }

  double _normalize(double rad) {
    const two = 2 * math.pi;
    var r = rad % two;
    if (r < 0) r += two;
    return r;
  }
}
