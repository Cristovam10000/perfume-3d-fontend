import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/processing_repository.dart';
import '../../domain/processing_job.dart';

class ProcessingController extends StateNotifier<ProcessingJob> {
  ProcessingController(this._ref) : super(const ProcessingJob());

  final Ref _ref;
  Timer? _timer;

  void start(String jobId) {
    _timer?.cancel();
    state = ProcessingJob(
      jobId: jobId,
      status: ProcessingStatus.uploaded,
      message: 'Imagens enviadas. Aguardando processamento.',
    );
    _schedulePoll();
  }

  void reset() {
    _timer?.cancel();
    state = const ProcessingJob();
  }

  void _schedulePoll() {
    _timer = Timer.periodic(AppConstants.processingPollInterval, (_) => _poll());
    // Dispara imediatamente também.
    _poll();
  }

  Future<void> _poll() async {
    final jobId = state.jobId;
    if (jobId == null) return;
    if (state.isCompleted || state.hasError) {
      _timer?.cancel();
      return;
    }
    try {
      final repo = _ref.read(processingRepositoryProvider);
      final updated = await repo.fetchStatus(jobId);
      state = updated;
      if (updated.isCompleted || updated.hasError) {
        _timer?.cancel();
      }
    } catch (e) {
      state = state.copyWith(
        status: ProcessingStatus.error,
        error: e.toString(),
      );
      _timer?.cancel();
    }
  }

  Future<void> retry() async {
    if (state.jobId == null) return;
    state = state.copyWith(
      status: ProcessingStatus.processing,
      clearError: true,
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
  return ProcessingController(ref);
});
