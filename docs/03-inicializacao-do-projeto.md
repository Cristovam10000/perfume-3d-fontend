# 03 - Inicializacao do projeto

## Pre-requisitos

- Flutter instalado e no `PATH`.
- Android Studio ou SDK Android configurado, caso rode em Android.
- Um backend local opcional, necessario apenas para o fluxo de captura/processamento.
- Acesso a internet para baixar dependencias e, em tempo de desenvolvimento, fontes/modelos remotos quando usados.

## Instalar dependencias

Na raiz do front:

```powershell
cd C:\TCC\front
flutter pub get
```

## Inicializacao do app

[lib/main.dart](../lib/main.dart) faz mais do que o template inicial:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const ProviderScope(child: PerfumeApp()));
}
```

Isso garante que `AppFormatters` consiga formatar datas e moeda em pt-BR antes da primeira tela.

## Configurar backend

O endereco atual esta em [app_constants.dart](../lib/core/constants/app_constants.dart):

```dart
static const String backendBaseUrl = 'http://192.168.0.3:8000';
```

Use:

- `10.0.2.2` para Android Emulator acessando backend na maquina host;
- o IP da maquina na rede local para aparelho fisico;
- `localhost` somente quando o app e o backend rodam no mesmo ambiente que resolve esse host.

O modulo `sales` roda com dados mockados e nao depende desse backend. O backend e necessario para:

- `POST /captures`;
- `GET /captures/{jobId}/status`;
- URLs de modelo usadas por `ModelViewer`, se apontarem para o servidor local.

## Rodar

```powershell
flutter run
```

Exemplos uteis:

```powershell
flutter run -d chrome
flutter run -d windows
flutter devices
```

Para Android fisico, habilite depuracao USB e confirme que o aparelho aparece em `flutter devices`.

## Analise estatica

```powershell
flutter analyze
```

## Testes

```powershell
flutter test
```

O teste atual esta em [test/sale_wizard_test.dart](../test/sale_wizard_test.dart). Ele inicializa locale pt-BR e desabilita busca runtime de Google Fonts para deixar o teste deterministico.

## Logs `flutter_*.log`

Os arquivos `flutter_01.log` a `flutter_05.log` sao registros antigos de tentativas de execucao na maquina Windows do autor. Eles indicam bloqueio local do `dartaotruntime.exe` por politica de AppControl, nao uma falha de codigo do app.

Se isso acontecer em outra maquina Windows, resolva a politica de seguranca local ou rode em ambiente sem esse bloqueio.

## Proxima leitura

- Estrutura atual de arquivos: [04 - Estrutura de pastas](04-estrutura-de-pastas.md).
- Rotas e bootstrap: [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
