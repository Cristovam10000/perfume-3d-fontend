# 05 — Arquitetura

Esta página explica **como o código está organizado** e **por que** as decisões arquiteturais foram tomadas assim.

## Padrão: Clean Architecture + Feature-First

O projeto combina dois padrões complementares:

1. **Clean Architecture** — cada funcionalidade é dividida em três camadas internas (`domain/`, `data/`, `presentation/`) com dependências fluindo sempre da UI para o domínio.
2. **Feature-First** — em vez de agrupar por tipo técnico (`pages/`, `controllers/`, `repositories/` em nível global), tudo que pertence à mesma funcionalidade vive junto sob `lib/features/<nome>/`.

A motivação dessa escolha é bem concreta:

- **Localidade de código**: quando você mexe na tela de câmera, todos os arquivos relevantes estão dentro de `lib/features/product_capture/`. Você não precisa navegar pelo projeto inteiro.
- **Escalabilidade**: adicionar uma nova feature (por exemplo, "Histórico") significa criar `lib/features/history/` sem tocar nas outras — baixo acoplamento por construção.
- **Testabilidade**: domínios são classes Dart puras, repositórios recebem `Dio` via injeção, controladores são `StateNotifier`s isolados. Cada camada pode ser testada sem as de cima.

### Camadas dentro de uma feature

```
lib/features/<nome>/
├── domain/          ← Modelos e enums. Zero imports de Flutter/Dio.
├── data/            ← Repositórios que falam com Dio/arquivos/plataforma.
└── presentation/
    ├── state/       ← Controllers (StateNotifier) + States (classes imutáveis).
    └── pages/       ← Widgets Flutter que consomem os controllers.
```

Regra de dependência: `domain/` não importa nada de cima. `data/` pode importar `domain/`. `presentation/` importa `data/` e `domain/`. Nunca o contrário.

### Por que não MVC/MVVM clássicos

- **MVC** mistura controller e view no mesmo arquivo em projetos Flutter médios — acaba com lógica de negócio dentro do `build()`.
- **MVVM** com packages como `provider` puro exige mais boilerplate para injeção/observação.
- **Clean Architecture** é mais verboso no começo (três pastas por feature), mas paga o custo ao crescer: o *live feedback* da câmera tem três utilitários (`FrameAnalyzer`, `TiltTracker`, `OrbSimilarityTracker`) orquestrados por um controller — esse controller seria um monstro dentro de uma view.

## Gerência de estado: Riverpod

O projeto usa [`flutter_riverpod` ^2.5.1](../pubspec.yaml). Há três tipos de provider em uso:

| Tipo | Quando usar | Exemplo no projeto |
|---|---|---|
| `Provider<T>` | Singleton imutável (dependência construída uma vez) | `dioClientProvider` |
| `StateNotifierProvider<N, S>` | Estado que muda ao longo do tempo | `captureControllerProvider` |
| `StateNotifierProvider.autoDispose` | Estado que deve ser **destruído** quando nenhuma tela o observa | `liveCaptureControllerProvider` |

### Por que `StateNotifier` e não `ChangeNotifier`

- `StateNotifier` expõe um `state` imutável — força você a criar uma nova instância a cada mudança (padrão `copyWith`), o que evita bugs sutis de mutação compartilhada.
- Ele não tem dependência do Flutter, então pode ser testado em um `test/` puro Dart.
- Integra nativamente com Riverpod: `ref.watch(provider)` retorna o state; `ref.read(provider.notifier).method()` chama métodos no controller.

### Por que `autoDispose` no `liveCaptureControllerProvider`

O controller de *live feedback* ([live_capture_controller.dart](../lib/features/product_capture/presentation/state/live_capture_controller.dart)) mantém em memória:

- Uma referência ao `OrbSimilarityTracker` com cache de descritores (KeyPoints + Mat) de **todas** as fotos já tiradas.
- Uma subscription ao `accelerometerEventStream` dos sensores.
- Buffers temporários de análise de frames.

Quando o usuário sai da câmera (navega para a revisão), esses recursos devem ser liberados para não vazar memória nativa do OpenCV. `autoDispose` garante que o controller é descartado assim que a `CaptureCameraPage` sai da árvore de widgets, e seu `dispose()` fecha subscription, limpa caches e chama `_orbTracker.dispose()` (que libera as `Mat`s do OpenCV).

Os demais controllers (captura global, processamento, viewer) sobrevivem à navegação porque o estado precisa persistir entre telas.

## Grafo completo de providers

Todos os providers ativos no projeto, com tipo, localização e quem consome:

| Provider | Tipo | Arquivo | Consumidores |
|---|---|---|---|
| `appRouterProvider` | `Provider<GoRouter>` | [app/router/app_router.dart](../lib/app/router/app_router.dart) | `PerfumeApp` em [app/app.dart](../lib/app/app.dart) |
| `dioClientProvider` | `Provider<Dio>` | [core/network/dio_client.dart](../lib/core/network/dio_client.dart) | `captureRepositoryProvider`, `processingRepositoryProvider` |
| `captureRepositoryProvider` | `Provider<CaptureRepository>` | [features/product_capture/data/capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) | `captureControllerProvider` |
| `captureControllerProvider` | `StateNotifierProvider<CaptureController, CaptureState>` | [features/product_capture/presentation/state/capture_controller.dart](../lib/features/product_capture/presentation/state/capture_controller.dart) | `CaptureCameraPage`, `CaptureReviewPage`, `app_router.dart` (guard) |
| `liveCaptureControllerProvider` | `StateNotifierProvider.autoDispose<LiveCaptureController, LiveCaptureState>` | [features/product_capture/presentation/state/live_capture_controller.dart](../lib/features/product_capture/presentation/state/live_capture_controller.dart) | `CaptureCameraPage` apenas |
| `processingRepositoryProvider` | `Provider<ProcessingRepository>` | [features/processing/data/processing_repository.dart](../lib/features/processing/data/processing_repository.dart) | `processingControllerProvider` |
| `processingControllerProvider` | `StateNotifierProvider<ProcessingController, ProcessingJob?>` | [features/processing/presentation/state/processing_controller.dart](../lib/features/processing/presentation/state/processing_controller.dart) | `ProcessingStatusPage`, `app_router.dart` (guard) |
| `viewerRepositoryProvider` | `Provider<ViewerRepository>` | [features/product_viewer/data/viewer_repository.dart](../lib/features/product_viewer/data/viewer_repository.dart) | `viewerControllerProvider` |
| `viewerControllerProvider` | `StateNotifierProvider<ViewerController, ProductModel?>` | [features/product_viewer/presentation/state/viewer_controller.dart](../lib/features/product_viewer/presentation/state/viewer_controller.dart) | `Product3dViewerPage` |

Total: **9 providers**, formando um grafo em camadas: `Dio` no chão, repositórios no meio, controllers no topo.

## Rotas e guards

A configuração das rotas vive em [app/router/app_router.dart](../lib/app/router/app_router.dart) e é **um provider Riverpod** (`appRouterProvider`). Isso permite que os `redirect` das rotas façam `ref.read(...)` para consultar o estado atual de outros controllers.

Os dois guards ativos:

1. **`/capture/review`** — se `captureControllerProvider.state.images` estiver vazio, redireciona para `/capture/camera`. Evita que o usuário acesse a revisão sem ter tirado nenhuma foto (por exemplo, via deep link).
2. **`/viewer`** — se `processingControllerProvider.state` não estiver em `completed` ou não tiver `modelUrl`, redireciona para `/processing`. Evita renderizar o `ModelViewer` com URL nula.

Poderia ter sido implementado com `if`s dentro dos `build()` das páginas, mas aí cada página precisaria de lógica defensiva — a centralização nos guards mantém as páginas focadas em UI.

## Throttling de frames

Um ponto de arquitetura sutil mas importante: o stream de frames da câmera dispara em ~30 FPS. Rodar ORB a cada frame travaria a UI em qualquer celular de gama intermediária. Então o [`LiveCaptureController`](../lib/features/product_capture/presentation/state/live_capture_controller.dart) aplica **dois intervalos de throttling independentes**:

| Tipo de análise | Intervalo | Custo aproximado |
|---|---|---|
| `FrameAnalyzer` (brilho, nitidez, saturação) | 200 ms | ~5 ms em um A15 |
| `OrbSimilarityTracker` | 500 ms | ~80–150 ms em um A15 |

A separação existe porque análise de pixels no plano Y é barata (só um loop subsampleado) — dá para rodar a 5 Hz sem custo notável, mantendo o banner de qualidade responsivo. ORB é caro (detecta features, computa descritores, faz kNN matching contra cada imagem já tirada) — a 2 Hz o usuário ainda percebe como "tempo real" mas a CPU não sofre.

## Dois controllers para a mesma feature

`CaptureController` e `LiveCaptureController` podem parecer redundantes. Não são — têm responsabilidades distintas:

- **`CaptureController`** ([capture_controller.dart](../lib/features/product_capture/presentation/state/capture_controller.dart)): guarda a lista de `CapturedImage` já capturadas, `uploadProgress`, e o `jobId` retornado do backend. Sobrevive à navegação. Compartilhado entre câmera, revisão e upload.
- **`LiveCaptureController`** ([live_capture_controller.dart](../lib/features/product_capture/presentation/state/live_capture_controller.dart)): guarda o estado **instantâneo** do frame atual — `QualityLevel`, `QualityMessage`, `tiltStatus`, `similarityStatus`, `isReady`. Vive apenas enquanto a câmera está aberta.

Colocar tudo em um controller só acabaria com um `CaptureState` enorme onde metade dos campos são descartados em cada tela. A separação mantém cada state focado no que a tela realmente precisa.

## Diretórios `core/` vs. `shared/`

Tanto `core/` quanto `shared/` abrigam código reutilizável, mas com um critério claro:

| Pasta | Conteúdo | Importa Flutter? |
|---|---|---|
| `core/` | Infraestrutura: constantes, exceptions, Dio, utilitários de processamento (frame, tilt, ORB, qualidade) | **Não** (exceto Dart SDK e packages não-UI) |
| `shared/` | Widgets reutilizáveis que aparecem em várias features | **Sim** — todos são `StatelessWidget`/`StatefulWidget` |

Esse critério mantém `core/` testável sem `flutter_test`, apenas com `dart test`. E impede que se empilhem widgets em um "utilitários" genérico — se tem `Widget` na classe, vai para `shared/`.

## Para onde ir agora

- O mapa concreto dos arquivos: [04 — Estrutura de pastas](04-estrutura-de-pastas.md).
- Como o app sobe e roteia as telas: [06 — Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
- Os utilitários de `core/` explicados em profundidade: [07 — Camada `core/`](07-camada-core.md).
