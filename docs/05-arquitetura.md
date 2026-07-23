# 05 - Arquitetura

## Visao geral

O projeto segue uma organizacao **feature-first**. Cada feature concentra modelos, dados, estado e telas relacionados ao seu caso de uso.

Ha dois estilos convivendo:

- `sales`: modulo comercial com `SalesController`, fallback de leitura e escritas backend-first.
- `product_capture` / `processing` / `product_viewer`: pipeline 3D com camadas mais classicas de domain, data e presentation.

## Camadas

### `domain`

Modelos puros de negocio:

- `sales_models.dart`: `Cliente`, `Produto`, `Venda`, `Parcela`, `Pagamento`, `Notificacao`, `SalesSnapshot`.
- `processing_job.dart`: status e metadados do job.
- `product_model.dart`: URL e metadados opcionais do modelo 3D.
- `captured_image.dart`: entidade auxiliar; o estado ativo usa um mapa vista→`File?` e uma lista de extras.

### `data`

Repositorios e acesso externo:

- `SalesController`: restaura o estado real local, sincroniza uma outbox ordenada e carrega `/sales/snapshot`.
- `CaptureRepository`: `POST /captures`.
- `ProcessingRepository`: `GET /captures/{jobId}/status`.
- `ViewerRepository`: placeholder que retorna `ProductModel(modelUrl: url)`.

### `presentation`

Widgets, paginas e controllers Riverpod.

No modulo comercial, varias telas usam estado local (`StatefulWidget`) para filtros, busca, wizard e tabs. Isso e adequado porque esses estados sao descartaveis e nao precisam sobreviver a navegacao.

## Providers atuais

| Provider | Tipo | Responsabilidade |
|---|---|---|
| `appRouterProvider` | `Provider<GoRouter>` | Rotas e guards. |
| `dioClientProvider` | `Provider<Dio>` | Cliente HTTP configurado. |
| `salesControllerProvider` | `StateNotifierProvider<SalesController, SalesSnapshot>` | Estado comercial confirmado pelo backend. |
| `salesSnapshotProvider` | `Provider<SalesSnapshot>` | Snapshot observado pelas telas comerciais. |
| `captureRepositoryProvider` | `Provider<CaptureRepository>` | Upload das imagens. |
| `captureControllerProvider` | `StateNotifierProvider` | Vistas cardeais, extras, upload e erros. |
| `liveCaptureControllerProvider` | `StateNotifierProvider.autoDispose` | Implementacao legada de camera ao vivo, tilt e ORB. |
| `processingRepositoryProvider` | `Provider<ProcessingRepository>` | Consulta status do job. |
| `processingControllerProvider` | `StateNotifierProvider` | Timer de polling e estado do job. |
| `viewerRepositoryProvider` | `Provider<ViewerRepository>` | Carregamento de metadados do modelo. |
| `viewerControllerProvider` | `StateNotifierProvider` | Estado do viewer final. |

## Estado global vs local

### Global via Riverpod

Use quando o estado precisa atravessar telas ou representar uma dependencia compartilhada:

- imagens capturadas;
- status do processamento;
- modelo carregado no viewer;
- snapshot comercial recebido do backend;
- clientes HTTP e repositorios.

### Local via `StatefulWidget`

Use quando o estado so existe enquanto a tela esta aberta:

- busca e filtro de clientes;
- busca de produtos;
- aba selecionada da cobranca;
- etapa atual do wizard;
- produtos selecionados, entrada e parcelas dentro do wizard.

## Roteamento

O app usa `go_router` com rotas nomeadas. A rota inicial e:

```dart
initialLocation: AppRoutes.home
```

`AppRoutes.home` e `/`, e o builder atual e `HomeDashboardPage`.

### Guards

So duas rotas tem `redirect`:

- `captureReviewName`: exige pelo menos uma imagem em `captureControllerProvider`.
- `viewerName`: exige `processingControllerProvider.isCompleted` e `modelUrl != null`.

As rotas comerciais ainda nao tem guards de existencia fortes. Quando um id nao existe, a propria pagina mostra "Cliente nao encontrado", "Venda nao encontrada" ou "Produto nao encontrado".

## Fluxo comercial

`salesSnapshotProvider` retorna um `SalesSnapshot` imutavel. Nao existe fonte
mockada: o controller restaura apenas o cache e as operacoes do usuario, tenta
sincronizar a fila e entao carrega `/sales/snapshot`:

- `clientesById`, `produtosById`, `vendasById`;
- `parcelasResumo`;
- `vencemHoje`, `vencemAmanha`, `emAtraso`;
- `topPagadores`;
- totais financeiros.

O wizard envia a `Venda` ao `SalesController`; somente depois do sucesso de `/sales/sales` atualiza o estado e abre o detalhe.

## Fluxo 3D

1. `CaptureViewsPage` preenche as quatro vistas cardeais e ate duas extras no `CaptureController`.
2. A mesma tela chama `submit()` quando todas as cardeais estao preenchidas.
3. `CaptureRepository` envia `images` e `views` via multipart e retorna `jobId`.
4. `ProcessingController.start(jobId)` inicia timer e polling.
5. Ao concluir, a pagina de processamento chama `viewerController.load(modelUrl)`.
6. `Product3DViewerPage` renderiza com `ModelViewer`.

## Por que `autoDispose` no live capture

`LiveCaptureController` guarda recursos caros:

- stream do acelerometro;
- descritores ORB em memoria nativa;
- objetos OpenCV (`cv.Mat`, `cv.ORB`, `cv.BFMatcher`).

Por isso ele e `autoDispose`: ao sair da camera, cancela stream e libera memoria nativa.

## Tema e tokens

O tema nao e mais um `ColorScheme.fromSeed` generico. Ele usa:

- `AppColors`, `AppRadius`, `AppSpacing` em [app_tokens.dart](../lib/app/theme/app_tokens.dart);
- `GoogleFonts.plusJakartaSansTextTheme`;
- componentes globais para botoes, cards e inputs.

## Proxima leitura

- Rotas completas: [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
- Modulo comercial: [18 - Feature `sales`](18-feature-sales.md).
- Pipeline de captura: [09 - Feature `product_capture`](09-feature-product-capture.md).
