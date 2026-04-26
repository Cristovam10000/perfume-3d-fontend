# 17 — Glossário

Termos técnicos usados ao longo da documentação, explicados em verbetes curtos. Organizados por categoria.

## Visão computacional

### ORB (Oriented FAST and Rotated BRIEF)

Algoritmo de detecção + descrição de *features* em imagens. Criado por Rublee et al. (2011) no OpenCV Labs como alternativa livre de patentes ao SIFT e SURF. Tem duas partes:

- **FAST** (detector): encontra *keypoints* olhando círculos de 16 pixels ao redor de cada ponto.
- **BRIEF** (descritor): codifica cada keypoint em um vetor binário de 32 bytes comparando pares aleatórios de pixels vizinhos.

ORB acrescenta **orientação** ao FAST (para invariância rotacional) e **rotação** ao BRIEF. No projeto, configurado com `nFeatures=500` e aplicado a frames redimensionados para 480 px de largura — ver [orb_similarity_tracker.dart](../lib/core/utils/orb_similarity_tracker.dart).

### Descritor de features

Vetor numérico que resume o "vizinhança" de um keypoint. Dois descritores podem ser comparados por distância (menor distância = mais parecidos). Descritores do ORB são **binários** (compactos e rápidos de comparar). Descritores do SIFT são floats de 128 dimensões (mais precisos, mas muito mais lentos).

### BFMatcher (Brute-Force Matcher)

Comparador "burro" de descritores: para cada descritor do frame A, calcula distância contra **todos** os descritores do frame B e retorna os mais próximos. Não usa estruturas de índice como KD-Tree ou LSH.

Para datasets pequenos (< 500 features por lado), é o mais simples e rápido. No projeto, usado com norma de Hamming (apropriada para descritores binários do ORB).

### Norma de Hamming

Distância entre dois vetores binários: número de bits que diferem. Implementada como `popcount(a XOR b)`. Extremamente rápida em CPUs modernas (instrução `POPCNT`).

Para descritores de 32 bytes (256 bits) do ORB, a distância máxima é 256. Na prática, matches "bons" têm distâncias < 64.

### knnMatch (k-Nearest Neighbors matching)

Variante do `match` que retorna os **k** vizinhos mais próximos em vez de apenas o melhor. Usado no projeto com `k=2` para habilitar o próximo conceito:

### Lowe's ratio test

Teste proposto por David Lowe no paper original do SIFT (2004) para filtrar matches ambíguos. A regra:

> Um match é "bom" se a distância ao melhor vizinho for **menor que `r * distância ao segundo melhor`**.

Com `r = 0.75`, rejeita matches onde o "melhor" e o "segundo melhor" estão próximos demais — significa que o descritor é ambíguo (provavelmente feature repetida no objeto, como uma quina simétrica de um frasco).

### Variância do Laplaciano

Medida de nitidez de uma imagem. Calculada em duas etapas:

1. Aplica o kernel Laplaciano `[[0,-1,0],[-1,4,-1],[0,-1,0]]` na imagem, obtendo uma imagem de "bordas".
2. Calcula a **variância** (não apenas a média) dos valores resultantes.

Alta variância = muitas bordas detectadas = imagem nítida. Baixa variância = imagem borrada (bordas dissolvidas).

Método popularizado por Pech-Pacheco et al. (2000). No projeto, threshold `25` indica "provavelmente borrada" — ver [frame_analyzer.dart](../lib/core/utils/frame_analyzer.dart).

### YUV420

Formato de imagem usado pelo stream da câmera em Android. Tem três planos separados:

- **Y (luminância)**: 8 bits por pixel, resolução total — a intensidade de luz.
- **U (chroma blue)** e **V (chroma red)**: 8 bits por pixel, mas **subsampleados 2× em ambas direções** — a cor.

O subsample de UV cabe no olho humano: somos mais sensíveis a luminância que a cor. Vantagem: ocupa **metade** do espaço de um RGB equivalente.

Para análises que só precisam de intensidade (brilho, nitidez, saturação, features), basta o plano Y — é exatamente o que o `FrameAnalyzer` e o `OrbSimilarityTracker` fazem.

## Algorítmica / UX

### Histerese (ou streak counter)

Técnica para suavizar transições entre estados de um sinal ruidoso. Em vez de reagir imediatamente à primeira leitura que cruza um threshold, espera **N leituras consecutivas** na mesma direção antes de mudar o estado exibido.

No projeto: `_blurStreakThreshold = 3` — o banner de "foto borrada" só aparece após 3 leituras seguidas abaixo do threshold de nitidez. Evita que o banner pisque por tremores naturais da mão.

### Throttling

Limitar a taxa com que uma operação cara é executada. No projeto, o stream da câmera vem a ~30 FPS, mas:

- `FrameAnalyzer` é throttled a **5 Hz** (uma execução a cada 200 ms).
- `OrbSimilarityTracker` é throttled a **2 Hz** (uma execução a cada 500 ms).

Implementado guardando o timestamp da última execução e comparando com `DateTime.now()` a cada novo frame.

## Sensores / Matemática

### Pitch, Roll, Yaw

Rotações de um corpo rígido em três eixos:

- **Pitch** — rotação em torno do eixo lateral (inclinar para frente/trás).
- **Roll** — rotação em torno do eixo longitudinal (tombar para o lado).
- **Yaw** — rotação em torno do eixo vertical (virar em "sim / não").

No contexto de um celular deitado com a tela virada para o usuário, `pitch` representa "inclinar o topo do celular para longe ou para perto". É o que o [TiltTracker](../lib/core/utils/tilt_tracker.dart) mede a partir do vetor de gravidade via `atan2(z, sqrt(x²+y²))`.

### Acelerômetro vs. Giroscópio

- **Acelerômetro**: mede aceleração linear (incluindo a gravidade). Em repouso, dá um vetor de gravidade — útil para saber orientação absoluta do aparelho.
- **Giroscópio**: mede velocidade angular. Para saber rotação acumulada, precisa **integrar** no tempo — o que introduz *drift*.

O pivot deste projeto (ver [14 — Histórico](14-historico-de-mudancas.md)) abandonou o giroscópio por causa do drift.

## Arquitetura / Flutter

### Clean Architecture

Padrão arquitetural popularizado por Robert C. Martin (Uncle Bob) que separa código em **camadas concêntricas**: domínio (regras de negócio) no centro, infraestrutura (UI, banco, rede) na borda. Dependências fluem sempre de fora para dentro.

Neste projeto, cada feature tem `domain/` (modelos), `data/` (repositórios que falam com Dio), e `presentation/` (UI + state). `domain/` nunca importa `data/` ou `presentation/`. Ver [05 — Arquitetura](05-arquitetura.md).

### Feature-First

Padrão de organização de pastas em que código é agrupado **por funcionalidade** (ex: `features/product_capture/`) em vez de por tipo técnico (ex: `pages/`, `repositories/`, `models/` globais).

Vantagem: localidade — tudo que pertence à captura está em um lugar só. Desvantagem: pode duplicar código "quase igual" entre features se o limite não for cuidadoso (resolvido por `shared/` e `core/`).

### Provider (Riverpod)

O tipo mais simples de provider do Riverpod: expõe um valor **imutável** construído uma vez. Análogo a um singleton injetado. Exemplo no projeto: `dioClientProvider`.

### StateNotifierProvider

Provider que expõe um `StateNotifier<S>` — uma classe que encapsula um estado mutável `S`. A UI chama `ref.watch(provider)` para observar o estado, e `ref.read(provider.notifier).method()` para mutar. Exemplo: `captureControllerProvider`.

Diferente de `ChangeNotifier` do Flutter: `StateNotifier` força estados imutáveis (pattern `copyWith`), o que evita bugs de mutação compartilhada.

### autoDispose

Modificador de provider que **destrói o estado** quando nenhum widget o está observando. Útil para providers que mantêm recursos caros (memória nativa, subscriptions, timers) e que são ligados à vida de uma tela específica.

No projeto, usado no `liveCaptureControllerProvider` porque ele guarda `Mat`s do OpenCV (memória nativa) e subscription do acelerômetro — tudo precisa ser liberado quando o usuário sai da câmera.

### ConsumerWidget / ConsumerStatefulWidget

Widgets do `flutter_riverpod` que expõem um `WidgetRef` no `build`, permitindo usar `ref.watch`, `ref.read` e `ref.listen`. Substitutos do `StatelessWidget`/`StatefulWidget` quando a tela precisa interagir com providers.

### `copyWith`

Convenção Dart para classes imutáveis: em vez de mutar campos, cria uma nova instância com alguns campos substituídos.

```dart
final next = state.copyWith(isUploading: true);
```

Riverpod + StateNotifier depende disso para reagir a mudanças — como cada `state = state.copyWith(...)` é uma instância nova, `==` retorna `false`, disparando rebuild dos consumers.

## Fotogrametria

### Fotogrametria

Técnica de construir modelos 3D a partir de múltiplas fotos do mesmo objeto tiradas de ângulos diferentes. Algoritmo típico:

1. **Structure from Motion (SfM)**: identifica pontos comuns entre as fotos e infere a posição da câmera em cada uma.
2. **Multi-View Stereo (MVS)**: densifica a nuvem de pontos usando as câmeras estimadas.
3. **Meshing**: converte a nuvem em uma malha de triângulos.
4. **Texturing**: projeta as fotos na malha.

O backend deste projeto faz esse pipeline. O app apenas garante que as fotos de entrada são **diversas** (ângulos variados, capturados pelo `OrbSimilarityTracker`) e de **qualidade** (nitidez, iluminação, tilt, capturados pelo `FrameAnalyzer` + `TiltTracker`).

### `.glb` / `.gltf`

Formatos padrão da indústria para modelos 3D, mantidos pela Khronos Group. `.gltf` é JSON + assets externos; `.glb` é um único arquivo binário. Ambos suportados nativamente por `<model-viewer>`, pelo Android Scene Viewer, pelo iOS Quick Look AR e pela maioria dos engines 3D modernos.

## Para onde ir agora

- Os conceitos aplicados na prática: [07 — Camada `core/`](07-camada-core.md) (algoritmos), [05 — Arquitetura](05-arquitetura.md) (padrões), [09 — Feature `product_capture`](09-feature-product-capture.md) (integração).
