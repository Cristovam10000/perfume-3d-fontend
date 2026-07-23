import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/processing_repository.dart';
import '../../domain/processing_job.dart';

class ProcessingController extends StateNotifier<ProcessingJob> {
  ProcessingController(
    this._repository, {
    Duration pollInterval = AppConstants.processingPollInterval,
  })  : _pollInterval = pollInterval,
        super(const ProcessingJob());

  final ProcessingRepository _repository;
  final Duration _pollInterval;
  Timer? _timer;
  bool _pollInProgress = false;
  int _generation = 0;

  void start(String jobId, {int? productId}) {
    _timer?.cancel();
    _generation++;
    state = ProcessingJob(
      jobId: jobId,
      status: ProcessingStatus.uploaded,
      message: 'Imagens enviadas. Aguardando processamento.',
      productId: productId,
    );
    _schedulePoll();
  }

  void reset() {
    _timer?.cancel();
    _generation++;
    state = const ProcessingJob();
  }

  void _schedulePoll() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    // Dispara imediatamente também.
    _poll();
  }

  Future<void> _poll() async {
    if (_pollInProgress) return;
    final jobId = state.jobId;
    if (jobId == null) return;
    if (state.isCompleted || state.hasError) {
      _timer?.cancel();
      return;
    }

    final generation = _generation;
    _pollInProgress = true;
    try {
      final updated = await _repository.fetchStatus(jobId);
      if (generation != _generation || state.jobId != jobId) return;
      state = updated;
      if (updated.isCompleted || updated.hasError) {
        _timer?.cancel();
      }
    } catch (e) {
      if (generation != _generation || state.jobId != jobId) return;
      final detail = e is AppException
          ? e.message
          : 'Não foi possível atualizar o andamento agora.';
      state = state.copyWith(
        pollingWarning:
            '$detail O processamento no servidor pode continuar normalmente. '
            'Uma nova consulta será feita automaticamente.',
      );
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> pollNow() => _poll();

  Future<void> retry() async {
    if (state.jobId == null) return;
    state = state.copyWith(
      status: ProcessingStatus.processing,
      clearError: true,
      clearPollingWarning: true,
    );
    _schedulePoll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final processingControllerProvider =
    StateNotifierProvider<ProcessingController, ProcessingJob>((ref) {
  return ProcessingController(ref.watch(processingRepositoryProvider));
});
