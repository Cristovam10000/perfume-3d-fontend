# 13 - Fluxos de dados

## Fluxo 1 - Snapshot comercial

```text
Sales pages
   |
   v
salesSnapshotProvider
   |
   v
salesControllerProvider
   |
   +-- shared_preferences (snapshot real + outbox + mapa de IDs)
   +-- GET /sales/snapshot (estado confirmado no PostgreSQL)
   +-- retry da outbox a cada 10 segundos
   |
   v
SalesSnapshot
```

`SalesSnapshot` contem as listas comerciais e getters calculados:

- `parcelasResumo`;
- `vencemHoje`;
- `vencemAmanha`;
- `emAtraso`;
- `topPagadores`;
- `totalMesAReceber`;
- `totalHoje`;
- `totalAtraso`.

As telas leem o snapshot com `ref.watch(salesSnapshotProvider)` e derivam a UI.

## Fluxo 2 - Wizard de venda

```text
HomeDashboardPage / ClientDetailPage
   |
   v
SaleWizardPage
   |
   +-- estado local: step, clienteId, items, entrada, parcelas
   |
   v
Confirmar venda
   |
   v
cria Venda(syncStatus: pending)
   |
   v
SalesController.confirmSale(venda)
   |-- persiste snapshot disponivel
   |-- tenta POST /sales/sales
   |
   v
context.goNamed(sale-detail, extra: venda)
   |
   v
SaleDetailPage(draftVenda)
```

A venda confirmada pelo wizard atualiza o `SalesController`, reduz o estoque, persiste o snapshot disponivel e tenta `POST /sales/sales`. `GoRouter.extra` apenas permite abrir o detalhe imediatamente antes de uma eventual recarga remota.

## Fluxo 3 - Produto 3D do catalogo

```text
ProductsPage / dashboard shortcut
   |
   v
Product3DPage(id)
   |
   v
salesSnapshotProvider.produtoById(id)
   |
   v
Produto.modelo3DPath
   |
   v
ModelViewer(src: modelo3DPath)
```

Esse fluxo nao usa `ViewerController`. Ele e especifico do modulo `sales`.

## Fluxo 4 - Captura ao vivo legada

Este fluxo permanece no codigo, mas as rotas atuais usam `CaptureViewsPage` com `image_picker`:

```text
CameraController.startImageStream()
   |
   v
CaptureCameraPage callback
   |
   v
LiveCaptureController.processFrame(frame)
   |
   +-- FrameAnalyzer -> brilho/nitidez/saturacao
   +-- TiltTracker -> pitch do acelerometro
   +-- OrbSimilarityTracker -> similaridade com capturas anteriores
   |
   v
LiveCaptureState.messages
   |
   v
QualityBanner
```

Ao tirar foto:

```text
stopImageStream()
takePicture()
CaptureController.addCapturedFile(File)
LiveCaptureController.markCapturedFromFile(path)
startImageStream()
```

## Fluxo 5 - Upload e processamento

```text
CaptureViewsPage
   |
   v
CaptureController.submit()
   |
   v
CaptureRepository.uploadImages(files, views: views)
   |
   v
POST /captures
   |
   v
UploadResult(jobId)
   |
   v
ProcessingController.start(jobId)
   |
   v
GET /captures/{jobId}/status a cada 3s
   |
   v
ProcessingJob(status, message, modelUrl, error)
```

Quando `completed` com `modelUrl`:

```text
ProcessingStatusPage
   |
   v
viewerController.load(modelUrl)
   |
   v
context.goNamed(viewer)
```

## Fluxo 6 - Viewer final

```text
Product3DViewerPage
   |
   v
viewerControllerProvider
   |
   v
ViewerState(modelUrl)
   |
   v
ModelViewer(src: modelUrl)
```

O botao `Concluir` reseta `processingControllerProvider` e `viewerControllerProvider`, depois volta para `home`.

## Providers por tela

| Tela | Providers observados/usados |
|---|---|
| `HomeDashboardPage` | `salesSnapshotProvider` |
| `ClientsPage` | `salesSnapshotProvider` |
| `ClientDetailPage` | `salesSnapshotProvider` |
| `SaleWizardPage` | `salesSnapshotProvider` |
| `SaleDetailPage` | `salesSnapshotProvider` |
| `BillingPage` | `salesSnapshotProvider` |
| `ProductsPage` | `salesSnapshotProvider` |
| `Product3DPage` | `salesSnapshotProvider` |
| `NotificationsPage` | `salesSnapshotProvider` |
| `CaptureViewsPage` | `captureControllerProvider`, `processingControllerProvider` |
| `ProcessingStatusPage` | `processingControllerProvider`, `viewerControllerProvider` |
| `Product3DViewerPage` | `viewerControllerProvider`, `processingControllerProvider` |

## Lacunas conscientes

- `/captura/:produtoId` associa o job e o GLB ao produto; a captura avulsa omite o campo.
- `/processando/:jobId` inicia ou retoma o polling a partir do parametro.
- Nao ha snapshot mockado. Sem backend, o app mostra somente dados reais
  cacheados e registros criados pelo usuario.
- A fila offline e duravel, ordenada e idempotente; nao ha resolucao
  multiusuario de conflitos.

## Proxima leitura

- Feature comercial: [18 - Feature `sales`](18-feature-sales.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
