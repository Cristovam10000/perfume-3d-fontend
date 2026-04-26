# 15 — Configuração de plataformas

Flutter compila o mesmo código Dart para 6 plataformas diferentes, mas cada uma tem sua **camada nativa** com configurações próprias (permissões, bundle ID, versões de SDK, ícones). Esta página cobre o que existe hoje em cada pasta de plataforma e quais ajustes são necessários antes de um release real.

## Android

### `android/app/build.gradle.kts`

O [build.gradle.kts](../android/app/build.gradle.kts) do módulo do app é escrito em Kotlin DSL (`.kts`) — a forma moderna no ecossistema Android. Principais configurações:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.perfume_3d_mvp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.perfume_3d_mvp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
```

Observações:

- **`namespace` e `applicationId`**: `com.example.perfume_3d_mvp` — o default do `flutter create`. Para publicar na Play Store, precisa mudar para algo como `com.cristovam.perfume_3d`.
- **SDK versions delegadas ao Flutter**: `flutter.compileSdkVersion`, `flutter.minSdkVersion` etc. Isso significa que o app sempre acompanha o SDK padrão do canal do Flutter em uso — hoje compileSdk 34, minSdk 21.
- **Java / Kotlin 17**: necessário para dependências modernas do AndroidX e para as configurações padrão do Flutter SDK atual.
- **Release assinado com debug key** ⚠️: `signingConfig = signingConfigs.getByName("debug")`. É o default gerado pelo `flutter create`, **mas não serve para publicação**. Precisa criar uma keystore e configurar `signingConfigs.release` antes de um release real.

### Permissões

O `AndroidManifest.xml` (em `android/app/src/main/`) precisa declarar:

- `<uses-permission android:name="android.permission.CAMERA" />` — obrigatório para `startImageStream`.
- `<uses-feature android:name="android.hardware.camera.any" android:required="true" />` — sinaliza que o app depende de câmera (sem isso, a Play Store permitiria instalar em devices sem câmera).

O plugin `camera ^0.11.0+2` injeta essas permissões automaticamente via manifest merging, mas vale confirmar após o pivot para garantir que estão no `AndroidManifest.xml` final (pode inspecionar em `build/app/outputs/`).

Sensores (acelerômetro) **não requerem permissão** no Android — são considerados "sensores de baixo risco" pelo Android.

## iOS

### `ios/Runner/Info.plist`

O [Info.plist](../ios/Runner/Info.plist) contém, entre outras coisas:

- `CFBundleIdentifier` — placeholder hoje. Precisa ser ajustado para um identificador único registrado na Apple Developer.
- `CFBundleDisplayName` — "perfume_3d_mvp" (pode ser melhorado para "Perfume 3D").
- `UISupportedInterfaceOrientations` — portrait + landscape. Isso é herdado do default do `flutter create`; na prática o app funciona melhor só em portrait, mas landscape não quebra nada.

### Permissões iOS ⚠️

**Ausentes hoje**, precisam ser adicionadas antes de um release:

- `NSCameraUsageDescription` — texto exibido no diálogo de permissão de câmera ("Este app usa a câmera para capturar fotos do perfume").
- `NSMotionUsageDescription` — para acesso ao acelerômetro via `sensors_plus`.
- `NSPhotoLibraryUsageDescription` — para o fallback de galeria via `image_picker`.

Sem essas entradas, o app **crasha** na primeira tentativa de abrir câmera/sensores no iOS. O `flutter create` não adiciona por default porque não sabe quais sensores o app quer usar.

### CocoaPods

`cd ios && pod install` baixa as dependências nativas dos plugins (camera, path_provider, image_picker, sensors_plus). O `pubspec.yaml` mantém a lista; o CocoaPods traduz para frameworks Xcode.

## Web

A pasta `web/` existe porque `flutter create` habilitou todas as plataformas. Funciona parcialmente:

- **`ModelViewer` funciona nativamente** — o `<model-viewer>` do Google foi criado para web, então esta é a plataforma de melhor suporte para a viewer.
- **`camera` e `image_picker` funcionam com limitações** — usam `navigator.mediaDevices.getUserMedia`, só em HTTPS.
- **`opencv_dart` NÃO funciona** — depende de código nativo C++ que não compila para WASM. Live feedback não existe na web.
- **`sensors_plus` funciona em dispositivos móveis via Safari/Chrome**, não em desktop.

Conclusão prática: a web serve só como demo parcial. Para um demo completo, Android físico é o alvo.

## Windows / macOS / Linux (desktop)

As pastas `windows/`, `macos/`, `linux/` também existem. Status:

- **`ModelViewer`** — funciona via WebView embedded (Edge WebView2 no Windows, WKWebView no macOS).
- **`camera`** — funciona em Windows com [camera_windows](https://pub.dev/packages/camera_windows), pode ter quirks em macOS.
- **`opencv_dart`** — compila via FFI; funciona em teoria, pouco testado nesse projeto.
- **`sensors_plus`** — **não funciona em desktop**: laptops geralmente não têm acelerômetro acessível.

Para o TCC, desktop é secundário — uma demo de viewer apenas, sem o fluxo de captura.

## `.flutter-plugins-dependencies`

Arquivo gerado em [.flutter-plugins-dependencies](../.flutter-plugins-dependencies) pelo `flutter pub get`. Lista todos os plugins nativos e em quais plataformas foram configurados. Você não precisa editar esse arquivo — é regenerado automaticamente. Mas é útil para debugar problemas de integração (por exemplo, "por que `camera` não está sendo empacotado no iOS?").

## `.metadata`

[.metadata](../.metadata) guarda a *revision* do Flutter SDK que criou o scaffolding, as plataformas habilitadas e a lista de arquivos `unmanaged_files` — todos detalhes já cobertos em [03 — Inicialização do projeto](03-inicializacao-do-projeto.md).

## Checklist para release em produção

Se um dia este projeto for publicado, estes são os itens críticos:

### Android

- [ ] Trocar `applicationId` para algo não-`com.example.*`.
- [ ] Criar keystore de release e configurar `signingConfigs.release` no `build.gradle.kts`.
- [ ] Ajustar `versionCode` e `versionName`.
- [ ] Testar em `--release` (não só `--debug`).
- [ ] Confirmar permissão de câmera no AndroidManifest final.

### iOS

- [ ] Trocar `CFBundleIdentifier` para um ID registrado na Apple Developer.
- [ ] Adicionar `NSCameraUsageDescription`, `NSMotionUsageDescription`, `NSPhotoLibraryUsageDescription` ao Info.plist.
- [ ] Configurar time de desenvolvimento e perfil de provisioning no Xcode.
- [ ] Rodar `pod install` após cada mudança em plugins.

### Geral

- [ ] Trocar `AppConstants.backendBaseUrl` do `10.0.2.2` de emulador para o host de produção.
- [ ] Habilitar HTTPS no backend (iOS e Android modernos bloqueiam HTTP por default via App Transport Security / Network Security Config).
- [ ] Remover o `LogInterceptor` do Dio em release (já está dentro de `assert`, então tecnicamente já é removido — mas confirmar no APK/IPA final).

## Para onde ir agora

- A feature de captura que depende de permissões nativas: [09 — Feature `product_capture`](09-feature-product-capture.md).
- O contrato do backend, cujo URL precisa ser ajustado para produção: [16 — Contrato do backend](16-contrato-backend.md).
