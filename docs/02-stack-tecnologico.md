# 02 — Stack tecnológico

Este documento percorre **toda a stack** do aplicativo: cada dependência declarada, o motivo da escolha, e onde no código ela é usada. A fonte canônica é [pubspec.yaml](../pubspec.yaml).

## Versões de SDK

Restrições declaradas em [pubspec.yaml:6-8](../pubspec.yaml):

```yaml
environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.19.0"
```

- **Dart ≥ 3.3.0** (antes de Dart 4.x): aproveita `records`, `patterns`, `class modifiers`, `sealed classes` — todas usadas pontualmente ou disponíveis para uso futuro.
- **Flutter ≥ 3.19.0**: versão que introduziu `Material 3` como padrão e estabilizou APIs importantes usadas aqui (ex.: `surfaceContainerHighest` no esquema de cores).

O arquivo [.metadata](../.metadata) registra que o projeto foi criado com Flutter revision `db50e20168db8fee486b9abf32fc912de3bc5b6a` do canal **stable**. Isso corresponde, na prática, ao Flutter **3.41.6** com Dart **3.11.4**, conforme aparece nos logs `flutter_*.log` da raiz do repositório.

## Dependências diretas

Todas são puxadas via `pub.dev`. A lista abaixo segue a ordem em que aparecem no `pubspec.yaml`.

### Ícones e Flutter core

#### `flutter` (SDK)

O framework em si. Nada a dizer — vem do SDK.

#### `cupertino_icons: ^1.0.8`

Biblioteca de ícones no estilo iOS. Não é usada ativamente — é o default do `flutter create` e foi mantida por não atrapalhar. O app usa exclusivamente ícones Material (`Icons.*`).

### Gerência de estado

#### `flutter_riverpod: ^2.5.1`

Sistema reativo de estado + injeção de dependências. **Escolhido** em vez de `Provider` puro, `Bloc` ou `GetX` porque:

- Oferece `Provider`, `StateNotifierProvider` e `autoDispose` numa única API coesa.
- Não depende de `BuildContext` para acessar estado — os controllers leem outros providers via `Ref`, sem amarração ao widget tree.
- Tem excelente suporte a testes: basta sobrescrever um provider em um `ProviderScope` de teste.

Locais onde aparece:

- [lib/main.dart](../lib/main.dart): raiz do app envolvida em `ProviderScope`.
- [lib/app/app.dart](../lib/app/app.dart): `PerfumeApp extends ConsumerWidget`.
- Todos os controllers do projeto estendem `StateNotifier<T>` e são expostos via `StateNotifierProvider`.
- [app_router.dart:14](../lib/app/router/app_router.dart) expõe o próprio `GoRouter` via `Provider`, de forma que guards possam ler outros providers (`ref.read(captureControllerProvider)` etc).

O app tem **9 providers**. A lista completa está em [05 — Arquitetura](05-arquitetura.md#grafo-de-providers).

### Navegação

#### `go_router: ^14.2.7`

Roteador declarativo recomendado pelo time do Flutter. **Escolhido** em vez de `Navigator 1.0` porque:

- Rotas são nomeadas (`context.goNamed(AppRoutes.homeName)`), eliminando strings mágicas espalhadas.
- Suporta `redirect` por rota, o que é usado para *guards* (ex.: não deixar entrar em `/capture/review` sem imagens).
- Integra com Riverpod via `ref` capturado no `Provider<GoRouter>`.

Local principal: [lib/app/router/app_router.dart](../lib/app/router/app_router.dart) (definição de rotas e guards) e [lib/app/router/app_routes.dart](../lib/app/router/app_routes.dart) (constantes de path e name).

### Rede

#### `dio: ^5.7.0`

Cliente HTTP. **Escolhido** em vez do pacote `http` padrão porque:

- Tem `onSendProgress` nativo, essencial para a barra de progresso do upload multipart.
- Permite interceptors (o projeto adiciona um `LogInterceptor` apenas em debug — ver [dio_client.dart:17-30](../lib/core/network/dio_client.dart)).
- Tem timeouts separados para *connect* / *receive* / *send*, permitindo dar 5 minutos para o upload grande e só 15s para conectar.
- Erros vêm com tipo (`DioException.type`), facilitando mensagens amigáveis.

Configuração: [lib/core/network/dio_client.dart](../lib/core/network/dio_client.dart). Consumido por [capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) e [processing_repository.dart](../lib/features/processing/data/processing_repository.dart).

### Captura de mídia

#### `camera: ^0.11.0+2`

Plugin oficial para acesso à câmera. **Escolhido** em vez de `image_picker` puro (que também existe no projeto como fallback — veja abaixo) porque:

- Permite `startImageStream()` entregando cada frame como `CameraImage`, o que é **essencial** para o feedback em tempo real. A feature de captura não funcionaria sem isso.
- Dá controle sobre `ResolutionPreset` e `ImageFormatGroup`. O app força `ImageFormatGroup.yuv420` — ver [capture_camera_page.dart:75](../lib/features/product_capture/presentation/pages/capture_camera_page.dart) — porque o ORB trabalha sobre o plano Y (luminância) do YUV420, evitando conversão de cor que mataria a performance.

Usado em [capture_camera_page.dart](../lib/features/product_capture/presentation/pages/capture_camera_page.dart). O ciclo de vida do `CameraController` é gerenciado ali (init, stream start/stop, dispose, reação a `didChangeAppLifecycleState`).

#### `image_picker: ^1.1.2`

Plugin para abrir a galeria ou a câmera nativa do sistema. **Complementar** ao `camera`: é usado no fluxo de fallback quando o usuário clica em "Galeria" e quer escolher fotos já existentes em vez de tirar novas.

Usado em [capture_controller.dart:17](../lib/features/product_capture/presentation/state/capture_controller.dart) e no método `pickFromGallery()`.

#### `path_provider: ^2.1.4`

Resolve caminhos de diretórios do sistema operacional (documents, cache, temp). Está no `pubspec` mas **não aparece diretamente no código Dart do projeto** — é puxado como dependência transitiva de outros plugins (`camera`, `image_picker` etc.) e declarado explicitamente para garantir versão compatível.

### Sensores

#### `sensors_plus: ^6.0.1`

Acesso a acelerômetro, giroscópio e magnetômetro. **Escolhido** porque é o pacote mantido oficialmente sob a organização *Flutter Community* e cobre todas as plataformas.

O app usa **apenas o acelerômetro** hoje, via `accelerometerEventStream()`. A assinatura é em [live_capture_controller.dart:54](../lib/features/product_capture/presentation/state/live_capture_controller.dart), e o consumo está em [tilt_tracker.dart](../lib/core/utils/tilt_tracker.dart), onde o vetor `(x, y, z)` vira um ângulo de inclinação vertical (pitch).

Historicamente o app também usava giroscópio (no paradigma "walk-around" antigo), mas isso foi removido no commit `63f2d07` — veja [14 — Histórico](14-historico-de-mudancas.md).

### Visão computacional

#### `opencv_dart: ^1.3.0`

Bindings Dart/FFI para o OpenCV 4. **Escolhido** porque:

- É o único pacote que entrega `ORB + BFMatcher + knnMatch` de forma nativa e eficiente no Flutter.
- Vem com binários nativos compilados para Android, iOS, Linux, macOS e Windows — sem precisar compilar OpenCV no ambiente de build do dev.
- Puxa como dependência transitiva o pacote `dartcv4` (que é quem de fato oferece as classes `cv.Mat`, `cv.ORB`, `cv.BFMatcher`). Você verá `import 'package:opencv_dart/opencv_dart.dart' as cv;` e o prefixo `cv.` em todos os usos.

Usado **exclusivamente** em [lib/core/utils/orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart) — o detector ORB extrai ~500 *keypoints* por frame, o `BFMatcher` (norma de Hamming) compara os descritores de 32 bytes, e o *Lowe's ratio test* filtra *matches* ambíguos. Os limiares de decisão (`duplicateThreshold = 90`, `partialThreshold = 40`) foram calibrados manualmente para objetos simétricos/reflexivos como frascos de perfume. Explicação profunda em [07 — Camada core](07-camada-core.md#orb_similarity_trackerdart).

**Nota sobre impacto**: esse pacote adiciona uns **30-50 MB** ao tamanho do APK por causa das libs nativas do OpenCV. Para um MVP acadêmico é aceitável; para produção, avaliar se compensa.

### Visualização 3D

#### `model_viewer_plus: ^1.8.0`

Widget que embrulha a biblioteca JavaScript `<model-viewer>` do Google dentro de uma `WebView`. **Escolhido** porque:

- É o único pacote maduro em Flutter para renderizar `.glb`/`.gltf` (formatos de saída mais comuns em pipelines de fotogrametria).
- Suporta os controles de câmera (rotação, zoom, pan, auto-rotate) que o app precisa "de graça".
- Não exige integração com Unity/Unreal nem escrever OpenGL ES manualmente.

Custo: usa WebView internamente, então carrega um Chromium embutido (Android) ou WKWebView (iOS). Isso funciona bem para o caso de uso, mas pesa um pouco na primeira abertura.

Usado em [product_3d_viewer_page.dart:41-49](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart) com `autoRotate: true`, `cameraControls: true`, `disableZoom: false`, `ar: false` (AR está fora do escopo do MVP).

## Dependências de desenvolvimento

### `flutter_lints: ^4.0.0`

Conjunto de regras de *lint* padrão do time do Flutter, importadas via [analysis_options.yaml:1](../analysis_options.yaml):

```yaml
include: package:flutter_lints/flutter.yaml
```

Esse conjunto aplica dezenas de regras de qualidade (uso de `const`, ordenação de imports, etc).

### `flutter_test` (SDK)

Framework de teste nativo do Flutter. Disponível no projeto mas **não utilizado no estado atual**: o diretório [test/](../test/) está vazio (o `widget_test.dart` boilerplate foi removido no commit `63f2d07`).

### Regras adicionais em `analysis_options.yaml`

Além do preset do `flutter_lints`, o projeto ativa explicitamente:

```yaml
linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    use_key_in_widget_constructors: true
```

- `prefer_const_constructors` e `prefer_const_literals_to_create_immutables` mantêm widgets imutáveis e reutilizáveis pelo *widget tree diffing* (ganho de performance).
- `avoid_print` força o uso de `debugPrint` ou um logger estruturado, evitando `print` acidental em produção. Note que o `LogInterceptor` do Dio em [dio_client.dart:25](../lib/core/network/dio_client.dart) contorna isso com um `assert(() { ... }())` que roda o `print` só em debug builds.
- `use_key_in_widget_constructors` obriga todo widget customizado a aceitar `{Key? key}` — importante para *keyed reconciliation* em listas.

## Dependências transitivas notáveis

Pinadas em [pubspec.lock](../pubspec.lock). Vale mencionar, porque têm **impacto no build e no tamanho do app**:

- **`dartcv4`**: puxado por `opencv_dart`; contém as classes `cv.Mat`, `cv.ORB`, `cv.BFMatcher`, `cv.IMREAD_GRAYSCALE`, `cv.NORM_HAMMING` usadas em [orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart).
- **`camera_android_camerax`**: implementação Android do plugin `camera` baseada na API CameraX (mais moderna que a Camera2 legada).
- **`camera_avfoundation`**: implementação iOS baseada em AVFoundation.
- **`camera_web`**: implementação Web via `getUserMedia()` do WebRTC. Existe só porque a plataforma web está habilitada pelo `flutter create`; não é um alvo real.
- **`jni`** / **`jni_flutter`**: bridges FFI para interop com Java/Kotlin no Android (usados transitivamente por `path_provider` e `sensors_plus`).
- **`webview_flutter_*`**: suporte a WebView em cada plataforma — requisito do `model_viewer_plus`.

## Assets

Declarações de assets em [pubspec.yaml:44-46](../pubspec.yaml):

```yaml
flutter:
  uses-material-design: true
```

Apenas a fonte de ícones Material Design é habilitada. **Não há assets próprios** do projeto (imagens, fontes customizadas, dados JSON). Isso simplifica bastante o bundle; todos os elementos visuais são widgets Flutter + ícones Material + as imagens capturadas pelo próprio usuário em tempo de execução.

## Resumo da escolha de stack

| Categoria | Pacote | Por quê específico |
|---|---|---|
| *State management* | `flutter_riverpod` | `Ref` fora de `BuildContext`, *auto-dispose*, ótimo para testar |
| Navegação | `go_router` | Rotas nomeadas + `redirect` para guards |
| HTTP | `dio` | `onSendProgress` para upload, timeouts separados, interceptors |
| Câmera | `camera` | `startImageStream` entrega frames YUV420 para ORB |
| Galeria (fallback) | `image_picker` | Cross-platform, poucas linhas de código |
| Sensores | `sensors_plus` | Acelerômetro cross-platform |
| CV | `opencv_dart` (+ `dartcv4`) | Única opção pronta com ORB+BFMatcher no Flutter |
| 3D | `model_viewer_plus` | `.glb`/`.gltf` com controles prontos via WebView |
| Ícones | `cupertino_icons` | Default do `flutter create`, não atrapalha |
| Lint | `flutter_lints` + regras extras | Qualidade sem esforço |

## Próxima leitura

- Como o projeto foi inicializado e como rodá-lo localmente: [03 — Inicialização do projeto](03-inicializacao-do-projeto.md).
- Configuração de cada plataforma (permissões, Gradle, Info.plist): [15 — Configuração de plataformas](15-configuracao-de-plataformas.md).
