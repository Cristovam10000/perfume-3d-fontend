# 10 — Feature `processing`

A feature `processing` lida com o **tempo de espera** entre o upload das fotos e a entrega do modelo 3D. O backend não responde síncronamente ao upload — ele retorna um `jobId` imediatamente e processa em background. O app precisa acompanhar esse progresso.

## Estrutura

```
lib/features/processing/
├── domain/
│   └── processing_job.dart
├── data/
│   └── processing_repository.dart
└── presentation/
    ├── state/
    │   └── processing_controller.dart
    └── pages/
        └── processing_status_page.dart
```

## Camada `domain/`

### `processing_job.dart`

[lib/features/processing/domain/processing_job.dart](../lib/features/processing/domain/processing_job.dart) define o enum e a classe imutável que representam o estado do job:

```dart
enum ProcessingStatus {
  queued,      // na fila
  processing,  // rodando
  uploading,   // modelo sendo preparado
  completed,   // pronto
  failed,      // erro
  cancelled,   // cancelado pelo usuário (futuro)
}

class ProcessingJob {
  final String jobId;
  final ProcessingStatus status;
  final double? progress;  // 0..1, pode vir nulo
  final String? message;   // texto curto vindo do backend
  final String? modelUrl;  // URL do .glb quando completed
  final String? errorCode; // código de erro quando failed

  const ProcessingJob({
    required this.jobId,
    required this.status,
    this.progress,
    this.message,
    this.modelUrl,
    this.errorCode,
  });

  bool get isTerminal =>
      status == ProcessingStatus.completed ||
      status == ProcessingStatus.failed ||
      status == ProcessingStatus.cancelled;

  ProcessingJob copyWith({ /* ... */ }) => ProcessingJob(/* ... */);
}
```

O getter `isTerminal` é usado pelo controller para decidir quando **parar** o polling — é a regra "pare de perguntar quando a resposta não vai mais mudar".

## Camada `data/`

### `processing_repository.dart`

[lib/features/processing/data/processing_repository.dart](../lib/features/processing/data/processing_repository.dart):

```dart
class ProcessingRepository {
  final Dio _dio;
  ProcessingRepository(this._dio);

  Future<ProcessingJob> fetchStatus(String jobId) async {
    final response = await _dio.get('/captures/$jobId/status');
    final data = response.data as Map<String, dynamic>;

    return ProcessingJob(
      jobId: jobId,
      status: _parseStatus(data['status'] as String),
      progress: (data['progress'] as num?)?.toDouble(),
      message: data['message'] as String?,
      modelUrl: data['modelUrl'] as String?,
      errorCode: data['errorCode'] as String?,
    );
  }

  ProcessingStatus _parseStatus(String raw) {
    return ProcessingStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ProcessingStatus.failed,
    );
  }
}

final processingRepositoryProvider = Provider<ProcessingRepository>((ref) {
  return ProcessingRepository(ref.read(dioClientProvider));
});
```

O parser de status defensivo: se o backend mandar um valor desconhecido, o app presume `failed` em vez de lançar exception. Isso evita que a tela trave em estado inconsistente por causa de um release dessincronizado entre app e backend.

## Camada `presentation/`

### `processing_controller.dart`

[lib/features/processing/presentation/state/processing_controller.dart](../lib/features/processing/presentation/state/processing_controller.dart):

```dart
class ProcessingController extends StateNotifier<ProcessingJob?> {
  final ProcessingRepository _repository;
  Timer? _pollTimer;

  ProcessingController(this._repository) : super(null);

  void start(String jobId) {
    state = ProcessingJob(jobId: jobId, status: ProcessingStatus.queued);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConstants.processingPollInterval, (_) => _poll());
    _poll(); // primeira consulta imediata
  }

  Future<void> _poll() async {
    final currentJob = state;
    if (currentJob == null || currentJob.isTerminal) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final updated = await _repository.fetchStatus(currentJob.jobId);
      state = updated;
      if (updated.isTerminal) {
        _pollTimer?.cancel();
      }
    } on DioException catch (e) {
      state = currentJob.copyWith(
        status: ProcessingStatus.failed,
        message: 'Falha ao consultar status: ${e.message}',
      );
      _pollTimer?.cancel();
    }
  }

  void reset() {
    _pollTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final processingControllerProvider =
    StateNotifierProvider<ProcessingController, ProcessingJob?>((ref) {
  return ProcessingController(ref.read(processingRepositoryProvider));
});
```

Pontos de projeto:

- **Intervalo de 3 segundos** ([AppConstants.processingPollInterval](../lib/core/constants/app_constants.dart)): equilibra *responsividade* com *carga no backend*. 1s seria esbanjador; 10s deixaria o usuário com a sensação de que "travou".
- **Primeira consulta imediata** (`_poll()` chamado logo após o `Timer.periodic`): sem isso, o usuário veria 3 segundos de estado "queued" forçado antes de saber o status real.
- **Auto-stop**: o timer cancela automaticamente quando o job fica terminal. Isso é crítico — um timer rodando a cada 3s indefinidamente seria *leak* energético e de dados.
- **Erro HTTP → `failed`**: se a rede cair durante o polling, o job transita para `failed` e o timer para. A UI mostra erro e o usuário pode voltar/retentar.
- **Não é `autoDispose`**: o usuário pode sair para a home e voltar; o job precisa continuar sendo visto.

### `processing_status_page.dart`

[lib/features/processing/presentation/pages/processing_status_page.dart](../lib/features/processing/presentation/pages/processing_status_page.dart) renderiza o estado atual:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final job = ref.watch(processingControllerProvider);

  if (job == null) {
    return const LoadingView(message: 'Aguardando...');
  }

  final (icon, title) = _statusVisuals(job.status);

  return AppScaffold(
    title: 'Processando',
    body: Center(
      child: Column(
        children: [
          Icon(icon, size: 96),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (job.progress != null) ...[
            const SizedBox(height: 24),
            LinearProgressIndicator(value: job.progress),
          ],
          if (job.message != null) ...[
            const SizedBox(height: 16),
            Text(job.message!),
          ],
          const SizedBox(height: 32),
          if (job.status == ProcessingStatus.completed)
            PrimaryButton(
              label: 'Ver modelo 3D',
              onPressed: () {
                ref.read(viewerControllerProvider.notifier).load(job.modelUrl!);
                context.goNamed(AppRoutes.viewerName);
              },
            ),
          if (job.status == ProcessingStatus.failed)
            PrimaryButton(
              label: 'Voltar',
              onPressed: () => context.goNamed(AppRoutes.homeName),
            ),
        ],
      ),
    ),
  );
}
```

Mapeamento `status → ícone + título`:

| Status | Ícone | Título |
|---|---|---|
| `queued` | `hourglass_empty` | "Na fila" |
| `processing` | `memory` (animado) | "Reconstruindo..." |
| `uploading` | `cloud_upload` | "Preparando download..." |
| `completed` | `check_circle` | "Modelo pronto!" |
| `failed` | `error` | "Falha no processamento" |

**Botões condicionais**:

- `completed`: "Ver modelo 3D" → dispara `viewerController.load(modelUrl)` e navega para `/viewer`.
- `failed`: "Voltar" → `/` (home). Não há "retry" porque o job já foi rejeitado pelo backend — refazer significa voltar à câmera e tirar fotos melhores.
- Estados intermediários não têm botão — é uma tela de espera passiva.

## Fluxo temporal

```
t=0s    CaptureReviewPage.submit() → retorna jobId="abc123"
t=0s    ProcessingController.start("abc123")
        state = queued
t=0s    _poll() dispara (imediato)
t=0.3s  GET /captures/abc123/status → queued
t=3s    _poll() → GET → queued
t=6s    _poll() → GET → processing, progress=0.1
t=9s    _poll() → GET → processing, progress=0.4
...
t=45s   _poll() → GET → completed, modelUrl="http://..."
        _pollTimer.cancel()
        UI mostra botão "Ver modelo 3D"
```

## Para onde ir agora

- A tela final após `completed`: [11 — Feature `product_viewer`](11-feature-product-viewer.md).
- O contrato HTTP detalhado do endpoint de status: [16 — Contrato do backend](16-contrato-backend.md).
