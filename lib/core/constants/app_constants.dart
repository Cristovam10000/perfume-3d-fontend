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
  // O modelo Hunyuan3D-2mv foi treinado com 4 vistas cardeais (front, left,
  // back, right) e aceita até 6 imagens no total (server.py:_MAX_IMAGENS=6).
  // O app guia o usuário a capturar cada vista explicitamente e envia o
  // rótulo no campo `views` do POST /captures.
  static const List<String> cardinalViews = ['front', 'left', 'back', 'right'];
  static const int requiredImages = 4; // 4 cardeais obrigatórias
  static const int maxExtras = 2; // até 2 fotos extras opcionais
  static const int maxImages = 6; // requiredImages + maxExtras

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
    'extra': 'Extra',
  };

  // Polling de processamento
  static const Duration processingPollInterval = Duration(seconds: 3);
}
