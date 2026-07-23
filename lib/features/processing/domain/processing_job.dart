enum ProcessingStatus {
  idle,
  waiting,
  uploaded,
  processing,
  completed,
  error,
}

extension ProcessingStatusLabel on ProcessingStatus {
  String get label {
    switch (this) {
      case ProcessingStatus.idle:
        return 'Aguardando';
      case ProcessingStatus.waiting:
        return 'Aguardando fila';
      case ProcessingStatus.uploaded:
        return 'Imagens enviadas';
      case ProcessingStatus.processing:
        return 'Processando';
      case ProcessingStatus.completed:
        return 'Concluído';
      case ProcessingStatus.error:
        return 'Erro';
    }
  }
}

class ProcessingJob {
  final String? jobId;
  final ProcessingStatus status;
  final String? message;
  final String? modelUrl;
  final String? error;
  final String? pollingWarning;
  final int? productId;

  const ProcessingJob({
    this.jobId,
    this.status = ProcessingStatus.idle,
    this.message,
    this.modelUrl,
    this.error,
    this.pollingWarning,
    this.productId,
  });

  bool get isCompleted => status == ProcessingStatus.completed;
  bool get hasError => status == ProcessingStatus.error;
  bool get hasPollingWarning => pollingWarning != null;

  ProcessingJob copyWith({
    String? jobId,
    ProcessingStatus? status,
    String? message,
    String? modelUrl,
    String? error,
    String? pollingWarning,
    bool clearError = false,
    bool clearPollingWarning = false,
    int? productId,
  }) {
    return ProcessingJob(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      message: message ?? this.message,
      modelUrl: modelUrl ?? this.modelUrl,
      error: clearError ? null : (error ?? this.error),
      pollingWarning:
          clearPollingWarning ? null : (pollingWarning ?? this.pollingWarning),
      productId: productId ?? this.productId,
    );
  }

  static ProcessingStatus parseStatus(String? raw) {
    switch (raw) {
      case 'waiting':
        return ProcessingStatus.waiting;
      case 'uploaded':
        return ProcessingStatus.uploaded;
      case 'processing':
        return ProcessingStatus.processing;
      case 'completed':
        return ProcessingStatus.completed;
      case 'error':
        return ProcessingStatus.error;
      default:
        return ProcessingStatus.idle;
    }
  }
}
