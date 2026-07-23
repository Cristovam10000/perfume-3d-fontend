# 04 - Estrutura de pastas

Esta e a estrutura atual relevante do front-end.

```text
lib/
  main.dart
  app/
    app.dart
    router/
      app_router.dart
      app_routes.dart
    theme/
      app_theme.dart
      app_tokens.dart
  core/
    constants/
      app_constants.dart
    errors/
      app_exception.dart
    network/
      dio_client.dart
    utils/
      app_formatters.dart
      frame_analyzer.dart
      image_quality_analyzer.dart
      orb_similarity_tracker.dart
      tilt_tracker.dart
  features/
    home/
      presentation/
        home_page.dart
    sales/
      data/
        sales_repository.dart
      domain/
        sales_models.dart
      presentation/
        pages/
          billing_page.dart
          client_detail_page.dart
          clients_page.dart
          home_dashboard_page.dart
          notifications_page.dart
          product_3d_page.dart
          products_page.dart
          sale_detail_page.dart
          sale_wizard_page.dart
        widgets/
          sales_widgets.dart
    product_capture/
      data/
        capture_repository.dart
      domain/
        captured_image.dart
      presentation/
        pages/
          capture_camera_page.dart
          capture_intro_page.dart
          capture_review_page.dart
        state/
          capture_controller.dart
          capture_state.dart
          live_capture_controller.dart
    processing/
      data/
        processing_repository.dart
      domain/
        processing_job.dart
      presentation/
        pages/
          processing_status_page.dart
        state/
          processing_controller.dart
    product_viewer/
      data/
        viewer_repository.dart
      domain/
        product_model.dart
      presentation/
        pages/
          product_3d_viewer_page.dart
        state/
          viewer_controller.dart
  shared/
    widgets/
      app_scaffold.dart
      capture_overlay.dart
      error_view.dart
      image_counter.dart
      image_grid.dart
      instruction_card.dart
      loading_view.dart
      primary_button.dart
      quality_banner.dart

test/
  sale_wizard_test.dart
```

## Raiz

### [main.dart](../lib/main.dart)

Inicializa binding do Flutter, locale `pt_BR`, dados de formatacao do `intl` e o `ProviderScope`.

### [app/app.dart](../lib/app/app.dart)

Define `PerfumeApp`, um `ConsumerWidget` que cria `MaterialApp.router`, usa `AppTheme.light()` e observa `appRouterProvider`.

## `app/router`

### [app_routes.dart](../lib/app/router/app_routes.dart)

Centraliza paths e nomes de rota. Hoje cobre dois grupos:

- rotas comerciais (`/`, `/clientes`, `/venda/nova`, `/cobranca`, `/produtos` etc.);
- rotas do pipeline antigo de captura (`/capture/intro`, `/capture/camera`, `/processing`, `/viewer` etc.).

### [app_router.dart](../lib/app/router/app_router.dart)

Monta o `GoRouter`. A rota inicial `/` abre `HomeDashboardPage`, nao a `HomePage` antiga.

Guards atuais:

- `/capture/review` redireciona para `/capture/camera` se nao houver imagens;
- `/viewer` redireciona para `/processing` se o job nao estiver completo ou nao tiver `modelUrl`.

## `app/theme`

### [app_tokens.dart](../lib/app/theme/app_tokens.dart)

Tokens visuais manuais: `AppColors`, `AppRadius` e `AppSpacing`.

### [app_theme.dart](../lib/app/theme/app_theme.dart)

Tema claro Material 3 com `Plus Jakarta Sans` via `google_fonts`, `ColorScheme.light`, estilos globais de botoes, cards e inputs.

## `core`

Codigo transversal sem UI de tela:

- [app_constants.dart](../lib/core/constants/app_constants.dart): nome do app, backend base URL, limites de captura e intervalo de polling.
- [app_exception.dart](../lib/core/errors/app_exception.dart): excecoes tipadas.
- [dio_client.dart](../lib/core/network/dio_client.dart): cliente HTTP compartilhado.
- [app_formatters.dart](../lib/core/utils/app_formatters.dart): moeda e datas pt-BR.
- [frame_analyzer.dart](../lib/core/utils/frame_analyzer.dart): brilho, nitidez e saturacao do frame.
- [image_quality_analyzer.dart](../lib/core/utils/image_quality_analyzer.dart): mensagens por quantidade de imagens.
- [orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart): ORB + BFMatcher para diferenca de angulo.
- [tilt_tracker.dart](../lib/core/utils/tilt_tracker.dart): inclinacao vertical via acelerometro.

## `features/home`

Contem a `HomePage` original do fluxo de captura. Ela ainda compila, mas nao e a home atual do app. A rota `/` foi migrada para `sales/HomeDashboardPage`.

## `features/sales`

Modulo principal da experiencia atual.

- `domain/sales_models.dart`: modelos de cliente, produto, venda, parcela, pagamento, notificacao e snapshot.
- `data/sales_repository.dart`: `SalesController`, `MockSalesRepository` e providers `salesControllerProvider` / `salesSnapshotProvider`.
- `data/sales_local_storage*.dart`: persistencia em `localStorage` no Web e fallback em memoria nas demais plataformas.
- `presentation/pages`: telas de dashboard, clientes, vendas, cobranca, produtos, viewer 3D de produto e notificacoes.
- `presentation/widgets/sales_widgets.dart`: scaffold e componentes especificos do dominio comercial.

Detalhes em [18 - Feature `sales`](18-feature-sales.md).

## `features/product_capture`

Modulo de captura guiada.

- `CaptureController` guarda um mapa das quatro vistas cardeais, ate duas extras, upload e mensagens de cobertura.
- `CaptureViewsPage` e a tela ativa de captura/revisao e usa camera ou galeria via `image_picker`.
- `LiveCaptureController` e `CaptureCameraPage` permanecem como implementacao anterior de preview customizado, tilt e similaridade ORB.

Detalhes em [09 - Feature `product_capture`](09-feature-product-capture.md).

## `features/processing`

Consulta o backend para acompanhar o job de reconstrucao 3D.

- `ProcessingJob` representa status, mensagem, `modelUrl` e erro.
- `ProcessingController` inicia o polling, tenta novamente e reseta.
- `ProcessingStatusPage` mostra estado e navega para o viewer final.

## `features/product_viewer`

Viewer final do pipeline de captura.

- `ProductModel` contem `modelUrl`, `name` e `brand`.
- `ViewerRepository` hoje so encapsula a URL em `ProductModel`.
- `ViewerController` controla `loading`, `model` e `error`.
- `Product3DViewerPage` usa `ModelViewer`.

## `shared/widgets`

Widgets reutilizados principalmente pelo pipeline de captura/processamento:

- `AppScaffold`
- `PrimaryButton` e `SecondaryButton`
- `InstructionCard`
- `ImageCounter`
- `QualityBanner`
- `CaptureOverlay`
- `CapturedImageGrid`
- `LoadingView`
- `ErrorView`

Widgets do modulo comercial ficam dentro de `features/sales/presentation/widgets`, porque carregam conceitos de cliente, parcela, status e moeda.

## `test`

[sale_wizard_test.dart](../test/sale_wizard_test.dart) cobre comportamento do wizard de venda e navegacao ate o detalhe da venda.

## Criterio pratico

- Use `core/` para infraestrutura e algoritmos sem widget.
- Use `shared/widgets/` para componentes visuais genericos.
- Use `features/<nome>/` quando o codigo expressa um caso de uso do produto.
- Mantenha widgets que conhecem o dominio de vendas dentro de `features/sales`.
