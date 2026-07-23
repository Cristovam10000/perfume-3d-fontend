# 09 - Feature `product_capture`

`product_capture` implementa a captura guiada das vistas usadas na reconstrucao 3D. O fluxo ativo exige quatro vistas cardeais (`front`, `left`, `back`, `right`) e aceita ate duas imagens extras.

## Estrutura ativa

```text
lib/features/product_capture/
  data/
    capture_repository.dart
  domain/
    captured_image.dart
  presentation/
    pages/
      capture_intro_page.dart
      capture_views_page.dart
    state/
      capture_controller.dart
      capture_state.dart
```

`capture_camera_page.dart`, `capture_review_page.dart` e `live_capture_controller.dart` permanecem no codigo como implementacao anterior com preview customizado, sensores e ORB. As rotas atuais concentram captura e revisao em `CaptureViewsPage`.

## Contrato de captura

[capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) envia `images` e, quando disponivel, a lista paralela `views`:

```dart
final formMap = <String, dynamic>{
  'images': [
    for (final file in images)
      await MultipartFile.fromFile(file.path),
  ],
};
if (views != null && views.isNotEmpty) {
  formMap['views'] = views;
}
await dio.post('/captures', data: FormData.fromMap(formMap));
```

- `views.length` precisa coincidir com `images.length`.
- Rotulos aceitos: `front`, `left`, `back`, `right`, `extra` ou string vazia.
- A resposta esperada contem `jobId` como string.
- Erros de Dio sao convertidos em `UploadException`.

## Estado

`CaptureState` guarda:

| Campo | Uso |
|---|---|
| `cardinals` | Mapa das quatro vistas para o arquivo capturado; valor `null` indica slot vazio. |
| `extras` | Ate duas imagens opcionais. |
| `qualityMessages` | Orientacoes calculadas conforme a cobertura. |
| `uploading` / `uploadProgress` | Estado e progresso do envio. |
| `selectingFromGallery` | Evita abrir seletores concorrentes. |
| `error` | Falha amigavel para a UI. |

`allCardinalsFilled` libera o envio. `flattenForUpload()` transforma o mapa e as extras em duas listas paralelas, preservando a ordem das vistas.

## Controller

`CaptureController`:

- captura ou seleciona uma imagem para cada vista;
- permite refazer e remover slots;
- adiciona/remove ate duas extras;
- exige as quatro cardeais antes de enviar;
- chama `CaptureRepository.uploadImages(files, views: views)`;
- retorna o `jobId` para a tela iniciar o polling.

## Paginas e rotas

`CaptureIntroPage` apresenta as orientacoes. `CaptureViewsPage` mostra o grid 2x2 das vistas, a secao de extras, progresso, erros e o botao de envio.

| Rota | Tela atual | Observacao |
|---|---|---|
| `/capture/intro` | `CaptureIntroPage` | Entrada explicativa. |
| `/capture/camera` | `CaptureViewsPage` | Nome mantido por compatibilidade. |
| `/capture/review` | `CaptureViewsPage` | Redireciona ao grid se nenhuma cardeal foi preenchida. |
| `/captura/:produtoId` | `CaptureViewsPage` | O parametro ainda nao e repassado ao `POST /captures`. |

Depois do upload, a tela inicia `ProcessingController.start(jobId)` e navega para `/processing`.

## Proxima leitura

- Constantes e auxiliares: [07 - Camada `core`](07-camada-core.md).
- Polling: [10 - Feature `processing`](10-feature-processing.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
