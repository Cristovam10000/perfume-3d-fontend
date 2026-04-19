import 'dart:math' as math;

/// Rastreia a inclinação vertical do aparelho (pitch) a partir do
/// acelerômetro. Útil para orientar o usuário a manter o celular na altura
/// do perfume em vez de apontar para cima ou para baixo.
///
/// Convenção assumida (Android, sensors_plus, aparelho em retrato):
///  - eixo X = lateral
///  - eixo Y = ao longo do corpo do celular (para cima)
///  - eixo Z = saindo da tela
/// Com o celular vertical apontando para frente (câmera traseira na horizontal)
/// esperamos z ≈ 0 e y ≈ g. Se a câmera aponta para baixo, z fica positivo;
/// se aponta para cima, z fica negativo.
class TiltTracker {
  double _pitchDegrees = 0;
  bool _hasSample = false;

  /// Consome um evento do acelerômetro e atualiza o pitch suavizado.
  void onAccel({required double x, required double y, required double z}) {
    final p = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
    if (!_hasSample) {
      _pitchDegrees = p;
      _hasSample = true;
    } else {
      _pitchDegrees = _pitchDegrees * 0.85 + p * 0.15;
    }
  }

  /// Pitch atual em graus. 0 ≈ câmera na horizontal.
  double get pitchDegrees => _pitchDegrees;

  /// True enquanto a câmera estiver aproximadamente na horizontal.
  bool isLevel({double tolerance = 20}) => _pitchDegrees.abs() <= tolerance;

  /// Mensagem de correção se fora da tolerância; null caso contrário.
  String? correction({double tolerance = 20}) {
    if (!_hasSample) return null;
    if (_pitchDegrees > tolerance) {
      return 'Você está apontando para baixo. Endireite o celular.';
    }
    if (_pitchDegrees < -tolerance) {
      return 'Você está apontando para cima. Endireite o celular.';
    }
    return null;
  }
}
