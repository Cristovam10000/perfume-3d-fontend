import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/core/errors/app_exception.dart';
import 'package:perfume_3d_mvp/features/processing/data/processing_repository.dart';
import 'package:perfume_3d_mvp/features/processing/domain/processing_job.dart';
import 'package:perfume_3d_mvp/features/processing/presentation/state/processing_controller.dart';

void main() {
  test('falha transitória mantém o job ativo e o polling recupera', () async {
    final repository = _QueueProcessingRepository([
      const ProcessingException('Rede local indisponível.'),
      const ProcessingJob(
        jobId: 'job-1',
        status: ProcessingStatus.processing,
        message: 'Reconstruindo modelo 3D',
      ),
    ]);
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.start('job-1');
    await _nextEventLoop();

    expect(controller.state.hasError, isFalse);
    expect(controller.state.status, ProcessingStatus.uploaded);
    expect(controller.state.pollingWarning, contains('Rede local'));
    expect(
      controller.state.pollingWarning,
      contains('pode continuar normalmente'),
    );

    await controller.pollNow();

    expect(controller.state.status, ProcessingStatus.processing);
    expect(controller.state.message, 'Reconstruindo modelo 3D');
    expect(controller.state.pollingWarning, isNull);
  });

  test('não inicia consultas concorrentes', () async {
    final pending = Completer<ProcessingJob>();
    final repository = _PendingProcessingRepository(pending);
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.start('job-2');
    await _nextEventLoop();
    await controller.pollNow();

    expect(repository.calls, 1);

    pending.complete(
      const ProcessingJob(
        jobId: 'job-2',
        status: ProcessingStatus.processing,
      ),
    );
    await _nextEventLoop();
    expect(controller.state.status, ProcessingStatus.processing);
  });

  test('erro informado pelo backend continua sendo terminal', () async {
    final repository = _QueueProcessingRepository([
      const ProcessingJob(
        jobId: 'job-3',
        status: ProcessingStatus.error,
        error: 'Falha na reconstrução.',
      ),
    ]);
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.start('job-3');
    await _nextEventLoop();

    expect(controller.state.hasError, isTrue);
    expect(controller.state.error, 'Falha na reconstrução.');
    expect(controller.state.pollingWarning, isNull);
  });

  test('resposta atrasada de job anterior não sobrescreve o job atual',
      () async {
    final firstResponse = Completer<ProcessingJob>();
    final repository = _SwitchingProcessingRepository(firstResponse);
    final controller = _controller(repository);
    addTearDown(controller.dispose);

    controller.start('job-antigo');
    await _nextEventLoop();
    controller.start('job-novo');

    firstResponse.complete(
      const ProcessingJob(
        jobId: 'job-antigo',
        status: ProcessingStatus.completed,
      ),
    );
    await _nextEventLoop();

    expect(controller.state.jobId, 'job-novo');
    expect(controller.state.status, ProcessingStatus.uploaded);

    await controller.pollNow();
    expect(controller.state.jobId, 'job-novo');
    expect(controller.state.status, ProcessingStatus.processing);
  });
}

ProcessingController _controller(ProcessingRepository repository) {
  return ProcessingController(
    repository,
    pollInterval: const Duration(days: 1),
  );
}

Future<void> _nextEventLoop() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _QueueProcessingRepository implements ProcessingRepository {
  _QueueProcessingRepository(this.responses);

  final List<Object> responses;

  @override
  Future<ProcessingJob> fetchStatus(String jobId) async {
    final response = responses.removeAt(0);
    if (response is Exception) throw response;
    return response as ProcessingJob;
  }
}

class _PendingProcessingRepository implements ProcessingRepository {
  _PendingProcessingRepository(this.pending);

  final Completer<ProcessingJob> pending;
  int calls = 0;

  @override
  Future<ProcessingJob> fetchStatus(String jobId) {
    calls++;
    return pending.future;
  }
}

class _SwitchingProcessingRepository implements ProcessingRepository {
  _SwitchingProcessingRepository(this.firstResponse);

  final Completer<ProcessingJob> firstResponse;
  int calls = 0;

  @override
  Future<ProcessingJob> fetchStatus(String jobId) {
    calls++;
    if (calls == 1) return firstResponse.future;
    return Future.value(
      ProcessingJob(
        jobId: jobId,
        status: ProcessingStatus.processing,
      ),
    );
  }
}
