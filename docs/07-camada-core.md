# 07 — Camada `core/`

A pasta [lib/core/](../lib/core/) reúne **infraestrutura transversal**: coisas que não pertencem a nenhuma feature específica, mas que várias features precisam. Nenhum arquivo em `core/` importa Flutter widgets — são puramente código Dart que roda igual em qualquer target.

Quatro subpastas:

- `constants/` — valores mágicos centralizados.
- `errors/` — hierarquia de exceptions do app.
- `network/` — configuração do cliente HTTP.
- `utils/` — algoritmos de análise de imagem e sensores.

## `core/constants/app_constants.dart`

[lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart) é uma classe estática com todas as "constantes mágicas" do app:

```dart
class AppConstants {
  static const String backendBaseUrl = 'http://10.0.2.2:8000';

  static const int minImages = 12;
  static const int recommendedImages = 24;
  static const int maxImages = 60;

  static const Duration processingPollInterval = Duration(seconds: 3);

  // ... outras constantes ...
}
```

| Constante | Efeito no app |
|---|---|
| `backendBaseUrl` | Endpoint raiz que o `Dio` usa. `10.0.2.2` é o alias do emulador Android para `localhost` do host. |
| `minImages` (12) | Abaixo disso a `ImageQualityAnalyzer` retorna `QualityLevel.insufficient`. O botão "Enviar" fica desabilitado. |
| `recommendedImages` (24) | Acima disso o analyzer retorna `QualityLevel.good`. Abaixo, `QualityLevel.acceptable`. |
| `maxImages` (60) | Limite superior — acima disso a câmera desabilita o botão de capturar. Evita upload exagerado. |
| `processingPollInterval` (3s) | Intervalo do `Timer.periodic` em `ProcessingController` para consultar o status do backend. |

Centralizar esses valores aqui significa que *tweakar* a experiência é uma mudança de uma linha, sem caçar pelos arquivos.

## `core/errors/app_exception.dart`

[lib/core/errors/app_exception.dart](../lib/core/errors/app_exception.dart) define uma hierarquia simples:

```dart
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class UploadException extends AppException {
  const UploadException(super.message);
}

class ProcessingException extends AppException {
  const ProcessingException(super.message);
}
```

A motivação é simples: quando a UI exibe uma mensagem de erro, ela não precisa saber se veio de timeout do Dio, de status HTTP 500 ou de um JSON malformado — só precisa saber que foi "erro de rede" vs. "erro de upload" vs. "erro de processamento". Os repositórios capturam exceções específicas (`DioException`, `SocketException`, etc.) e re-emitem como `AppException`.

```dart
try {
  await _dio.post(...);
} on DioException catch (e) {
  throw NetworkException('Falha ao enviar imagens: ${e.message}');
}
```

Isso mantém a UI agnóstica à implementação da camada de rede.

## `core/network/dio_client.dart`

[lib/core/network/dio_client.dart](../lib/core/network/dio_client.dart) expõe um provider Riverpod que cria o `Dio` singleton:

```dart
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
  ));

  assert(() {
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
    ));
    return true;
  }());

  return dio;
});
```

Decisões importantes:

- **`connectTimeout: 15s`** — uma rede Wi-Fi normal conecta em ms, mas um backend local pode estar caindo; 15s dá margem sem travar a UI eternamente.
- **`receiveTimeout: 30s`** — para respostas normais (GET de status).
- **`sendTimeout: 5min`** — *upload* multipart de 24 imagens pode passar de 20 MB; 5 minutos é tolerante para rede ruim.
- **`LogInterceptor`** dentro de `assert(() { ... }())` — esse *truque* faz o log só ser incluído em builds de debug. Em release, o `assert` é stripado pelo compilador AOT, e o `LogInterceptor` não é criado, evitando vazar payloads em produção.
- **`requestBody: false`** — não loga corpos de request (seriam as imagens, muito grandes).
- **`responseBody: true`** — loga respostas do backend (JSONs pequenos).

## `core/utils/`: o coração algorítmico

Os quatro arquivos em [lib/core/utils/](../lib/core/utils/) implementam os algoritmos que tornam o *live feedback* da câmera possível. São as classes mais "técnicas" do projeto.

### `frame_analyzer.dart`

[lib/core/utils/frame_analyzer.dart](../lib/core/utils/frame_analyzer.dart) analisa um `CameraImage` em formato YUV420 e retorna três métricas:

```dart
class FrameMetrics {
  final double brightness;     // 0..255
  final double sharpness;      // variância do Laplaciano
  final double saturatedRatio; // fração de pixels acima do _saturationThreshold
}
```

A implementação trabalha apenas no **plano Y** (luminância) do YUV420 — isso já dá brilho, nitidez e saturação sem precisar converter para RGB (o que seria caríssimo a 30 FPS).

- **Brilho**: média aritmética do plano Y (após subsample).
- **Nitidez**: **variância do Laplaciano**. Aplica o kernel 3×3 `[0 -1 0; -1 4 -1; 0 -1 0]` em cada pixel e calcula `variance = E[x²] - E[x]²` dos resultados. Alta variância = muitas bordas detectadas = imagem nítida. Baixa variância = borrada.
- **Saturação**: conta quantos pixels estão acima do `_saturationThreshold = 245` e divide pelo total. Representa "estouro de branco" — reflexos de luz direta no frasco.

**Subsample (`_step = 8`)**: em vez de iterar pelos ~2 milhões de pixels de um frame 1920×1080, pula de 8 em 8 linhas e colunas. Isso reduz 64× o custo computacional, mantendo as estatísticas representativas (são médias e variâncias, não precisam ser exatas).

Trade-off: perde detalhes finos, mas para brilho global e nitidez macro é mais que suficiente.

### `tilt_tracker.dart`

[lib/core/utils/tilt_tracker.dart](../lib/core/utils/tilt_tracker.dart) consome o stream do acelerômetro (`sensors_plus`) e calcula o **pitch** do aparelho:

```dart
double pitch = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
```

A fórmula vem da mecânica clássica: quando o celular está deitado paralelo ao chão (tela para cima), `z ≈ 9.8 m/s²` (toda a gravidade no eixo Z) e `x, y ≈ 0`. `atan2(9.8, 0) = π/2 = 90°`. Quando está em pé (orientação retrato normal), `y ≈ -9.8` e `z ≈ 0`, retornando 0°.

**Suavização exponencial**:

```dart
_smoothedPitch = _smoothedPitch * 0.85 + newPitch * 0.15;
```

Essa média móvel com pesos 85/15 filtra jitter de baixa amplitude (tremor natural da mão). Sem ela, o status de tilt piscaria entre `aligned` e `tilted` a cada respiração.

**Tolerância** (`_tiltTolerance = 20.0` graus): o app aceita o celular inclinado até 20° de qualquer referência. É folgado o suficiente para não estressar o usuário, mas apertado o suficiente para evitar fotos enviesadas que complicam a fotogrametria.

### `orb_similarity_tracker.dart`

[lib/core/utils/orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart) é o **pivot técnico do projeto**. Substituiu um antigo `AngleTracker` baseado em giroscópio (hoje deletado) por uma abordagem de **visão computacional drift-free**: comparar o frame atual com todas as fotos já tiradas, por features ORB.

#### Pipeline completo

```dart
// 1. Reduz resolução (performance)
final resized = _resizeToWidth(yPlane, width, height, _targetWidth); // 480 px

// 2. Extrai keypoints e descritores binários
final (kp, desc) = _orb.detectAndCompute(resizedMat, emptyMask);
// nFeatures = 500

// 3. Para cada imagem capturada, faz kNN matching
for (final stored in _storedDescriptors) {
  final matches = _matcher.knnMatch(desc, stored.descriptors, k: 2);
  int goodCount = 0;
  for (final pair in matches) {
    if (pair.length == 2 && pair[0].distance < 0.75 * pair[1].distance) {
      goodCount++; // passou no Lowe's ratio test
    }
  }
  maxMatches = math.max(maxMatches, goodCount);
}

// 4. Classifica o status
if (maxMatches >= 90) return SimilarityStatus.duplicate;
if (maxMatches >= 40) return SimilarityStatus.partial;
return SimilarityStatus.newAngle;
```

#### Por que essas escolhas

- **ORB** (Oriented FAST and Rotated BRIEF): detector **livre de patentes** (versus SIFT/SURF, patenteados), ordens de grandeza mais rápido, e com descritores binários (32 bytes) que comparam em norma de Hamming (XOR + popcount), extremamente eficientes.
- **`nFeatures = 500`**: balanço entre ruído (poucos features = falso-match fácil) e custo (muitos features = kNN lento). 500 é o default do OpenCV e funciona bem para objetos de médio detalhe como um frasco.
- **`_targetWidth = 480 px`**: redimensionar o frame antes do ORB reduz quase linearmente o custo. Em 480 de largura, ORB roda em ~80 ms; em 1280, passa de 300 ms.
- **`BFMatcher` com `NORM_HAMMING`**: *brute-force matcher* com norma de Hamming — ideal para descritores binários de ORB. Alternativas (`FlannBasedMatcher` + LSH) exigem setup e não ganham muito em escalas pequenas (< 100 imagens).
- **`knnMatch` com `k = 2`**: para cada descritor do frame atual, pega os **dois** vizinhos mais próximos em cada imagem armazenada. Isso alimenta o próximo passo:
- **Lowe's ratio test (`0.75`)**: um match só é considerado "bom" se a distância ao melhor vizinho for **< 75% da distância ao segundo melhor**. Isso filtra falsos-positivos em objetos simétricos (onde múltiplas regiões parecem iguais): se o melhor e o segundo melhor estão próximos, o match é ambíguo e descartado. `0.75` é o valor canônico do paper original do Lowe (2004).

#### Thresholds de classificação

```dart
static const int duplicateThreshold = 90;
static const int partialThreshold = 40;
```

- **`duplicate` (≥ 90 matches)**: "esse ângulo você já capturou — mova o celular." Banner vermelho.
- **`partial` (40–89 matches)**: "parecido com alguma foto, mas ainda tem diferença — pode capturar se quiser." Banner amarelo.
- **`newAngle` (< 40 matches)**: "ângulo novo, pode capturar!" Banner verde.

Esses valores foram **calibrados empiricamente** com um frasco real. Valores iniciais (`60` / `20`) geravam falso-positivos em perfumes simétricos — o lado esquerdo e o direito do frasco são quase idênticos, então o ORB matcheava agressivamente. Subir para `90` / `40` tolera essa ambiguidade natural do objeto.

Ver [14 — Histórico](14-historico-de-mudancas.md) para o caminho completo dessa calibração.

#### Cache de descritores e `dispose()`

Cada foto tirada tem seus KeyPoints + descriptors computados **uma vez** e guardados:

```dart
class _StoredDescriptors {
  final VecKeyPoint keypoints;
  final Mat descriptors; // OpenCV Mat — memória nativa!
}
```

A `Mat` do OpenCV vive em memória nativa (C++), não no heap do Dart. Isso significa que:

- O Garbage Collector do Dart **não libera** automaticamente.
- É preciso chamar `.dispose()` explicitamente.

Por isso `OrbSimilarityTracker.dispose()` itera sobre `_storedDescriptors` e chama `m.descriptors.dispose()` em cada uma, além de liberar o `_orb` e o `_matcher`. E por isso o `LiveCaptureController` é `autoDispose` — para garantir que esse `dispose()` seja chamado quando a câmera fecha.

### `image_quality_analyzer.dart`

[lib/core/utils/image_quality_analyzer.dart](../lib/core/utils/image_quality_analyzer.dart) é mais simples: classifica o conjunto capturado em níveis de qualidade, com base apenas no **número** de imagens:

```dart
enum QualityLevel { insufficient, acceptable, good }

class QualityReport {
  final QualityLevel level;
  final String message;
}

QualityReport evaluate(int imageCount) {
  if (imageCount < AppConstants.minImages) {
    return QualityReport(
      level: QualityLevel.insufficient,
      message: 'Capture pelo menos ${AppConstants.minImages} fotos...',
    );
  }
  if (imageCount < AppConstants.recommendedImages) {
    return QualityReport(
      level: QualityLevel.acceptable,
      message: 'Você tem o mínimo necessário, mas mais fotos melhoram o resultado.',
    );
  }
  return QualityReport(
    level: QualityLevel.good,
    message: 'Ótima cobertura! Você pode enviar quando quiser.',
  );
}
```

É uma heurística deliberadamente simples. Não analisa diversidade dos ângulos (esse trabalho é feito em tempo real pelo ORB). Apenas conta fotos e dá um *hint* textual na tela de revisão.

## Para onde ir agora

- Como esses utilitários são **orquestrados** pelo `LiveCaptureController`: [09 — Feature `product_capture`](09-feature-product-capture.md).
- Os termos técnicos (ORB, Laplaciano, Lowe, Hamming) definidos em verbetes curtos: [17 — Glossário](17-glossario.md).
