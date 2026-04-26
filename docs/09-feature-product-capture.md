# 09 - Feature `product_capture`

`product_capture` e o modulo de captura guiada de imagens para reconstrucao 3D. Ele continua ativo e pode ser acessado por rotas antigas (`/capture/...`) ou pelo atalho comercial `/captura/:produtoId`.

## Estrutura

```text
lib/features/product_capture/
  data/
    capture_repository.dart
  domain/
    captured_image.dart
  presentation/
    pages/
      capture_camera_page.dart
      capture_intro_page.dart
      capture_review_page.dart
    state/
      capture_controller.dart
      capture_state.dart
      live_capture_controller.dart
```

## Domain

### `captured_image.dart`

Modelo simples:

```dart
class CapturedImage {
  final File file;
  final DateTime capturedAt;
}
```

Observacao: o estado ativo da captura usa `List<File>` diretamente em `CaptureState`. `CapturedImage` esta pronto para evolucao, mas nao e o tipo usado na lista principal hoje.

## Data

### `capture_repository.dart`

`CaptureRepositoryImpl.uploadImages` recebe `List<File>` e envia multipart:

```dart
final formData = FormData.fromMap({
  'images': [
    for (final f in images)
      await MultipartFile.fromFile(
        f.path,
        filename: f.uri.pathSegments.last,
      ),
  ],
});

final response = await _dio.post('/captures', data: formData);
```

Contrato esperado:

- request: campo multipart `images`;
- response: JSON com `jobId` string.

Se a resposta nao tiver `jobId`, o repositorio lanca `UploadException`.

## Estado persistente da captura

### `CaptureState`

Campos atuais:

| Campo | Uso |
|---|---|
| `images` | Lista de arquivos capturados/selecionados. |
| `qualityMessages` | Mensagens por quantidade de imagens. |
| `uploading` | Indica envio em andamento. |
| `uploadProgress` | Progresso `0..1`. |
| `error` | Mensagem de falha. |
| `count` | Atalho para `images.length`. |
| `canReview` | `true` quando ha ao menos uma imagem. |

### `CaptureController`

Responsabilidades:

- recomputar mensagens com `ImageQualityAnalyzer`;
- adicionar arquivo capturado via `addCapturedFile(File)`;
- abrir camera nativa via `captureFromCamera()` como fallback;
- escolher multiplas imagens da galeria via `pickFromGallery()`;
- remover imagem por indice;
- limpar estado;
- enviar imagens e retornar `jobId`.

`submit()` nao navega. Ele retorna `String?` para a pagina decidir o proximo passo.

## Estado ao vivo da camera

### `LiveCaptureState`

Campos principais:

- `messages`: banners de feedback;
- `brightness`;
- `sharpness`;
- `capturesCount`;
- `verdict`: resultado do ORB;
- `matchCount`;
- `readyToCapture`.

### `LiveCaptureController`

Combina:

- `FrameAnalyzer` a cada 200 ms;
- `OrbSimilarityTracker` a cada 500 ms;
- `TiltTracker` alimentado por `accelerometerEventStream()`.

Thresholds atuais:

| Valor | Significado |
|---|---|
| `_darkThreshold = 60` | abaixo disso, ambiente escuro. |
| `_brightThreshold = 210` | acima disso, luz forte. |
| `_blurryThreshold = 25` | nitidez minima. |
| `_reflectiveRatio = 0.15` | saturacao/reflexo alto. |
| `_tiltTolerance = 20` | tolerancia em graus. |
| `_blurStreakThreshold = 3` | histerese contra alerta piscando. |

`readyToCapture` e calculado, mas a UI atual ainda habilita o botao de captura quando a camera esta inicializada. As mensagens continuam orientando o usuario; se o produto exigir bloqueio mais rigido, a condicao ja existe no estado.

## Paginas

### `CaptureIntroPage`

Mostra instrucoes antes da camera:

- boa iluminacao;
- varios angulos;
- centralizacao;
- fundo limpo;
- quantidade minima.

Botao: `Comecar captura` -> `captureCameraName`.

### `CaptureCameraPage`

E um `ConsumerStatefulWidget` porque gerencia `CameraController`, ciclo de vida do app e stream nativo.

Fluxo tecnico:

1. busca cameras com `availableCameras()`;
2. escolhe camera traseira;
3. cria `CameraController` com `ResolutionPreset.high`, `enableAudio: false`, `ImageFormatGroup.yuv420`;
4. inicia `startImageStream`;
5. envia cada frame para `liveCaptureControllerProvider.notifier.processFrame(frame)`;
6. ao fotografar, para o stream, chama `takePicture()`, adiciona o arquivo no `CaptureController`, registra descritores ORB e reinicia o stream.

UI:

- `ImageCounter`;
- preview com `CameraPreview`;
- `CaptureOverlay`;
- ate duas mensagens de `QualityBanner`;
- botoes `Galeria`, `Capturar` e `Avancar para revisao`.

### `CaptureReviewPage`

Mostra:

- contador;
- primeiro banner de qualidade;
- grid 3 colunas com remocao;
- `LinearProgressIndicator` durante upload;
- botoes `Capturar mais` e `Enviar para processamento`.

Ao enviar:

1. chama `controller.submit()`;
2. se vier `jobId`, chama `processingControllerProvider.notifier.start(jobId)`;
3. navega para `AppRoutes.processingName`.

## Rotas relacionadas

| Rota | Uso |
|---|---|
| `/capture/intro` | fluxo antigo explicativo. |
| `/capture/camera` | camera direta. |
| `/capture/review` | revisao com guard de imagens. |
| `/captura/:produtoId` | entrada comercial para captura, ainda sem usar `produtoId`. |

## Proxima leitura

- Algoritmos: [07 - Camada `core`](07-camada-core.md).
- Processamento: [10 - Feature `processing`](10-feature-processing.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
