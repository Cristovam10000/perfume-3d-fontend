# 11 — Feature `product_viewer`

A feature `product_viewer` é a **tela final** da jornada: exibe o modelo 3D que o backend gerou. Tecnicamente, é a feature mais simples de implementar no app, porque o trabalho pesado (renderização 3D) é delegado ao pacote `model_viewer_plus`, que embute o `<model-viewer>` do Google dentro de um WebView.

## Estrutura

```
lib/features/product_viewer/
├── domain/
│   └── product_model.dart
├── data/
│   └── viewer_repository.dart
└── presentation/
    ├── state/
    │   └── viewer_controller.dart
    └── pages/
        └── product_3d_viewer_page.dart
```

## Camada `domain/`

### `product_model.dart`

[lib/features/product_viewer/domain/product_model.dart](../lib/features/product_viewer/domain/product_model.dart):

```dart
class ProductModel {
  final String id;
  final String modelUrl; // URL do .glb ou .gltf
  final String? name;
  final String? description;

  const ProductModel({
    required this.id,
    required this.modelUrl,
    this.name,
    this.description,
  });
}
```

O modelo é voluntariamente minimalista. Hoje o backend não devolve metadados além do `modelUrl`, mas `name` e `description` ficam prontos para quando houver.

## Camada `data/`

### `viewer_repository.dart`

[lib/features/product_viewer/data/viewer_repository.dart](../lib/features/product_viewer/data/viewer_repository.dart):

```dart
class ViewerRepository {
  final Dio _dio;
  ViewerRepository(this._dio);

  Future<ProductModel> fetchModelMetadata(String modelUrl) async {
    // Placeholder: hoje o backend não expõe metadados separados.
    // Retornamos um ProductModel com apenas o URL.
    return ProductModel(
      id: modelUrl.hashCode.toString(),
      modelUrl: modelUrl,
    );
  }
}

final viewerRepositoryProvider = Provider<ViewerRepository>((ref) {
  return ViewerRepository(ref.read(dioClientProvider));
});
```

Este repositório é essencialmente um **stub**. Existe por consistência com as outras features (domain/data/presentation) e prepara o terreno para quando houver um endpoint `GET /models/{id}` com `name`, `description`, `thumbnailUrl`, etc.

Por enquanto, a "metadata" é apenas o próprio URL.

## Camada `presentation/`

### `viewer_controller.dart`

[lib/features/product_viewer/presentation/state/viewer_controller.dart](../lib/features/product_viewer/presentation/state/viewer_controller.dart):

```dart
class ViewerController extends StateNotifier<ProductModel?> {
  final ViewerRepository _repository;
  ViewerController(this._repository) : super(null);

  Future<void> load(String modelUrl) async {
    state = null;
    try {
      final model = await _repository.fetchModelMetadata(modelUrl);
      state = model;
    } catch (_) {
      state = null; // falha silenciosa — a UI mostra "carregando"
    }
  }

  void clear() {
    state = null;
  }
}

final viewerControllerProvider =
    StateNotifierProvider<ViewerController, ProductModel?>((ref) {
  return ViewerController(ref.read(viewerRepositoryProvider));
});
```

O controller é invocado pela `ProcessingStatusPage` quando o status vira `completed`:

```dart
ref.read(viewerControllerProvider.notifier).load(job.modelUrl!);
context.goNamed(AppRoutes.viewerName);
```

### `product_3d_viewer_page.dart`

[lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart):

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final model = ref.watch(viewerControllerProvider);

  if (model == null) {
    return const LoadingView(message: 'Carregando modelo...');
  }

  return AppScaffold(
    title: 'Visualizador 3D',
    body: Column(
      children: [
        Expanded(
          child: ModelViewer(
            src: model.modelUrl,
            alt: 'Modelo 3D do perfume',
            autoRotate: true,
            cameraControls: true,
            disableZoom: false,
            ar: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: 'Concluir',
            onPressed: () {
              ref.read(captureControllerProvider.notifier).reset();
              ref.read(processingControllerProvider.notifier).reset();
              ref.read(viewerControllerProvider.notifier).clear();
              context.goNamed(AppRoutes.homeName);
            },
          ),
        ),
      ],
    ),
  );
}
```

#### Parâmetros do `ModelViewer`

| Parâmetro | Valor | Razão |
|---|---|---|
| `src` | `model.modelUrl` | URL do .glb/.gltf. Pode ser remoto ou asset local. |
| `alt` | texto descritivo | Acessibilidade — lido por screen readers. |
| `autoRotate` | `true` | O modelo gira sozinho ao carregar — dá uma primeira impressão imediata do objeto. |
| `cameraControls` | `true` | Permite arrastar para rotacionar manualmente, pinçar para zoom. |
| `disableZoom` | `false` | Zoom habilitado. |
| `ar` | `false` | **AR desligado**. Não está no escopo do MVP — adicionar AR requer configurar ARCore no Android e USDZ no iOS, trabalho significativo. |

#### Como o `ModelViewer` funciona internamente

O package `model_viewer_plus` é essencialmente um `WebView` que carrega uma página HTML local com a biblioteca JavaScript [`<model-viewer>`](https://modelviewer.dev/) do Google. O `.glb` é baixado (pela própria WebView) e renderizado via Three.js / WebGL.

Consequências práticas:

- **Requer internet** para baixar o modelo (a não ser que seja asset local).
- **Qualidade depende do WebView** do dispositivo — Android moderno (WebView atualizável) rende muito bem; iOS WKWebView também.
- **Não há cache nativo** — toda vez que a tela abre, o `.glb` é baixado novamente. Isso é aceitável para o MVP; um futuro *enhancement* seria salvar o modelo localmente após o primeiro download.

#### Botão "Concluir"

Ao finalizar, o botão **reseta os três controllers** da jornada:

- `captureController.reset()` — limpa a lista de imagens capturadas.
- `processingController.reset()` — para o polling (se ainda rodar) e limpa o job.
- `viewerController.clear()` — libera o estado do modelo.

E então navega para a home. Isso garante que, se o usuário quiser fazer outra captura, começa do zero sem "fantasmas" do job anterior.

## Por que `ar: false`

Adicionar AR traria:

- **Android**: configuração de ARCore no `AndroidManifest.xml`, detecção de superfície via câmera.
- **iOS**: conversão `.glb → .usdz` (formato exigido pelo Quick Look AR da Apple), entitlements específicos.
- **UX**: uma etapa extra ("posicione no mundo real") que dobra o tempo de testes.

Para um TCC focado em demonstrar o ciclo "captura → processamento → visualização", 3D interativo em tela é suficiente. AR fica como evolução natural.

## Para onde ir agora

- Os fluxos completos da jornada em diagrama: [13 — Fluxos de dados](13-fluxos-de-dados.md).
- Os widgets compartilhados que a página usa (`AppScaffold`, `LoadingView`, `PrimaryButton`): [12 — Widgets compartilhados](12-widgets-compartilhados.md).
