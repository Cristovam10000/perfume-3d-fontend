import '../constants/app_constants.dart';

enum QualityLevel { ok, warning, blocker }

class QualityMessage {
  final String text;
  final QualityLevel level;
  const QualityMessage(this.text, this.level);
}

/// Heurísticas de orientação durante a captura guiada.
///
/// O fluxo novo é por vista cardeal (4 obrigatórias), topo opcional e até 2
/// extras. As mensagens guiam o usuário até completar as 4 cardeais — não
/// importa a contagem total, mas qual cardeal ainda falta.
class ImageQualityAnalyzer {
  const ImageQualityAnalyzer();

  List<QualityMessage> evaluate({
    required int cardinalCount,
    bool hasTop = false,
    int extrasCount = 0,
  }) {
    final messages = <QualityMessage>[];

    if (cardinalCount == 0) {
      messages.add(const QualityMessage(
        'Comece capturando a vista FRENTE do perfume.',
        QualityLevel.warning,
      ));
    } else if (cardinalCount < AppConstants.requiredImages) {
      final faltam = AppConstants.requiredImages - cardinalCount;
      messages.add(QualityMessage(
        'Faltam $faltam vista(s) cardeal(is) para enviar.',
        QualityLevel.warning,
      ));
    } else if (!hasTop) {
      messages.add(const QualityMessage(
        'Todas as cardeais prontas. Você pode enviar ou adicionar o topo opcional.',
        QualityLevel.ok,
      ));
    } else if (extrasCount < AppConstants.maxExtras) {
      messages.add(const QualityMessage(
        'Cardeais e topo prontos. Você pode enviar ou adicionar até 2 extras.',
        QualityLevel.ok,
      ));
    } else {
      messages.add(const QualityMessage(
        'Captura completa (4 cardeais + topo + 2 extras). Pronto para enviar.',
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
        'Use fundo claro para o algoritmo destacar o frasco.',
      ];
}
