# 09 - Feature `product_capture`

`product_capture` implementa a captura guiada das vistas usadas na reconstrucao 3D. O fluxo ativo exige quatro vistas cardeais (`front`, `left`, `back`, `right`) e aceita ate duas imagens extras.

## Estrutura ativa

```text
lib/features/product_capture/
  data/
    capture_repository.dart
    capture_session_store.dart
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

[capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) envia `images`, a lista paralela `views` e, quando a rota veio de um produto, `productId`:

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
if (productId != null) {
  formMap['productId'] = productId;
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
| `selectingImage` | Evita abrir camera/galeria concorrentes, inclusive para extras. |
| `error` | Falha amigavel para a UI. |
| `productId` | Produto comercial opcional ao qual o novo GLB sera vinculado. |

`allCardinalsFilled` libera o envio. `flattenForUpload()` transforma o mapa e as extras em duas listas paralelas, preservando a ordem das vistas.

## Controller

`CaptureController`:

- captura ou seleciona uma imagem para cada vista;
- permite refazer e remover slots;
- adiciona/remove ate duas extras;
- exige as quatro cardeais antes de enviar;
- chama `CaptureRepository.uploadImages(files, views: views, productId: productId)`;
- retorna o `jobId` para a tela iniciar o polling.

## Memoria e recuperacao no Android

As fotos escolhidas continuam em resolucao original para o upload. O app nao
passa `imageQuality`, `maxWidth` ou `maxHeight` ao `image_picker`, evitando que
o plugin decodifique uma foto de 50 MP apenas para recomprimi-la.

Na interface, os originais nunca sao decodificados no tamanho completo:

- cards das vistas usam `cacheWidth: 768`;
- extras usam `cacheWidth: 240`.

Esses limites afetam somente o preview; o JPEG enviado ao backend nao perde
resolucao. Isso evita que quatro fotos `8160 x 6120` ocupem mais de 1 GB entre
bitmaps e memoria grafica.

`CaptureSessionStore` copia os arquivos sem decodificacao para a pasta privada
de suporte do aplicativo e grava `session.json` com as vistas, extras, `productId` e o alvo
pendente. Se o Android encerrar a Activity enquanto o Photo Picker estiver
aberto, `ImagePicker.retrieveLostData()` restaura o resultado na vista correta.
O rascunho e removido ao limpar a captura ou depois de um upload concluido.

## Paginas e rotas

`CaptureIntroPage` apresenta as orientacoes. `CaptureViewsPage` mostra o grid 2x2 das vistas, a secao de extras, progresso, erros e o botao de envio.

| Rota | Tela atual | Observacao |
|---|---|---|
| `/capture/intro` | `CaptureIntroPage` | Entrada explicativa. |
| `/capture/camera` | `CaptureViewsPage` | Nome mantido por compatibilidade. |
| `/capture/review` | `CaptureViewsPage` | Redireciona ao grid se nenhuma cardeal foi preenchida. |
| `/captura/:produtoId` | `CaptureViewsPage` | Envia `productId` e preserva o vínculo ao restaurar o rascunho. |

Depois do upload, a tela inicia `ProcessingController.start(jobId, productId: ...)`
e navega para `/processing`. O status também devolve `productId`, permitindo recuperar
o vínculo ao retomar um job.

## Proxima leitura

- Constantes e auxiliares: [07 - Camada `core`](07-camada-core.md).
- Polling: [10 - Feature `processing`](10-feature-processing.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
