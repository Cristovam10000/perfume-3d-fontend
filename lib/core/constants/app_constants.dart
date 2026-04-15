class AppConstants {
  AppConstants._();

  static const String appName = 'Perfume 3D';

  // Base URL do backend local. Ajustar conforme ambiente.
  // Em emulador Android use 10.0.2.2; em dispositivo físico, o IP da máquina.
  static const String backendBaseUrl = 'http://10.0.2.2:8000';

  // Regras de captura
  static const int minImages = 12;
  static const int recommendedImages = 24;
  static const int maxImages = 60;

  // Polling de processamento
  static const Duration processingPollInterval = Duration(seconds: 3);
}
