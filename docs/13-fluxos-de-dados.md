# 13 — Fluxos de dados

Esta página mostra, em diagramas ASCII e pseudocódigo, **como os dados transitam pelo app** nos três cenários principais: captura em tempo real, upload para o backend e carregamento do modelo 3D. Serve como referência visual para entender a integração entre as camadas e os packages externos.

## Fluxo 1 — Captura em tempo real

O fluxo mais técnico do app. Cada frame da câmera é processado em paralelo por três análises, cujos resultados alimentam um único `LiveCaptureState` exibido como banner na UI.

```
┌─────────────────┐
│  CameraPlugin   │  (30 FPS, YUV420)
│ startImageStream│
└────────┬────────┘
         │ CameraImage
         ▼
┌──────────────────────────────┐
│   CaptureCameraPage._onFrame │
│      (ConsumerStatefulWidget)│
└────────┬─────────────────────┘
         │ ref.read(liveCaptureControllerProvider.notifier).processFrame(image)
         ▼
┌──────────────────────────────────────────────────────┐
│             LiveCaptureController                    │
│  ┌─────────────────────────────────────────────┐     │
│  │ Throttle check (timestamp do último run)    │     │
│  └───┬────────────────────────┬────────────────┘     │
│      │ a cada 200ms           │ a cada 500ms         │
│      ▼                        ▼                      │
│  ┌──────────────┐         ┌──────────────────────┐   │
│  │FrameAnalyzer │         │OrbSimilarityTracker  │   │
│  │  (plano Y)   │         │(OpenCV ORB+BFMatcher)│   │
│  └──────┬───────┘         └──────────┬───────────┘   │
│         │ FrameMetrics               │ SimilarityStatus
│         ▼                            ▼               │
│  ┌──────────────────────────────────────────┐        │
│  │        _buildQualityMessage(...)         │        │
│  │  (aplica prioridade blocker>warn>ok)     │        │
│  └──────────────────┬───────────────────────┘        │
└─────────────────────┼────────────────────────────────┘
                      │ state = LiveCaptureState(...)
                      ▼
               Riverpod reactive update
                      │
                      ▼
          ┌─────────────────────────┐
          │  QualityBanner + border │
          │  color do CaptureOverlay│
          └─────────────────────────┘
```

Em paralelo (stream contínuo do sensores_plus, não throttled):

```
┌───────────────────────┐
│ accelerometerEventStream
└──────────┬────────────┘
           │ AccelerometerEvent(x,y,z)
           ▼
     ┌──────────────┐
     │ TiltTracker  │  pitch = atan2(z, sqrt(x²+y²))
     │  (+ smoothing)│ smoothed = 0.85*prev + 0.15*new
     └──────┬───────┘
            │ TiltStatus (aligned | tilted)
            ▼
    LiveCaptureController (mesmo state acima)
```

**Frequências efetivas**:

- Atualização do state geral: cada 200 ms (quando o analyzer roda) ou cada 500 ms (quando ORB roda) — o que vier primeiro.
- Atualização só de tilt: conforme o stream de acelerômetro (tipicamente ~10 Hz).

O usuário percebe isso como **um banner que responde imediatamente** às mudanças de iluminação ou tilt, e reavalia a duplicata a cada meio segundo.

## Fluxo 2 — Captura da foto + upload

Quando o usuário aperta o botão de capturar e depois "Enviar para processamento".

```
CaptureCameraPage._capture()
         │
         ├─▶ cameraController.stopImageStream()   (plugin exige)
         ├─▶ cameraController.takePicture()        → XFile
         ├─▶ _persistToAppTmp(xfile.path)          → path estável
         ├─▶ captureControllerProvider.addImage(
         │        CapturedImage(id, path, capturedAt))
         └─▶ cameraController.startImageStream(...) (retoma)

           [... usuário tira mais fotos e navega para revisão ...]

CaptureReviewPage → botão "Enviar"
         │
         ├─▶ captureControllerProvider.submit()
         │      │
         │      ├─▶ state.copyWith(isUploading: true)
         │      ├─▶ _repository.uploadImages(
         │      │        images,
         │      │        onProgress: (p) => state.copyWith(progress: p),
         │      │     )
         │      │      │
         │      │      ├─▶ Dio.post('/captures', FormData com images[])
         │      │      │     │   ... chunks streamed do disco ...
         │      │      │     └─▶ onSendProgress callback
         │      │      │
         │      │      └─▶ response = { "jobId": "abc123" }
         │      │
         │      └─▶ state.copyWith(jobId: "abc123", isUploading: false)
         │
         └─▶ processingControllerProvider.start("abc123")
             │
             ├─▶ state = ProcessingJob(queued)
             ├─▶ Timer.periodic(3s, _poll)
             ├─▶ _poll() imediato
             │
             └─▶ context.goNamed("processing")
```

**Garantias do fluxo**:

- A foto já está em disco persistente (`app/tmp`) antes de ser adicionada ao state — sobrevive a um hot restart.
- O upload é *streamed*: Dio lê o arquivo em chunks, não carrega tudo na RAM.
- O `onSendProgress` alimenta a `LinearProgressIndicator` em tempo real.
- Falha de rede vira `state.errorMessage` sem perder as imagens capturadas — o usuário pode tentar de novo.

## Fluxo 3 — Polling + carregamento do modelo 3D

A etapa final: esperar o backend processar e depois exibir o `.glb`.

```
ProcessingController.start(jobId)
       │
       └──▶ Timer.periodic(3s) ativado

   [loop de polling a cada 3s]
       │
       ▼
   _poll()
       │
       ├──▶ Dio.get("/captures/{jobId}/status")
       │        │
       │        └──▶ { status, progress, message, modelUrl?, errorCode? }
       │
       ├──▶ _repository parseia → ProcessingJob
       ├──▶ state = ProcessingJob(...)
       │
       └──▶ se isTerminal: Timer.cancel()

   [quando status == completed]
       │
       ▼
   ProcessingStatusPage mostra botão "Ver modelo 3D"
       │
       │ (usuário toca)
       ▼
   viewerControllerProvider.load(modelUrl)
       │
       ├──▶ _repository.fetchModelMetadata(url)  (stub hoje)
       │        └─▶ ProductModel(id, modelUrl)
       └──▶ state = ProductModel
       │
       ▼
   context.goNamed("viewer")
       │
       ▼
   Product3dViewerPage
       │
       └──▶ ModelViewer(src: model.modelUrl, ...)
                │
                └──▶ WebView interno
                       │
                       └──▶ <model-viewer> JS + Three.js
                              │
                              └──▶ GET model.modelUrl (HTTPS)
                                      │
                                      └──▶ decode .glb → WebGL mesh
                                               │
                                               └──▶ render + autoRotate
```

**Observações do fluxo**:

- O app **não baixa** o `.glb` explicitamente — o WebView faz isso sozinho via HTTP. Isso significa que o `dioClientProvider` não participa deste carregamento.
- Se o URL não for acessível (backend caiu, modelo não existe), o próprio `<model-viewer>` mostra um erro dentro da WebView. O app Flutter não intercepta — um *enhancement* futuro seria validar a URL antes (ex: `HEAD /model.glb`).
- O botão "Concluir" reseta os três controllers e volta para a home.

## Grafo de providers em tempo de execução

Uma visão "fotográfica" de quais providers estão vivos em cada tela:

| Tela | Providers ativos |
|---|---|
| `HomePage` | `appRouterProvider` |
| `CaptureIntroPage` | `appRouterProvider` |
| `CaptureCameraPage` | `appRouterProvider`, `captureControllerProvider`, `liveCaptureControllerProvider` (autoDispose), `dioClientProvider` (transitivo) |
| `CaptureReviewPage` | `appRouterProvider`, `captureControllerProvider`, `captureRepositoryProvider`, `dioClientProvider` |
| `ProcessingStatusPage` | `appRouterProvider`, `processingControllerProvider`, `processingRepositoryProvider`, `dioClientProvider`, `captureControllerProvider` (ainda vivo, não foi descartado) |
| `Product3dViewerPage` | `appRouterProvider`, `viewerControllerProvider`, `viewerRepositoryProvider`, `dioClientProvider`, `processingControllerProvider` (ainda vivo) |

Só o `liveCaptureControllerProvider` é descartado ao sair da câmera — todos os outros sobrevivem até o botão "Concluir" da viewer resetar manualmente.

## Para onde ir agora

- Detalhes do contrato HTTP que esses fluxos usam: [16 — Contrato do backend](16-contrato-backend.md).
- A história de por que esse fluxo é assim (pivot do walk-around para ORB): [14 — Histórico de mudanças](14-historico-de-mudancas.md).
