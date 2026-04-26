# 13 - Fluxos de dados

## Fluxo 1 - Snapshot comercial

```text
Sales pages
   |
   v
salesSnapshotProvider
   |
   v
salesRepositoryProvider
   |
   v
MockSalesRepository.loadSnapshot()
   |
   v
SalesSnapshot
```

`SalesSnapshot` contem listas mockadas e getters calculados:

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
context.goNamed(sale-detail, extra: venda)
   |
   v
SaleDetailPage(draftVenda)
```

A venda criada no wizard nao e persistida no `MockSalesRepository`. Ela e enviada em memoria por `GoRouter.extra`. Por isso, se a tela for recarregada sem `extra`, a venda draft desaparece.

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

## Fluxo 4 - Captura ao vivo

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
CaptureReviewPage
   |
   v
CaptureController.submit()
   |
   v
CaptureRepository.uploadImages(files)
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
| `CaptureCameraPage` | `captureControllerProvider`, `liveCaptureControllerProvider` |
| `CaptureReviewPage` | `captureControllerProvider`, `processingControllerProvider` |
| `ProcessingStatusPage` | `processingControllerProvider`, `viewerControllerProvider` |
| `Product3DViewerPage` | `viewerControllerProvider`, `processingControllerProvider` |

## Lacunas conscientes

- `/captura/:produtoId` nao associa as imagens ao produto.
- `/processando/:jobId` nao inicia polling a partir do parametro.
- Vendas novas nao sao persistidas no repositorio mockado.
- `SyncStatus` e apenas visual; nao ha fila local real.

## Proxima leitura

- Feature comercial: [18 - Feature `sales`](18-feature-sales.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
