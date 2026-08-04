class AppConstants {
  AppConstants._();

  static const String appName = 'Perfume 3D';

  // Base URL do backend local.
  // Para celular/emulador, rode com:
  // --dart-define=BACKEND_BASE_URL=http://IP_DA_MAQUINA:8000
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static String resolveBackendUrl(String value) {
    final base = Uri.parse(
        backendBaseUrl.endsWith('/') ? backendBaseUrl : '$backendBaseUrl/');
    final parsed = Uri.parse(value);
    if (!parsed.hasScheme) return base.resolveUri(parsed).toString();
    if ((parsed.host == 'localhost' || parsed.host == '127.0.0.1') &&
        base.host.isNotEmpty) {
      return parsed
          .replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          )
          .toString();
    }
    return parsed.toString();
  }

  // ---- Captura guiada (Hunyuan3D-2mv) ----
  // O modelo Hunyuan3D-2mv recebe as 4 vistas cardeais (front, left, back,
  // right). A vista `top` é opcional e não vai para o Hunyuan: o backend a
  // usa depois para projetar a textura da tampa no GLB. O app envia cada
  // rótulo no campo `views` do POST /captures.
  static const List<String> cardinalViews = ['front', 'left', 'back', 'right'];
  static const String topView = 'top';
  static const int requiredImages = 4; // 4 cardeais obrigatórias
  static const int maxExtras = 2; // até 2 fotos extras opcionais
  static const int maxImages = 7; // cardeais + topo opcional + extras

  // ---- Material do frasco ----
  // Enviado no campo `material` do POST /captures e usado pelo backend para
  // decidir entre aplicar vidro PBR ou preservar a textura pintada pela IA.
  // A pergunta existe porque o classificador CLIP do backend não separa as
  // duas classes: medido em 6 frascos reais, um de vidro pontuou abaixo de um
  // opaco, então nenhum limiar acerta os dois. Não enviar o campo mantém o
  // comportamento antigo (o backend classifica sozinho).
  static const String materialGlass = 'glass';
  static const String materialOpaque = 'opaque';
  static const Map<String, String> materialLabels = {
    materialGlass: 'Vidro transparente',
    materialOpaque: 'Opaco',
  };

  // Os JPEGs originais continuam disponíveis para upload. Estes limites
  // controlam apenas a resolução decodificada dos previews na interface.
  static const int cardinalPreviewCacheWidth = 768;
  static const int extraPreviewCacheWidth = 240;

  // Rótulos em pt-BR para exibição na UI.
  static const Map<String, String> viewLabels = {
    'front': 'Frente',
    'left': 'Esquerda',
    'back': 'Trás',
    'right': 'Direita',
    'top': 'Topo',
    'extra': 'Extra',
  };

  // Polling de processamento
  static const Duration processingPollInterval = Duration(seconds: 3);
}
