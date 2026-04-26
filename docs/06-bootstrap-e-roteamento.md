# 06 - Bootstrap e roteamento

## `main.dart`

[lib/main.dart](../lib/main.dart) inicializa dependencias antes do `runApp`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const ProviderScope(child: PerfumeApp()));
}
```

Responsabilidades:

- garantir binding do Flutter;
- configurar locale padrao;
- carregar simbolos de data pt-BR;
- criar o container raiz do Riverpod.

## `PerfumeApp`

[lib/app/app.dart](../lib/app/app.dart):

```dart
class PerfumeApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Perfume 3D MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
```

O app atual declara apenas tema claro. Nao ha `darkTheme` ativo.

## Tema

[app_theme.dart](../lib/app/theme/app_theme.dart) monta `ThemeData` com:

- `useMaterial3: true`;
- `ColorScheme.light` baseado em tokens manuais;
- `scaffoldBackgroundColor: AppColors.bg`;
- `GoogleFonts.plusJakartaSansTextTheme`;
- estilos globais para `AppBar`, `FilledButton`, `OutlinedButton`, `Card` e `InputDecoration`.

Os tokens ficam em [app_tokens.dart](../lib/app/theme/app_tokens.dart).

## Rotas

As constantes ficam em [app_routes.dart](../lib/app/router/app_routes.dart).

| Path | Nome | Tela |
|---|---|---|
| `/` | `home` | `HomeDashboardPage` |
| `/clientes` | `clients` | `ClientsPage` |
| `/cliente/:id` | `client-detail` | `ClientDetailPage` |
| `/venda/nova` | `sale-new` | `SaleWizardPage` |
| `/venda/:id` | `sale-detail` | `SaleDetailPage` |
| `/cobranca` | `billing` | `BillingPage` |
| `/produtos` | `products` | `ProductsPage` |
| `/produto/:id/3d` | `product-3d` | `Product3DPage` |
| `/captura/:produtoId` | `capture-by-product` | `CaptureCameraPage` |
| `/processando/:jobId` | `processing-by-job` | `ProcessingStatusPage` |
| `/notificacoes` | `notifications` | `NotificationsPage` |
| `/capture/intro` | `capture-intro` | `CaptureIntroPage` |
| `/capture/camera` | `capture-camera` | `CaptureCameraPage` |
| `/capture/review` | `capture-review` | `CaptureReviewPage` |
| `/processing` | `processing` | `ProcessingStatusPage` |
| `/viewer` | `viewer` | `Product3DViewerPage` |

Observacoes importantes:

- `/captura/:produtoId` ja existe para entrada a partir de produto, mas o `produtoId` ainda nao e usado pela tela de camera.
- `/processando/:jobId` ja existe, mas a tela nao reidrata o `ProcessingController` a partir do parametro.
- A rota inicial `/` abre `HomeDashboardPage`, nao `features/home/HomePage`.

## Guards

### `/capture/review`

```dart
final images = ref.read(captureControllerProvider).images;
if (images.isEmpty) return AppRoutes.captureCamera;
```

Evita abrir revisao sem imagens.

### `/viewer`

```dart
final job = ref.read(processingControllerProvider);
if (!job.isCompleted || job.modelUrl == null) {
  return AppRoutes.processing;
}
```

Evita renderizar `ModelViewer` sem URL valida.

## Navegacao comercial

O app usa `SalesScaffold` com bottom navigation em quatro abas:

- Inicio -> `home`;
- Clientes -> `clients`;
- Produtos -> `products`;
- Cobranca -> `billing`;

O botao central de adicionar abre `sale-new` via `context.pushNamed`.

## Navegacao do pipeline 3D

Fluxo classico:

```text
capture-intro -> capture-camera -> capture-review -> processing -> viewer
```

Atalhos atuais:

- dashboard "Capturar" chama `capture-by-product` com o primeiro produto mockado;
- dashboard "3D" chama `product-3d` com o primeiro produto mockado;
- `Product3DPage` tem botao "Vender" para `sale-new`.

## `go` vs `push`

O codigo usa os dois estilos:

- `goNamed`: troca a localizacao atual, comum em abas e mudancas de fluxo.
- `pushNamed`: empilha detalhe, notificacoes, wizard ou telas abertas como drill-down.

## Proxima leitura

- Modulo comercial: [18 - Feature `sales`](18-feature-sales.md).
- Fluxos de dados: [13 - Fluxos de dados](13-fluxos-de-dados.md).
