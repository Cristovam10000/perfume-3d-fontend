import '../constants/app_constants.dart';

enum QualityLevel { ok, warning, blocker }

class QualityMessage {
  final String text;
  final QualityLevel level;
  const QualityMessage(this.text, this.level);
}

/// Heurísticas simples para orientação ao usuário durante a captura.
/// Este MVP não analisa pixels — apenas responde à contagem e ao contexto.
/// A feature pode evoluir para inspeção real (luminância, nitidez) sem
/// mudar a API pública.
class ImageQualityAnalyzer {
  const ImageQualityAnalyzer();

  List<QualityMessage> evaluate({required int imageCount}) {
    final messages = <QualityMessage>[];

    if (imageCount == 0) {
      messages.add(const QualityMessage(
        'Capture a primeira imagem do perfume centralizado no enquadramento.',
        QualityLevel.warning,
      ));
    } else if (imageCount < AppConstants.minImages) {
      final faltam = AppConstants.minImages - imageCount;
      messages.add(QualityMessage(
        'Faltam mais imagens. Capture ao menos $faltam ângulos adicionais.',
        QualityLevel.warning,
      ));
      messages.add(const QualityMessage(
        'Gire o perfume em passos pequenos para cobrir todos os ângulos.',
        QualityLevel.ok,
      ));
    } else if (imageCount < AppConstants.recommendedImages) {
      messages.add(const QualityMessage(
        'Boa cobertura. Capture mais ângulos para melhorar a reconstrução.',
        QualityLevel.ok,
      ));
    } else {
      messages.add(const QualityMessage(
        'Cobertura excelente. Você pode seguir para a revisão.',
        QualityLevel.ok,
      ));
    }

    return messages;
  }

  /// Dicas sempre visíveis como guia geral durante a captura.
  List<String> generalHints() => const [
        'Mantenha boa iluminação e evite sombras fortes.',
        'Centralize o perfume no guia de enquadramento.',
        'Evite reflexos e fundo poluído.',
        'Aproxime ou afaste até preencher bem o quadro.',
      ];
}
