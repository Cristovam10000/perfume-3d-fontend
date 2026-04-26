# 06 — Bootstrap e roteamento

Esta página cobre **como o app inicializa** (da chamada `main()` até a primeira tela desenhada) e **como a navegação funciona** entre as 6 telas.

## `main.dart`: o ponto de entrada

O arquivo [lib/main.dart](../lib/main.dart) é deliberadamente minúsculo:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  runApp(const ProviderScope(child: PerfumeApp()));
}
```

Três coisas importantes acontecem nessas duas linhas de `main()`:

1. **`runApp`** inicializa o binding do Flutter e começa o event loop.
2. **`ProviderScope`** é o *container raiz* do Riverpod. Qualquer `ProviderContainer` criado descendentemente compartilha estado. Sem ele, nenhum `ref.watch` funciona.
3. **`PerfumeApp`** é o widget raiz — mas a lógica interessante está nele, não aqui.

Esse padrão (`main` enxuto que apenas embrulha `ProviderScope`) é o recomendado pela documentação oficial do Riverpod. Lógica de inicialização mais complexa (splash screens nativos, setup de Firebase, etc.) não é necessária neste MVP.

## `app.dart`: o widget raiz

[lib/app/app.dart](../lib/app/app.dart) define `PerfumeApp` como um `ConsumerWidget`:

```dart
class PerfumeApp extends ConsumerWidget {
  const PerfumeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Perfume 3D MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
```

Pontos a observar:

- **`ConsumerWidget`** (de `flutter_riverpod`) permite usar `ref.watch` no `build`. Diferente de `StatefulWidget`, não tem `setState` — a reconstrução vem da reatividade do Riverpod.
- **`MaterialApp.router`** (e não `MaterialApp`) é a variante que aceita um `routerConfig`. Isso é obrigatório quando você usa `go_router`.
- **Tema claro + escuro** configurados simultaneamente — o sistema escolhe automaticamente com base na preferência do usuário no OS. Definidos em [app_theme.dart](../lib/app/theme/app_theme.dart).
- **`debugShowCheckedModeBanner: false`** esconde a faixa "DEBUG" no canto superior direito durante desenvolvimento, porque o autor prefere demos limpas.

## `app_theme.dart`: Material Design 3

[lib/app/theme/app_theme.dart](../lib/app/theme/app_theme.dart) define dois temas (`light` e `dark`) a partir de uma única **seed color** `Color(0xFF6750A4)` — um roxo Material 3.

```dart
final _seed = const Color(0xFF6750A4);

static ThemeData get light => _build(Brightness.light);
static ThemeData get dark => _build(Brightness.dark);

static ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    cardTheme: CardTheme(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
```

Decisões visuais:

- **Seed único**: `ColorScheme.fromSeed` deriva 30+ cores (primary, onPrimary, secondary, tertiary, surface, etc.) matematicamente a partir dessa única fonte. Garante coerência sem precisar definir manualmente cada token.
- **Botões de 52 px de altura** com radius 16 — tamanho generoso para toque em mobile, radius batendo com os cards.
- **Cards com radius 16** — mesmo valor para manter ritmo visual.
- **AppBar sem elevação** — estilo "flat" do Material 3.

## O roteamento: visão macro

A navegação usa [`go_router` ^14.2.7](../pubspec.yaml), escolha natural porque:

- É o package oficial recomendado pelo time do Flutter.
- Usa URLs como identidade das telas (útil para *deep linking* futuro).
- Tem guards (`redirect`) embutidos.
- Integra bem com Riverpod quando o `GoRouter` é exposto como um provider.

### `app_routes.dart`: constantes de path e name

[lib/app/router/app_routes.dart](../lib/app/router/app_routes.dart) centraliza as strings de rota em uma única classe:

```dart
class AppRoutes {
  static const home = '/';
  static const captureIntro = '/capture/intro';
  static const captureCamera = '/capture/camera';
  static const captureReview = '/capture/review';
  static const processing = '/processing';
  static const viewer = '/viewer';

  // Nomes para `context.goNamed(...)`
  static const homeName = 'home';
  static const captureIntroName = 'captureIntro';
  static const captureCameraName = 'captureCamera';
  static const captureReviewName = 'captureReview';
  static const processingName = 'processing';
  static const viewerName = 'viewer';
}
```

Ter paths e names separados evita *magic strings* em todo lugar — se uma rota mudar, só um arquivo precisa atualizar.

### `app_router.dart`: a árvore de rotas

[lib/app/router/app_router.dart](../lib/app/router/app_router.dart) expõe um provider:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.captureIntro,
        name: AppRoutes.captureIntroName,
        builder: (_, __) => const CaptureIntroPage(),
      ),
      GoRoute(
        path: AppRoutes.captureCamera,
        name: AppRoutes.captureCameraName,
        builder: (_, __) => const CaptureCameraPage(),
      ),
      GoRoute(
        path: AppRoutes.captureReview,
        name: AppRoutes.captureReviewName,
        builder: (_, __) => const CaptureReviewPage(),
        redirect: (context, state) {
          final images = ref.read(captureControllerProvider).images;
          if (images.isEmpty) return AppRoutes.captureCamera;
          return null;
        },
      ),
      GoRoute(
        path: AppRoutes.processing,
        name: AppRoutes.processingName,
        builder: (_, __) => const ProcessingStatusPage(),
      ),
      GoRoute(
        path: AppRoutes.viewer,
        name: AppRoutes.viewerName,
        builder: (_, __) => const Product3dViewerPage(),
        redirect: (context, state) {
          final job = ref.read(processingControllerProvider);
          if (job == null ||
              job.status != ProcessingStatus.completed ||
              job.modelUrl == null) {
            return AppRoutes.processing;
          }
          return null;
        },
      ),
    ],
  );
});
```

### Guards: por que são importantes

Os dois `redirect` protegem contra estados inválidos:

1. **`/capture/review` sem imagens**: se o usuário fechar o app na câmera e depois tentar abrir a revisão (via deep link ou navegação manual), o guard manda de volta para a câmera.
2. **`/viewer` sem modelo pronto**: impede renderizar `ModelViewer` com `modelUrl = null`, o que daria crash no WebView.

Sem guards, essas validações teriam que viver no `build()` de cada página com `if (state.images.isEmpty) return ErrorView(...)`. Os guards centralizam a política: uma rota só é acessível se o estado necessário existir.

### Por que o router é um provider Riverpod

O `GoRouter` é criado dentro de um `Provider` porque os `redirect` precisam chamar `ref.read(captureControllerProvider)` e `ref.read(processingControllerProvider)`. Se o `GoRouter` fosse uma variável global, ele não teria acesso ao `ref`.

Essa integração também significa que o router **só é instanciado uma vez** (a semântica de `Provider`) — redecidir rotas a cada `build` seria desperdício.

## Fluxo completo de navegação

Seguindo a jornada feliz do usuário:

```
┌──────┐  Iniciar     ┌──────────────┐  Continuar  ┌────────────────┐
│ Home │ ───────────▶ │ CaptureIntro │ ──────────▶ │ CaptureCamera  │
└──────┘              └──────────────┘             └────────┬───────┘
                                                            │ Revisar (≥ minImages)
                                                            ▼
┌──────────────────┐  completed    ┌──────────────┐  Enviar ┌────────────────┐
│ Product3dViewer  │ ◀──────────── │  Processing  │ ◀────── │ CaptureReview  │
└────────┬─────────┘               └──────────────┘         └────────────────┘
         │ Concluir
         ▼
      /  (Home)
```

- **Ida**: `context.goNamed(AppRoutes.captureIntroName)` — substitui a rota atual.
- **Voltar**: `context.pop()` — volta uma rota na pilha.
- **Concluir do viewer**: `context.goNamed(AppRoutes.homeName)` — substitui, não empilha, para limpar o histórico.

Todas as navegações estão nos botões das páginas (nunca em controllers de estado) — manter a navegação como responsabilidade da camada de UI simplifica o teste dos controllers.

## Sobre `initialLocation`

O `initialLocation: AppRoutes.home` garante que, mesmo em *hot restart* durante desenvolvimento, o app volta para a home. Sem isso, ao salvar um arquivo o Flutter reconstroi do zero mas tentaria retomar a rota atual — o que, combinado com os guards, poderia jogar o dev para `/capture/camera` vazia e causar confusão.

## Para onde ir agora

- Os utilitários de `core/` que os controllers consomem: [07 — Camada `core/`](07-camada-core.md).
- A feature mais simples, ótima para entender o padrão: [08 — Feature `home`](08-feature-home.md).
- A feature mais complexa, onde o router e os providers se encontram: [09 — Feature `product_capture`](09-feature-product-capture.md).
