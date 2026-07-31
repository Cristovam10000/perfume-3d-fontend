# 02 - Stack tecnologico

A fonte canonica das dependencias e [pubspec.yaml](../pubspec.yaml).

## SDK

```yaml
environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.19.0"
```

O projeto usa Flutter com Material 3 e Dart 3. As plataformas geradas pelo `flutter create` continuam presentes: Android, iOS, Web, Windows, Linux e macOS.

## Dependencias diretas

### Flutter e icones

- `flutter`: framework principal.
- `cupertino_icons: ^1.0.8`: dependencia padrao do template; o app atual usa majoritariamente `Icons.*` do Material.

### Estado e navegacao

- `flutter_riverpod: ^2.5.1`: providers de repositorio, controllers e router.
- `go_router: ^14.2.7`: rotas nomeadas, parametros de path e guards via `redirect`.

Locais principais:

- [lib/main.dart](../lib/main.dart) cria o `ProviderScope`.
- [lib/app/app.dart](../lib/app/app.dart) observa `appRouterProvider`.
- [lib/app/router/app_router.dart](../lib/app/router/app_router.dart) define a arvore de rotas.

### Rede

- `dio: ^5.7.0`: cliente HTTP para upload multipart e polling de status.

O `Dio` fica em [core/network/dio_client.dart](../lib/core/network/dio_client.dart), com:

- `baseUrl` vindo de `AppConstants.backendBaseUrl`;
- timeout de conexao de 15 segundos;
- timeout de envio de 5 minutos;
- `LogInterceptor` apenas em debug via `assert`.

### Captura e midia

- `camera: ^0.11.0+2`: preview, `CameraController`, `startImageStream` e `takePicture`.
- `image_picker: ^1.1.2`: selecao de imagens da galeria e fallback de captura nativa.
- `path_provider: ^2.1.4`: declarado para compatibilidade com plugins, embora nao seja chamado diretamente no Dart atual.

### Sensores e visao computacional

- `sensors_plus: ^6.0.1`: o app usa `accelerometerEventStream()` para estimar inclinacao.
- `opencv_dart: ^1.3.0`: ORB, descritores, `BFMatcher`, `knnMatch` e norma de Hamming.

O uso de OpenCV esta concentrado em [orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart).

### Visualizacao 3D

- `model_viewer_plus: ^1.8.0`: renderiza arquivos `.glb`/`.gltf` via `<model-viewer>` dentro de WebView.

Ha dois usos:

- [Product3DPage](../lib/features/sales/presentation/pages/product_3d_page.dart), para o GLB vinculado ao produto no banco.
- [Product3DViewerPage](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart), para o modelo retornado pelo backend de captura.

### Localizacao, formatacao e fontes

- `intl: ^0.20.2`: moeda e datas em pt-BR. O `main()` inicializa `Intl.defaultLocale = 'pt_BR'` e `initializeDateFormatting('pt_BR')`.
- `flutter_localizations` (SDK): traducoes dos componentes do Material. `PerfumeApp` registra os delegates globais e fixa `locale`/`supportedLocales` em `pt_BR`, o que deixa o date picker em portugues.
- `google_fonts: ^8.0.2`: tema usa `GoogleFonts.plusJakartaSansTextTheme`.

Formatadores ficam em [core/utils/app_formatters.dart](../lib/core/utils/app_formatters.dart).

## Dependencias de desenvolvimento

- `flutter_lints: ^4.0.0`: regras padrao de lint.
- `flutter_test`: testes de widget.

O projeto tem teste ativo em [test/sale_wizard_test.dart](../test/sale_wizard_test.dart), cobrindo:

- abertura do catalogo de produtos;
- selecao de produto e quantidade;
- navegacao do botao voltar no wizard;
- confirmacao de venda e detalhe com parcelas/itens.

## Regras de lint

[analysis_options.yaml](../analysis_options.yaml) inclui:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    use_key_in_widget_constructors: true
```

## Assets

O `pubspec.yaml` declara apenas:

```yaml
flutter:
  uses-material-design: true
```

Nao ha assets proprios versionados para imagens, modelos 3D, fontes ou JSON. Os cards de produto desenham uma arte simples em Flutter, e as URLs dos modelos 3D chegam pelo backend.

## Resumo

| Categoria | Pacote | Uso |
|---|---|---|
| Estado | `flutter_riverpod` | Providers, controllers e repositorios. |
| Rotas | `go_router` | Rotas nomeadas, path params, extra e guards. |
| HTTP | `dio` | Upload multipart e status do backend. |
| Camera | `camera` | Preview, stream YUV420 e fotos. |
| Galeria | `image_picker` | Escolha de imagens existentes. |
| Sensores | `sensors_plus` | Acelerometro para tilt. |
| CV | `opencv_dart` | ORB e matching de angulos. |
| 3D | `model_viewer_plus` | Viewer `.glb`/`.gltf`. |
| Datas/moeda | `intl` | Formatacao pt-BR. |
| Fonte | `google_fonts` | Plus Jakarta Sans no tema. |
| Testes | `flutter_test` | Widget tests do wizard de venda. |

## Proxima leitura

- Como rodar: [03 - Inicializacao do projeto](03-inicializacao-do-projeto.md).
- Arquitetura e providers: [05 - Arquitetura](05-arquitetura.md).
