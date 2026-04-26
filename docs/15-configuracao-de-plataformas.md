# 15 - Configuracao de plataformas

O projeto foi criado com suporte Flutter padrao para Android, iOS, Web, Windows, Linux e macOS. O alvo mais realista para a captura e Android fisico.

## Android

### Gradle

[android/app/build.gradle.kts](../android/app/build.gradle.kts) usa configuracao padrao do Flutter:

- `namespace = "com.example.perfume_3d_mvp"`;
- `applicationId = "com.example.perfume_3d_mvp"`;
- `compileSdk = flutter.compileSdkVersion`;
- `minSdk = flutter.minSdkVersion`;
- Java/Kotlin 17;
- release assinado com debug key enquanto nao ha assinatura real.

### Manifest

[android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) esta praticamente no template.

Atencao: no estado atual, o manifest principal nao declara explicitamente:

- `android.permission.INTERNET`;
- `android.permission.CAMERA`;
- permissoes de midia/galeria para versoes antigas do Android.

Os manifests de debug/profile tem `INTERNET`, mas isso nao cobre release.

Antes de release ou demo em aparelho fisico com captura/backend, revise:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

Para galeria, a necessidade varia por versao do Android e estrategia do `image_picker`/Photo Picker. Teste em Android 13+ e Android mais antigo.

## iOS

[ios/Runner/Info.plist](../ios/Runner/Info.plist) esta no estado padrao do Flutter e ainda nao declara textos de privacidade para camera/galeria.

Para usar captura no iOS, adicione antes de rodar em device:

```xml
<key>NSCameraUsageDescription</key>
<string>Este app usa a camera para capturar fotos do perfume.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Este app acessa a galeria para selecionar fotos do perfume.</string>
```

Sem essas chaves, o iOS bloqueia o acesso e pode encerrar o app.

## Web

A pasta [web/](../web/) continua com template padrao.

O modulo comercial tende a rodar bem em Web. O pipeline de captura depende de:

- suporte do plugin `camera` no navegador;
- permissao de camera via browser;
- comportamento do OpenCV/WebAssembly/FFI conforme suporte do pacote.

Para demo web, o caminho mais seguro e focar dashboard/catalogo/viewer 3D.

## Desktop

Pastas `windows/`, `linux/` e `macos/` existem por padrao.

O modulo comercial pode ser util em desktop para banca/demo. Captura com camera e OpenCV deve ser validada por plataforma antes de prometer suporte.

## ModelViewer

`model_viewer_plus` depende de WebView ou equivalente da plataforma. Em geral:

- Android: usa WebView do sistema;
- iOS: usa WKWebView;
- Web: renderiza via browser;
- Desktop: suporte depende do plugin e ambiente.

Se um modelo nao aparecer, verifique primeiro:

- URL acessivel pelo device;
- permissao de internet;
- CORS quando rodando no navegador;
- formato `.glb`/`.gltf` valido.

## Checklist antes de demo

- Confirmar `backendBaseUrl` correto para o device.
- Rodar `flutter pub get`.
- Rodar `flutter analyze`.
- Rodar `flutter test`.
- Testar `ProductsPage` e `Product3DPage`.
- Testar wizard de venda.
- Testar camera em aparelho real.
- Verificar permissoes nativas se for Android/iOS.

## Proxima leitura

- Como rodar: [03 - Inicializacao do projeto](03-inicializacao-do-projeto.md).
- Contrato do backend: [16 - Contrato do backend](16-contrato-backend.md).
