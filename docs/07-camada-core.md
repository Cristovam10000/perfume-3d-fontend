# 07 - Camada `core`

`core/` contem infraestrutura e algoritmos compartilhados que nao pertencem a uma unica tela.

## `constants/app_constants.dart`

[app_constants.dart](../lib/core/constants/app_constants.dart) define:

| Constante | Valor atual | Uso |
|---|---:|---|
| `appName` | `Perfume 3D` | Nome logico do app. |
| `backendBaseUrl` | `http://192.168.0.3:8000` | Base URL do backend de captura/processamento. |
| `minImages` | `12` | Minimo recomendado para revisao/upload. |
| `recommendedImages` | `24` | Alvo visual do contador. |
| `maxImages` | `60` | Limite superior de imagens. |
| `processingPollInterval` | `3s` | Intervalo do polling. |

## `errors/app_exception.dart`

Define excecoes simples:

- `AppException`
- `NetworkException`
- `UploadException`
- `ProcessingException`

Os repositorios do pipeline 3D convertem erros de Dio em excecoes de upload/processamento para a camada de UI exibir mensagens mais coerentes.

## `network/dio_client.dart`

[dio_client.dart](../lib/core/network/dio_client.dart) expoe `dioClientProvider`.

Configuracao atual:

- `baseUrl: AppConstants.backendBaseUrl`;
- `connectTimeout: 15s`;
- `receiveTimeout: 30s`;
- `sendTimeout: 5min`;
- `responseType: json`;
- `LogInterceptor` com `print` dentro de `assert`, rodando apenas em debug.

Consumidores:

- `CaptureRepositoryImpl`;
- `ProcessingRepositoryImpl`.

O modulo `sales` nao usa Dio hoje.

## `utils/app_formatters.dart`

Centraliza formatacao pt-BR:

- `AppFormatters.brl(num)` para moeda `R$`;
- `AppFormatters.compactDate(DateTime)` com `dd MMM`;
- `AppFormatters.date(DateTime)` com `dd MMM yyyy`.

Depende da inicializacao feita em `main()`:

```dart
Intl.defaultLocale = 'pt_BR';
await initializeDateFormatting('pt_BR');
```

## `utils/frame_analyzer.dart`

Analisa frames da camera em YUV420:

- brilho medio do plano Y;
- saturacao aproximada;
- nitidez por variancia do Laplaciano amostrado.

Ele trabalha com subamostragem (`_step = 8`) para nao travar o preview.

Resultado:

```dart
class FrameQuality {
  final double brightness;
  final double sharpness;
  final double saturatedRatio;
}
```

## `utils/tilt_tracker.dart`

Recebe acelerometro `(x, y, z)` e estima pitch:

```dart
atan2(z, sqrt(x*x + y*y)) * 180 / pi
```

Aplica suavizacao exponencial:

```dart
_pitchDegrees = _pitchDegrees * 0.85 + p * 0.15;
```

Uso:

- avisar quando o celular esta apontando para cima/baixo;
- participar de `readyToCapture` no `LiveCaptureController`.

## `utils/orb_similarity_tracker.dart`

Compara o frame atual contra fotos ja capturadas.

Pipeline:

1. converte o plano Y do `CameraImage` para `cv.Mat`;
2. reduz largura para `targetWidth = 480`, se necessario;
3. extrai descritores ORB;
4. compara com descritores de capturas anteriores usando `BFMatcher` com `NORM_HAMMING`;
5. aplica `knnMatch(k=2)` e Lowe ratio test (`ratioThreshold = 0.75`);
6. classifica pelo maior numero de matches bons.

Vereditos:

| Veredito | Condicao |
|---|---|
| `noReference` | nenhuma captura registrada. |
| `newAngle` | menos de `partialThreshold` matches. |
| `partialOverlap` | entre `partialThreshold` e `duplicateThreshold`. |
| `duplicate` | pelo menos `duplicateThreshold` matches. |

Valores atuais:

- `nFeatures = 500`;
- `duplicateThreshold = 90`;
- `partialThreshold = 40`;
- `targetWidth = 480`.

Importante: o tracker guarda `cv.Mat` em memoria nativa. Por isso `LiveCaptureController.dispose()` precisa chamar `_similarity.dispose()`.

## `utils/image_quality_analyzer.dart`

Este utilitario nao analisa pixels. Ele produz mensagens de orientacao a partir da quantidade de imagens capturadas:

- `0`: incentive a primeira captura;
- abaixo de `minImages`: avisa quantas faltam;
- abaixo de `recommendedImages`: cobertura boa, mas pode melhorar;
- acima do recomendado: cobertura excelente.

As mensagens usam:

```dart
enum QualityLevel { ok, warning, blocker }
```

O feedback pixel-a-pixel fica no `FrameAnalyzer` e no `LiveCaptureController`.

## Proxima leitura

- Captura em tempo real: [09 - Feature `product_capture`](09-feature-product-capture.md).
- Widgets que exibem mensagens de qualidade: [12 - Widgets compartilhados](12-widgets-compartilhados.md).
