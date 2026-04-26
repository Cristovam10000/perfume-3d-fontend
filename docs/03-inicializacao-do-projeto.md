# 03 — Inicialização do projeto

Esta página descreve como o projeto foi criado do zero e o que você precisa fazer para rodá-lo localmente na sua máquina.

## Como o projeto foi gerado

O projeto foi criado pelo comando padrão do Flutter:

```bash
flutter create perfume_3d_mvp
```

A evidência está em [.metadata](../.metadata), que é um arquivo que o `flutter create` gera automaticamente e o CLI do Flutter usa depois para orientar `flutter migrate`:

```yaml
version:
  revision: "db50e20168db8fee486b9abf32fc912de3bc5b6a"
  channel: "stable"

project_type: app
```

A *revision* `db50e20168…` corresponde a **Flutter 3.41.6** do canal **stable** — é a versão do SDK que criou o scaffolding.

No arquivo também lista quais plataformas foram habilitadas na criação:

```yaml
migration:
  platforms:
    - platform: root
    - platform: android
    - platform: ios
    - platform: linux
    - platform: macos
    - platform: web
    - platform: windows
```

Ou seja, **todas as 6 plataformas** foram habilitadas (o `flutter create` faz isso por padrão em versões recentes do SDK). Na prática, o alvo real do TCC é **Android físico** — em particular o **Samsung Galaxy A15 (SM-A155M)** do autor. As demais plataformas existem porque vieram "grátis" no scaffolding e podem facilitar demos em laptop.

A seção `unmanaged_files` do `.metadata` marca dois arquivos que o `flutter migrate` deve **deixar intocados**:

```yaml
unmanaged_files:
  - 'lib/main.dart'
  - 'ios/Runner.xcodeproj/project.pbxproj'
```

Isso preserva o `main.dart` modificado pelo autor (ele não é mais a versão boilerplate) e o projeto Xcode, que pode ter configurações manuais no futuro.

## Pré-requisitos na máquina de desenvolvimento

- **Flutter SDK ≥ 3.19.0** no canal stable.
- **Dart SDK ≥ 3.3.0 < 4.0.0** (vem junto do Flutter).
- Para Android: **Android Studio** (ou só as Command Line Tools) + um AVD ou dispositivo físico com depuração USB.
- Para iOS: **Xcode** (rodando em macOS).
- Para Windows: Visual Studio com o workload "Desktop development with C++".

Verifique com:

```bash
flutter doctor
```

Todos os componentes marcados como OK devem cobrir a(s) plataforma(s) que você pretende rodar.

## Passos para clonar e rodar

```bash
git clone https://github.com/Cristovam10000/TCC.git perfume_3d_mvp
cd perfume_3d_mvp
flutter pub get
```

O `flutter pub get` baixa todas as dependências listadas em [pubspec.yaml](../pubspec.yaml) e gera o `.dart_tool/` + o `.flutter-plugins-dependencies`.

## Configurar o endereço do backend

Antes de rodar, você provavelmente precisa ajustar o endereço do backend. Abra [lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart):

```dart
static const String backendBaseUrl = 'http://10.0.2.2:8000';
```

O padrão `http://10.0.2.2:8000` é o endereço mágico que o **emulador Android** usa para chegar ao `localhost:8000` da máquina hospedeira. Se você rodar em:

- **Emulador Android**: deixe como está.
- **Dispositivo Android físico** na mesma rede Wi-Fi: troque para o IP da sua máquina, por exemplo `http://192.168.0.42:8000`.
- **iOS simulator**: troque para `http://localhost:8000`.
- **Dispositivo iOS físico**: IP da sua máquina (igual ao caso do Android físico).

O backend que o app espera não está neste repositório — é um serviço Python separado documentado em [16 — Contrato do backend](16-contrato-backend.md).

## Rodar o app

### Android (emulador ou físico)

```bash
flutter run
```

Se tiver mais de um dispositivo conectado:

```bash
flutter devices       # lista tudo
flutter run -d <id>   # escolhe um
```

Para debug (hot reload, DevTools, etc.), use `flutter run` sem flags. Para release:

```bash
flutter run --release
```

### iOS (apenas macOS)

```bash
cd ios && pod install && cd ..
flutter run
```

### Windows / macOS / Linux desktop

```bash
flutter run -d windows    # ou macos / linux
```

Note que no desktop a câmera e o ORB podem não entregar a mesma experiência do mobile.

## Rodar a análise estática

```bash
flutter analyze
```

Deve terminar com `No issues found!`. As regras estão em [analysis_options.yaml](../analysis_options.yaml).

## Rodar os testes

```bash
flutter test
```

No estado atual o diretório [test/](../test/) está **vazio** — o `widget_test.dart` boilerplate gerado pelo `flutter create` foi removido no commit `63f2d07`, porque testava um app contador que não é o deste projeto. Escrever testes é um dos passos naturais de evolução.

## Sobre os logs `flutter_*.log` na raiz

Você verá estes arquivos no repositório:

```
flutter_01.log
flutter_02.log
flutter_03.log
flutter_04.log
flutter_05.log
```

São capturas de saídas de `flutter run` **na máquina Windows do autor**, nas quais o Dart AOT runtime (`dartaotruntime.exe`) foi **bloqueado pela política de AppControl do Windows**. Ou seja, não é bug do código — é uma política de segurança local que impede a execução do compilador Dart. Se você estiver em outra máquina (Linux, macOS, ou um Windows sem AppControl), não deve encontrar esse problema.

Eles não deveriam estar versionados em repositório (são artefatos de desenvolvimento), mas foram incluídos no `first commit` e podem ser limpos em uma faxina futura.

## Próxima leitura

- Entender como cada pasta dentro de `lib/` se organiza: [04 — Estrutura de pastas](04-estrutura-de-pastas.md).
- Configurações específicas de cada plataforma (Android Gradle, iOS Info.plist, permissões): [15 — Configuração de plataformas](15-configuracao-de-plataformas.md).
