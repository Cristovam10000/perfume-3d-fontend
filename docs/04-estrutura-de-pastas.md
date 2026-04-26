# 04 — Estrutura de pastas

Esta página é o **mapa** do código. Cada arquivo em `lib/` recebe uma linha de propósito. Detalhes de implementação ficam nos documentos dedicados a cada camada.

## Árvore completa

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   └── app_routes.dart
│   └── theme/
│       └── app_theme.dart
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── app_exception.dart
│   ├── network/
│   │   └── dio_client.dart
│   └── utils/
│       ├── frame_analyzer.dart
│       ├── image_quality_analyzer.dart
│       ├── orb_similarity_tracker.dart
│       └── tilt_tracker.dart
├── features/
│   ├── home/
│   │   └── presentation/
│   │       └── home_page.dart
│   ├── product_capture/
│   │   ├── domain/
│   │   │   └── captured_image.dart
│   │   ├── data/
│   │   │   └── capture_repository.dart
│   │   └── presentation/
│   │       ├── state/
│   │       │   ├── capture_state.dart
│   │       │   ├── capture_controller.dart
│   │       │   └── live_capture_controller.dart
│   │       └── pages/
│   │           ├── capture_intro_page.dart
│   │           ├── capture_camera_page.dart
│   │           └── capture_review_page.dart
│   ├── processing/
│   │   ├── domain/
│   │   │   └── processing_job.dart
│   │   ├── data/
│   │   │   └── processing_repository.dart
│   │   └── presentation/
│   │       ├── state/
│   │       │   └── processing_controller.dart
│   │       └── pages/
│   │           └── processing_status_page.dart
│   └── product_viewer/
│       ├── domain/
│       │   └── product_model.dart
│       ├── data/
│       │   └── viewer_repository.dart
│       └── presentation/
│           ├── state/
│           │   └── viewer_controller.dart
│           └── pages/
│               └── product_3d_viewer_page.dart
└── shared/
    └── widgets/
        ├── app_scaffold.dart
        ├── capture_overlay.dart
        ├── error_view.dart
        ├── image_counter.dart
        ├── image_grid.dart
        ├── instruction_card.dart
        ├── loading_view.dart
        ├── primary_button.dart
        └── quality_banner.dart
```

## Camada raiz

### [lib/main.dart](../lib/main.dart)

Entrada do app. Tem 8 linhas. Envolve o widget raiz em `ProviderScope` (pré-requisito do Riverpod) e dispara `runApp`. Nada mais.

## Camada `app/` — a "casca" do aplicativo

Agrupa o que faz o app subir e se orientar. Não contém lógica de domínio — só configuração.

### [lib/app/app.dart](../lib/app/app.dart)

Widget raiz `PerfumeApp`, um `ConsumerWidget`. Lê o provider de roteamento e devolve um `MaterialApp.router` com tema claro/escuro. É onde o `debugShowCheckedModeBanner: false` vive.

### [lib/app/router/app_router.dart](../lib/app/router/app_router.dart)

Cria um `Provider<GoRouter>` com as 6 rotas do app e os dois `redirect` (guards) que impedem pular etapas:

- `/capture/review` → redireciona para `/capture/camera` se não há imagens.
- `/viewer` → redireciona para `/processing` se o job não está `completed` ou o `modelUrl` é null.

### [lib/app/router/app_routes.dart](../lib/app/router/app_routes.dart)

Classe `AppRoutes` privada (construtor `._()`), só com `static const`: seis `paths` (`home`, `captureIntro`, `captureCamera`, `captureReview`, `processing`, `viewer`) e seis `names` (os mesmos com sufixo `Name`). Fonte única da verdade — evita strings mágicas.

### [lib/app/theme/app_theme.dart](../lib/app/theme/app_theme.dart)

Classe `AppTheme` com `light()` e `dark()` estáticos. Usa `ColorScheme.fromSeed` com o seed `#6750A4` (roxo Material 3). Override global para `FilledButton` (altura mínima 52, border radius 16), `OutlinedButton` (mesmo formato), `Card` (elevação 0, border radius 16, fundo `surfaceContainerHighest`) e `AppBar` (centered title, sem elevação).

## Camada `core/` — infraestrutura transversal

Código que **não** depende de nenhuma feature específica e que várias features reutilizam. Regra: se um arquivo só é usado por uma feature, ele deve morar dentro dela; se é usado por duas ou mais, sobe para `core/`.

### [lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart)

Classe `AppConstants` com `const` globais: `appName`, `backendBaseUrl`, `minImages = 12`, `recommendedImages = 24`, `maxImages = 60`, `processingPollInterval = Duration(seconds: 3)`. Fonte única para valores ajustáveis em um só ponto.

### [lib/core/errors/app_exception.dart](../lib/core/errors/app_exception.dart)

Hierarquia simples de exceções: `AppException` (base), `NetworkException`, `UploadException`, `ProcessingException`. Todas carregam `message` e opcionalmente um `cause`. Permite `catch (UploadException e)` em vez de `catch (Exception)`.

### [lib/core/network/dio_client.dart](../lib/core/network/dio_client.dart)

Provider `dioClientProvider` que constrói um `Dio` pré-configurado: base URL vinda de `AppConstants.backendBaseUrl`, timeouts (15 s connect, 30 s receive, 5 min send), `responseType: ResponseType.json` e um `LogInterceptor` que só imprime em builds de debug (via `assert(() { print(...); return true; }())`).

### [lib/core/utils/frame_analyzer.dart](../lib/core/utils/frame_analyzer.dart)

Classe `FrameAnalyzer` + classe `FrameQuality`. Analisa um `CameraImage` YUV420 calculando **brilho** (média do plano Y subamostrado a cada 8 pixels), **saturação** (fração de pixels ≥ 245) e **nitidez** (variância do Laplaciano 3×3 amostrado). É tudo em Dart puro — não depende de nenhum pacote pesado.

### [lib/core/utils/image_quality_analyzer.dart](../lib/core/utils/image_quality_analyzer.dart)

Classe `ImageQualityAnalyzer` + enum `QualityLevel` (`ok`, `warning`, `blocker`) + classe `QualityMessage`. Produz mensagens **baseadas na contagem de imagens**, não no conteúdo delas. É uma camada "burra" de heurística que complementa o `FrameAnalyzer`.

### [lib/core/utils/orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart)

Classe `OrbSimilarityTracker` + enum `AngleVerdict` (`noReference`, `newAngle`, `partialOverlap`, `duplicate`) + classe `SimilarityResult`. **Núcleo técnico** do app: usa OpenCV para extrair ~500 features ORB por frame, comparar via `BFMatcher` (Hamming) + knnMatch + Lowe's ratio test, e classificar se o frame atual é um ângulo novo, parcialmente sobreposto ou duplicata.

### [lib/core/utils/tilt_tracker.dart](../lib/core/utils/tilt_tracker.dart)

Classe `TiltTracker`. Recebe eventos do acelerômetro e calcula o **pitch** (inclinação vertical) suavizado. Disponibiliza `isLevel(tolerance)` e `correction(tolerance)` para a UI avisar "Você está apontando para baixo" ou "para cima".

## Camada `features/` — módulos de negócio

Cada feature segue a sub-estrutura `domain/` + `data/` + `presentation/{state, pages}`. Uma feature **não depende** das outras — elas se comunicam pelo router e por providers globais.

### `features/home/`

A mais simples. Só tem `presentation/home_page.dart`. Sem controller, sem repository, sem estado — é uma página estática que navega para a intro de captura.

#### [lib/features/home/presentation/home_page.dart](../lib/features/home/presentation/home_page.dart)

Widget `HomePage`. Mostra o nome do app, um tagline, três cards explicativos (captura guiada, processamento externo, visualização 3D), um botão "Iniciar captura" que navega para `/capture/intro` e um botão desabilitado "Histórico (em breve)".

### `features/product_capture/`

A feature mais complexa do app. Recebe um documento próprio em [09 — Feature de captura](09-feature-product-capture.md).

#### [lib/features/product_capture/domain/captured_image.dart](../lib/features/product_capture/domain/captured_image.dart)

Model `CapturedImage`: um `File` e o timestamp de captura. Factory `.fromFile()` que carimba a hora atual.

#### [lib/features/product_capture/data/capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart)

Interface `CaptureRepository` + impl `CaptureRepositoryImpl` + model `UploadResult` + provider `captureRepositoryProvider`. Responsável pelo upload multipart das imagens para `POST /captures` e retornar o `jobId` para acompanhamento.

#### [lib/features/product_capture/presentation/state/capture_state.dart](../lib/features/product_capture/presentation/state/capture_state.dart)

Model `CaptureState`: lista de imagens, lista de mensagens de qualidade, flag `uploading`, `uploadProgress` e `error`. Tem `copyWith(..., clearError: bool)`.

#### [lib/features/product_capture/presentation/state/capture_controller.dart](../lib/features/product_capture/presentation/state/capture_controller.dart)

`CaptureController extends StateNotifier<CaptureState>` + `captureControllerProvider`. Gerencia a **coleção persistente** de imagens (adicionar, remover, limpar, enviar) e encapsula `ImagePicker` para a galeria. Roda heurística do `ImageQualityAnalyzer` a cada mudança. Não toca em câmera ao vivo.

#### [lib/features/product_capture/presentation/state/live_capture_controller.dart](../lib/features/product_capture/presentation/state/live_capture_controller.dart)

`LiveCaptureController extends StateNotifier<LiveCaptureState>` + provider **auto-dispose** `liveCaptureControllerProvider`. Recebe cada frame da câmera (via `processFrame`) e orquestra `FrameAnalyzer`, `TiltTracker` e `OrbSimilarityTracker` com throttling (200 ms análise, 500 ms ORB), produzindo mensagens de qualidade e flag `readyToCapture`.

#### [lib/features/product_capture/presentation/pages/capture_intro_page.dart](../lib/features/product_capture/presentation/pages/capture_intro_page.dart)

Página com cinco `InstructionCard` explicando boa iluminação, vários ângulos, centralização, fundo limpo e quantidade mínima. Botão "Começar captura" navega para a câmera.

#### [lib/features/product_capture/presentation/pages/capture_camera_page.dart](../lib/features/product_capture/presentation/pages/capture_camera_page.dart)

`CaptureCameraPage` (ConsumerStatefulWidget). Inicializa `CameraController` em YUV420, liga `startImageStream` repassando frames ao `LiveCaptureController`, mostra `CameraPreview` + `CaptureOverlay`, exibe os banners de qualidade em baixo e tem botões "Galeria" / "Capturar" / "Avançar para revisão". Gerencia ciclo de vida da câmera (`WidgetsBindingObserver`).

#### [lib/features/product_capture/presentation/pages/capture_review_page.dart](../lib/features/product_capture/presentation/pages/capture_review_page.dart)

`CaptureReviewPage` (ConsumerWidget). Mostra um `CapturedImageGrid` com as imagens coletadas, um `ImageCounter` no topo, banner de qualidade e barra de progresso durante upload. Botão "Enviar para processamento" chama `controller.submit()` e, no sucesso, inicia o polling do `ProcessingController` e navega para `/processing`.

### `features/processing/`

Feature de "tela de espera". Doc dedicado: [10 — Feature de processamento](10-feature-processing.md).

#### [lib/features/processing/domain/processing_job.dart](../lib/features/processing/domain/processing_job.dart)

Enum `ProcessingStatus` (`idle`, `waiting`, `uploaded`, `processing`, `completed`, `error`) com `extension ProcessingStatusLabel` (labels em pt-BR). Model `ProcessingJob` com `jobId`, `status`, `message`, `modelUrl`, `error`, helpers `isCompleted`/`hasError`, método `copyWith` e fábrica `parseStatus(String?)` para converter strings do backend em enum.

#### [lib/features/processing/data/processing_repository.dart](../lib/features/processing/data/processing_repository.dart)

Interface `ProcessingRepository` + impl + provider. Chama `GET /captures/{jobId}/status`, parseia o JSON para `ProcessingJob`.

#### [lib/features/processing/presentation/state/processing_controller.dart](../lib/features/processing/presentation/state/processing_controller.dart)

`ProcessingController extends StateNotifier<ProcessingJob>` + `processingControllerProvider`. Abre um `Timer.periodic` a cada `processingPollInterval` (3 s), auto-cancela em `completed`/`error`, oferece `retry()` para re-iniciar e `reset()` para voltar ao estado inicial.

#### [lib/features/processing/presentation/pages/processing_status_page.dart](../lib/features/processing/presentation/pages/processing_status_page.dart)

`ProcessingStatusPage` (ConsumerWidget). Mostra ícone conforme o status (`check_circle_outline`, `settings_suggest_outlined`, etc.), label, job id, `LinearProgressIndicator` (enquanto não é terminal) e mensagem. Botões condicionais: "Visualizar modelo 3D" se concluído, "Tentar novamente" / "Voltar ao início" se erro.

### `features/product_viewer/`

Feature de fim de jornada. Doc dedicado: [11 — Feature de viewer](11-feature-product-viewer.md).

#### [lib/features/product_viewer/domain/product_model.dart](../lib/features/product_viewer/domain/product_model.dart)

Model `ProductModel`: `modelUrl`, `name?`, `brand?`. Name e brand estão reservados para o dia em que o backend passar a expor metadados.

#### [lib/features/product_viewer/data/viewer_repository.dart](../lib/features/product_viewer/data/viewer_repository.dart)

Interface + impl + provider. **No MVP é um stub**: o método `loadModel(String)` apenas devolve `ProductModel(modelUrl: ...)` sem fazer nenhuma chamada de rede. Existe para que, no futuro, basta alterar a impl sem mexer no controller.

#### [lib/features/product_viewer/presentation/state/viewer_controller.dart](../lib/features/product_viewer/presentation/state/viewer_controller.dart)

`ViewerController extends StateNotifier<ViewerState>` + provider. Estado com `loading`, `model?`, `error?`. Método `load(modelUrl)` dispara o repository e atualiza o estado.

#### [lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart)

`Product3DViewerPage` (ConsumerWidget). Mostra `LoadingView` enquanto carrega, `ErrorView` se der erro, ou o widget `ModelViewer` do `model_viewer_plus` com o `.glb` em streaming. Abaixo do viewer, exibe `name` e `brand` (se presentes). Botão "Concluir" reseta `processingController` + `viewerController` e vai para home.

## Camada `shared/widgets/` — UI reutilizável

Componentes que mais de uma feature consome. Todos são `StatelessWidget` de Flutter puro.

- **[app_scaffold.dart](../lib/shared/widgets/app_scaffold.dart)** — `AppScaffold`: Scaffold padronizado com AppBar + SafeArea + `bottomNavigationBar` opcional padding-consistente. Usa `title`, `body`, `bottomBar`, `actions`, `showBack`.
- **[capture_overlay.dart](../lib/shared/widgets/capture_overlay.dart)** — `CaptureOverlay`: guia de enquadramento desenhado via `CustomPaint`. Tem um retângulo arredondado 70% × 55% no centro + cantos destacados + hint opcional em caixa preta semi-transparente na base.
- **[error_view.dart](../lib/shared/widgets/error_view.dart)** — `ErrorView`: ícone de erro + título "Algo deu errado" + mensagem + botão de retry opcional.
- **[image_counter.dart](../lib/shared/widgets/image_counter.dart)** — `ImageCounter`: mostra "X / 24 imagens" com ícone (check ou câmera), selo "mínimo atingido" / "mínimo: 12" e `LinearProgressIndicator`.
- **[image_grid.dart](../lib/shared/widgets/image_grid.dart)** — `CapturedImageGrid`: grid 3 colunas de `Image.file`. Se `onRemove != null`, mostra botão de fechar em cada item.
- **[instruction_card.dart](../lib/shared/widgets/instruction_card.dart)** — `InstructionCard`: card com ícone à esquerda (em caixa colorida) + título + descrição.
- **[loading_view.dart](../lib/shared/widgets/loading_view.dart)** — `LoadingView`: spinner central + mensagem opcional.
- **[primary_button.dart](../lib/shared/widgets/primary_button.dart)** — `PrimaryButton` (`FilledButton`) e `SecondaryButton` (`OutlinedButton`), ambos com `icon?` e `loading?` opcionais.
- **[quality_banner.dart](../lib/shared/widgets/quality_banner.dart)** — `QualityBanner`: banner colorido (verde/laranja/vermelho) conforme o `QualityLevel` da mensagem, com ícone e texto.

Cada um está detalhado em [12 — Widgets compartilhados](12-widgets-compartilhados.md).

## Critério `core/` vs `shared/`

Uma distinção sutil mas importante:

- **`core/`** contém código **sem Flutter UI**: constantes, exceções, clientes HTTP, algoritmos (análise de frame, rastreamento de pitch, ORB). Nunca um `Widget`.
- **`shared/`** contém só UI — widgets reutilizáveis entre features.

Isso significa que `shared/widgets/quality_banner.dart` **importa** `core/utils/image_quality_analyzer.dart` (para conhecer o `QualityLevel`), mas não o contrário. A direção da dependência é sempre `UI → domínio`, nunca o inverso.

## Critério de uma feature vs `core/` / `shared/`

- Se o código é usado **dentro de uma única feature**, mora em `features/<nome>/`.
- Se é usado por **duas ou mais features**, sobe para `core/` (lógica) ou `shared/widgets/` (UI).

Um contra-exemplo útil: o `QualityMessage` e `QualityLevel` estão em `core/utils/` porque o widget `QualityBanner` (em `shared/`) também os consome. Se fossem só da feature de captura, deveriam estar dentro dela.

## Próxima leitura

- Por que a arquitetura foi organizada assim: [05 — Arquitetura](05-arquitetura.md).
- Qual o papel de cada feature em detalhe: documentos 08 a 11.
