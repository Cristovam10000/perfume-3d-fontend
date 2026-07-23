# 11 - Feature `product_viewer`

`product_viewer` e o viewer final do pipeline de captura. Ele renderiza o modelo 3D retornado pelo backend depois que o processamento termina.

Nao confundir com [Product3DPage](../lib/features/sales/presentation/pages/product_3d_page.dart), que e o viewer de produto do catalogo comercial.

## Estrutura

```text
lib/features/product_viewer/
  data/
    viewer_repository.dart
  domain/
    product_model.dart
  presentation/
    pages/
      product_3d_viewer_page.dart
    state/
      viewer_controller.dart
```

## Domain

### `ProductModel`

Campos:

- `modelUrl` obrigatorio;
- `name` opcional;
- `brand` opcional.

Hoje o backend de captura retorna apenas `modelUrl`; nome e marca ficam nulos.

## Data

### `ViewerRepository`

Interface:

```dart
Future<ProductModel> loadModel(String modelUrl);
```

Implementacao atual:

```dart
return ProductModel(modelUrl: modelUrl);
```

Nao ha chamada HTTP adicional para metadados.

## State

### `ViewerState`

Campos:

- `loading`;
- `model`;
- `error`.

### `ViewerController`

Metodos:

- `load(String modelUrl)`: chama repositorio e popula `model`;
- `reset()`: volta para `ViewerState` vazio.

## UI

### `Product3DViewerPage`

Estados renderizados:

- `LoadingView` quando `loading`;
- `ErrorView` se houver erro;
- `ErrorView('Nenhum modelo carregado.')` se nao houver modelo;
- `ModelViewer` quando `model` existe.

Configuracao do `ModelViewer`:

```dart
ModelViewer(
  src: m.modelUrl,
  alt: 'Modelo 3D do perfume',
  ar: false,
  autoRotate: true,
  cameraControls: true,
  disableZoom: false,
)
```

O botao `Concluir` faz:

```dart
ref.read(processingControllerProvider.notifier).reset();
ref.read(viewerControllerProvider.notifier).reset();
context.goNamed(AppRoutes.homeName);
```

Ele nao limpa `captureControllerProvider` no codigo atual.

## Viewer comercial

O modulo `sales` tambem tem viewer 3D:

- arquivo: [product_3d_page.dart](../lib/features/sales/presentation/pages/product_3d_page.dart);
- rota: `/produto/:id/3d`;
- fonte: `Produto.modelo3DPath` recebido em `/sales/snapshot`;
- `autoRotate: false`;
- botao `Vender` para `sale-new`.

## Por que `ar: false`

Realidade aumentada fica fora do escopo atual. O app demonstra inspecao 3D interativa em tela, suficiente para a proposta do MVP.

## Proxima leitura

- Fluxos de dados: [13 - Fluxos de dados](13-fluxos-de-dados.md).
- Contrato do backend: [16 - Contrato do backend](16-contrato-backend.md).
