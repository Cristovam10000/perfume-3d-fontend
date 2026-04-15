class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, [this.cause]);

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

class UploadException extends AppException {
  const UploadException(super.message, [super.cause]);
}

class ProcessingException extends AppException {
  const ProcessingException(super.message, [super.cause]);
}
