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

  // Regras de captura
  static const int minImages = 12;
  static const int recommendedImages = 24;
  static const int maxImages = 60;

  // Polling de processamento
  static const Duration processingPollInterval = Duration(seconds: 3);
}
