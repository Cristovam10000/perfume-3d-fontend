# 09 — Feature `product_capture`

Esta é a feature central do app — onde tudo o que há de tecnicamente interessante acontece. Três telas, dois controllers, um repositório, orquestração de câmera + acelerômetro + OpenCV. Esta página cobre tudo em profundidade.

## Estrutura

```
lib/features/product_capture/
├── domain/
│   └── captured_image.dart
├── data/
│   └── capture_repository.dart
└── presentation/
    ├── state/
    │   ├── capture_controller.dart
    │   ├── capture_state.dart
    │   └── live_capture_controller.dart
    └── pages/
        ├── capture_intro_page.dart
        ├── capture_camera_page.dart
        └── capture_review_page.dart
```

A arquitetura em três camadas (domain, data, presentation) aparece aqui em sua forma completa. Vamos percorrer de baixo para cima.

## Camada `domain/`

### `captured_image.dart`

[lib/features/product_capture/domain/captured_image.dart](../lib/features/product_capture/domain/captured_image.dart) define a entidade que representa uma foto tirada:

```dart
class CapturedImage {
  final String id;           // timestamp ou UUID
  final String path;         // caminho no filesystem temporário
  final DateTime capturedAt;

  const CapturedImage({
    required this.id,
    required this.path,
    required this.capturedAt,
  });
}
```

Classe imutável, sem imports de Flutter ou Dio — é um POJO Dart. Pode ser testada em isolamento e serializada sem drama.

## Camada `data/`

### `capture_repository.dart`

[lib/features/product_capture/data/capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) é a ponte entre a lista de `CapturedImage` e o backend:

```dart
class UploadResult {
  final String jobId;
  const UploadResult({required this.jobId});
}

class CaptureRepository {
  final Dio _dio;
  CaptureRepository(this._dio);

  Future<UploadResult> uploadImages(
    List<CapturedImage> images, {
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'images': await Future.wait(
        images.map((img) async => await MultipartFile.fromFile(
          img.path,
          filename: img.id,
        )),
      ),
    });

    final response = await _dio.post(
      '/captures',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    return UploadResult(jobId: response.data['jobId'] as String);
  }
}

final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return CaptureRepository(ref.read(dioClientProvider));
});
```

Pontos de destaque:

- **Multipart**: `FormData` com campo repetido `images[]`. O backend Python recebe como uma lista de arquivos.
- **`onSendProgress`**: callback do Dio que dispara a cada *chunk* enviado. A presentation usa isso para atualizar a barra de progresso no botão "Enviando...".
- **`MultipartFile.fromFile`**: lê do disco de forma *streamed* — não carrega os 20+ MB na memória ao mesmo tempo.
- **Retorno tipado** (`UploadResult`) em vez de `Map<String, dynamic>` — força o repositório a traduzir o JSON bruto para algo com *schema*, protegendo a camada acima de mudanças no backend.

O `Provider` na última linha é o que os controllers consomem via `ref.read(captureRepositoryProvider)`.

## Camada `presentation/state/`

### `capture_state.dart`

[lib/features/product_capture/presentation/state/capture_state.dart](../lib/features/product_capture/presentation/state/capture_state.dart) é o state imutável:

```dart
class CaptureState {
  final List<CapturedImage> images;
  final double uploadProgress; // 0..1
  final bool isUploading;
  final String? jobId;
  final String? errorMessage;

  const CaptureState({
    this.images = const [],
    this.uploadProgress = 0.0,
    this.isUploading = false,
    this.jobId,
    this.errorMessage,
  });

  CaptureState copyWith({ /* ... */ }) => CaptureState(/* ... */);
}
```

Padrão `copyWith` — produz uma nova instância com alguns campos substituídos. Riverpod + StateNotifier trabalha melhor com estados imutáveis porque a detecção de mudança é por `==`.

### `capture_controller.dart`

[lib/features/product_capture/presentation/state/capture_controller.dart](../lib/features/product_capture/presentation/state/capture_controller.dart) gerencia a coleção de fotos e o upload:

```dart
class CaptureController extends StateNotifier<CaptureState> {
  final CaptureRepository _repository;

  CaptureController(this._repository) : super(const CaptureState());

  void addImage(CapturedImage image) {
    state = state.copyWith(images: [...state.images, image]);
  }

  void removeImage(String id) {
    state = state.copyWith(
      images: state.images.where((i) => i.id != id).toList(),
    );
  }

  void reset() {
    state = const CaptureState();
  }

  Future<void> submit() async {
    state = state.copyWith(isUploading: true, errorMessage: null);
    try {
      final result = await _repository.uploadImages(
        state.images,
        onProgress: (p) => state = state.copyWith(uploadProgress: p),
      );
      state = state.copyWith(
        isUploading: false,
        jobId: result.jobId,
        uploadProgress: 1.0,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Falha no upload: ${e.message}',
      );
    }
  }
}

final captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>((ref) {
  return CaptureController(ref.read(captureRepositoryProvider));
});
```

O controller é **não-autoDispose** — o estado das imagens precisa sobreviver quando a câmera fecha e o usuário vai para a revisão.

### `live_capture_controller.dart`

Este é o controller mais complexo do projeto. [lib/features/product_capture/presentation/state/live_capture_controller.dart](../lib/features/product_capture/presentation/state/live_capture_controller.dart) orquestra **três fontes de dados** em tempo real para produzir um único `LiveCaptureState`:

```dart
class LiveCaptureState {
  final QualityLevel qualityLevel;
  final QualityMessage message; // texto + cor do banner
  final TiltStatus tiltStatus;
  final SimilarityStatus similarityStatus;
  final bool isReady; // pronto para capturar
  // ...
}
```

#### As três fontes

1. **`FrameAnalyzer`** (brilho, nitidez, saturação) — cada 200 ms.
2. **`TiltTracker`** (pitch do aparelho) — contínuo no stream do acelerômetro.
3. **`OrbSimilarityTracker`** (comparação contra fotos já tiradas) — cada 500 ms.

#### Orquestração — método `processFrame`

Chamado pelo `startImageStream` da câmera (~30 FPS), mas o próprio método decide quando realmente trabalhar:

```dart
void processFrame(CameraImage image) {
  final now = DateTime.now();

  // Análise leve: brilho, nitidez, saturação (200 ms)
  if (now.difference(_lastAnalyzerRun) >= _analyzerInterval) {
    _lastAnalyzerRun = now;
    final metrics = _frameAnalyzer.analyze(image);
    _updateFromMetrics(metrics);
  }

  // ORB (500 ms)
  if (now.difference(_lastOrbRun) >= _orbInterval) {
    _lastOrbRun = now;
    _runOrbComparison(image);
  }
}
```

#### Prioridade de mensagens: blocker > warning > ok

O banner no topo da câmera mostra uma única mensagem. Quando múltiplos sinais coincidem (ex: está muito escuro *e* o ângulo é duplicado), o controller aplica prioridade:

```dart
QualityMessage _selectMessage({
  QualityMessage? blurry,
  QualityMessage? brightness,
  QualityMessage? reflective,
  QualityMessage? tilt,
  QualityMessage? similarity,
}) {
  // Blockers (vermelho) vêm primeiro
  if (blurry?.level == MessageLevel.blocker) return blurry!;
  if (brightness?.level == MessageLevel.blocker) return brightness!;
  if (similarity?.level == MessageLevel.blocker) return similarity!;
  // ... depois warnings (amarelo), depois ok (verde)
}
```

Isso evita o usuário corrigir o tilt e só depois descobrir que também estava borrado — mostra o problema mais crítico primeiro.

#### Histerese do blur (`_blurStreakThreshold = 3`)

Esse é um detalhe crítico para UX: detecção de nitidez oscila naturalmente com o movimento da mão. Um único frame borrado não significa que a imagem está "ruim" — significa que o usuário mexeu o celular no momento em que o analyzer rodou.

Solução: só marca `blurry = true` após **3 leituras consecutivas** abaixo do threshold:

```dart
if (sharpness < _blurryThreshold) {
  _blurStreak++;
  if (_blurStreak >= _blurStreakThreshold) {
    // agora sim, banner "foto está borrada"
  }
} else {
  _blurStreak = 0;
}
```

Sem a histerese, o banner amarelo piscaria constantemente e o usuário perderia confiança nas mensagens.

#### Thresholds atuais

```dart
static const double _darkThreshold = 60;
static const double _brightThreshold = 210;
static const double _blurryThreshold = 25;   // variância do Laplaciano
static const double _reflectiveRatio = 0.15; // 15% do frame saturado
static const double _tiltTolerance = 20;     // graus
static const int _blurStreakThreshold = 3;
static const Duration _analyzerInterval = Duration(milliseconds: 200);
static const Duration _orbInterval = Duration(milliseconds: 500);
```

Todos esses valores foram calibrados contra um dispositivo real ([Samsung Galaxy A15](../README.md)) em iluminação doméstica. Em outro hardware ou em outra iluminação, podem precisar ajustes — ficam aqui, em um lugar só, por exatamente esse motivo.

#### Cálculo de `isReady`

```dart
final isReady = qualityLevel != QualityLevel.blocker &&
                tiltStatus == TiltStatus.aligned &&
                similarityStatus != SimilarityStatus.duplicate;
```

O botão de capturar só é habilitado quando todas as três condições são verdadeiras. Isso força o usuário a corrigir o que está errado *antes* de tirar a foto, em vez de tirar fotos ruins que depois são descartadas.

#### `autoDispose` e liberação de memória

Como discutido em [05 — Arquitetura](05-arquitetura.md), esse controller é `autoDispose` porque mantém `Mat`s do OpenCV em memória nativa. Seu `dispose()`:

```dart
@override
void dispose() {
  _accelerometerSubscription?.cancel();
  _orbTracker.dispose(); // libera todas as Mats armazenadas
  super.dispose();
}
```

Sem isso, abrir e fechar a câmera várias vezes vazaria memória nativa até o app crashar.

## Camada `presentation/pages/`

### `capture_intro_page.dart`

[lib/features/product_capture/presentation/pages/capture_intro_page.dart](../lib/features/product_capture/presentation/pages/capture_intro_page.dart) é uma tela explicativa com 5 `InstructionCard`s:

1. **Iluminação** — evite luz direta em reflexos; prefira luz difusa.
2. **Ângulos variados** — cubra todos os lados do frasco.
3. **Enquadramento** — mantenha o perfume dentro da moldura.
4. **Fundo limpo** — superfície lisa sem elementos visuais fortes.
5. **Quantidade mínima** — recomendam-se pelo menos 12–24 fotos.

A tela existe por uma razão concreta: **usuários leigos** não têm intuição para fotogrametria. Uma intro com 5 cartões alinha expectativas antes da câmera abrir — reduz frustração se o resultado final não for ideal.

Botão no fim: `"Continuar"` → `captureCameraName`.

### `capture_camera_page.dart`

[lib/features/product_capture/presentation/pages/capture_camera_page.dart](../lib/features/product_capture/presentation/pages/capture_camera_page.dart) é a tela mais complexa em UI. É um `ConsumerStatefulWidget` porque precisa gerenciar o ciclo de vida da `CameraController` (nativo, não Riverpod-friendly).

#### Ciclo de vida

```dart
@override
void initState() {
  super.initState();
  _initializeCamera();
}

Future<void> _initializeCamera() async {
  final cameras = await availableCameras();
  final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
  _cameraController = CameraController(
    back,
    ResolutionPreset.high,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );
  await _cameraController!.initialize();
  await _cameraController!.startImageStream(_onFrame);
  setState(() => _isInitialized = true);
}

@override
void dispose() {
  _cameraController?.stopImageStream();
  _cameraController?.dispose();
  super.dispose();
}
```

Três pontos técnicos:

- **`ImageFormatGroup.yuv420`**: formato nativo do Android. Evita conversão pra JPEG a cada frame (cara) e dá acesso direto ao plano Y que o `FrameAnalyzer` quer.
- **`enableAudio: false`**: não precisamos de microfone. Reduz latência de inicialização e evita pedir permissão de áudio.
- **`ResolutionPreset.high`**: 720p — equilibra qualidade e performance. 1080p travaria o ORB em aparelhos médios.

#### O método `_onFrame`

```dart
void _onFrame(CameraImage image) {
  ref.read(liveCaptureControllerProvider.notifier).processFrame(image);
}
```

Delega toda a lógica ao controller. A página não faz análise direta.

#### Captura da foto

Um detalhe do plugin `camera` atual: **`takePicture` não pode ser chamado com `startImageStream` ativo**. Então:

```dart
Future<void> _capture() async {
  await _cameraController!.stopImageStream();
  final file = await _cameraController!.takePicture();
  // copia para diretório temporário permanente
  final savedPath = await _persistToAppTmp(file.path);
  ref.read(captureControllerProvider.notifier).addImage(
    CapturedImage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: savedPath,
      capturedAt: DateTime.now(),
    ),
  );
  await _cameraController!.startImageStream(_onFrame);
}
```

Pausar/retomar o stream a cada foto adiciona ~300 ms de *hiccup* visual, mas é obrigatório pelo plugin.

#### UI

A tela sobrepõe:

1. **Preview da câmera** (`CameraPreview` nativo em tela cheia).
2. **`CaptureOverlay`** ([lib/shared/widgets/capture_overlay.dart](../lib/shared/widgets/capture_overlay.dart)) — moldura de enquadramento via `CustomPainter`.
3. **`QualityBanner`** ([lib/shared/widgets/quality_banner.dart](../lib/shared/widgets/quality_banner.dart)) no topo — mostra a mensagem atual do `LiveCaptureController`.
4. **`ImageCounter`** ([lib/shared/widgets/image_counter.dart](../lib/shared/widgets/image_counter.dart)) — indica quantas fotos já foram tiradas.
5. **Controles inferiores**: botão de capturar (disabled se `!isReady`), botão de galeria (fallback com `image_picker`), botão de revisar.

### `capture_review_page.dart`

[lib/features/product_capture/presentation/pages/capture_review_page.dart](../lib/features/product_capture/presentation/pages/capture_review_page.dart) mostra um grid das fotos e dispara o upload:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(captureControllerProvider);
  final qualityReport = ref.watch(imageQualityProvider(state.images.length));

  return AppScaffold(
    title: 'Revisar capturas',
    body: Column(
      children: [
        QualityBanner(report: qualityReport),
        Expanded(child: CapturedImageGrid(
          images: state.images,
          onRemove: (id) => ref.read(captureControllerProvider.notifier).removeImage(id),
        )),
        if (state.isUploading)
          LinearProgressIndicator(value: state.uploadProgress),
        PrimaryButton(
          label: 'Enviar para processamento',
          onPressed: qualityReport.level == QualityLevel.insufficient
              ? null
              : () async {
                  await ref.read(captureControllerProvider.notifier).submit();
                  final jobId = ref.read(captureControllerProvider).jobId;
                  if (jobId != null && context.mounted) {
                    ref.read(processingControllerProvider.notifier).start(jobId);
                    context.goNamed(AppRoutes.processingName);
                  }
                },
        ),
      ],
    ),
  );
}
```

Observações:

- O botão "Enviar" fica **desabilitado** se `QualityLevel.insufficient` (< 12 fotos).
- Após upload bem-sucedido, ativa o `ProcessingController` com o `jobId` retornado e navega para a tela de processamento.
- Se upload falhar, `state.errorMessage` é preenchido e exibido em banner (com retry implícito no botão).

## Grafo de dependências da feature

```
CaptureCameraPage ──▶ captureControllerProvider
       │                    └──▶ captureRepositoryProvider
       │                             └──▶ dioClientProvider
       │
       └──▶ liveCaptureControllerProvider (autoDispose)
                  │
                  ├──▶ FrameAnalyzer      (core/utils)
                  ├──▶ TiltTracker        (core/utils)
                  └──▶ OrbSimilarityTracker (core/utils)

CaptureReviewPage ─▶ captureControllerProvider
                     processingControllerProvider (para acionar start)
```

## Para onde ir agora

- A próxima tela da jornada: [10 — Feature `processing`](10-feature-processing.md).
- Os utilitários internos detalhados: [07 — Camada `core/`](07-camada-core.md).
- Os widgets de UI referenciados: [12 — Widgets compartilhados](12-widgets-compartilhados.md).
- O contrato HTTP que o `CaptureRepository` fala: [16 — Contrato do backend](16-contrato-backend.md).
