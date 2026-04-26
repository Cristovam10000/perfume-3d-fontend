# 14 — Histórico de mudanças

Esta página é a única em que descrevemos o **passado** do projeto. Baseada em `git log`, ela narra os três commits que existem e — mais importante — o **pivot técnico** que aconteceu entre o primeiro e o segundo.

## Os três commits

```
a8b85e7  Remove unused AngleTracker and CoverageWheel classes;
         update thresholds in OrbSimilarityTracker and
         LiveCaptureController for improved performance.
63f2d07  Add OpenCV and DartCV4 dependencies; implement ORB similarity
         tracking and tilt tracking features
c303de7  first commit
```

Branch: `main`. Remote: `https://github.com/Cristovam10000/TCC.git`.

## `c303de7` — "first commit"

O scaffolding inicial do projeto. Foi criado com `flutter create perfume_3d_mvp` e recebeu a primeira versão do app com o paradigma **walk-around**.

### O que "walk-around" significava

A ideia original: o usuário deixa o perfume **parado** em cima de uma mesa e **anda ao redor** dele segurando o celular. A câmera captura fotos enquanto o usuário circula o objeto — uma rotação completa de 360°.

### Como o app tentava guiar esse fluxo

Com dois artefatos que **não existem mais** no código de hoje:

- **`angle_tracker.dart`** — rastreava rotação acumulada usando o **giroscópio** do `sensors_plus`. Integrava a velocidade angular no eixo vertical para estimar quantos graus o usuário já tinha girado.
- **`coverage_wheel.dart`** — widget visual: uma roda de 12 fatias (uma por bin de 30°). Cada bin acendia quando o usuário passava pela faixa correspondente e tirava uma foto ali.

### Por que isso não funcionou bem

Dois problemas:

1. **Drift do giroscópio**: giroscópios MEMS acumulam erro rapidamente quando integrados no tempo. Depois de 1–2 minutos de captura, o app achava que o usuário tinha girado 400° quando na verdade foram 350°. Isso fazia a roda preencher posições erradas.
2. **Pressupõe movimento do usuário**: e se o usuário estiver em um ambiente apertado onde não dá para circular o objeto? E se o objeto (o perfume) for pequeno e o usuário achar mais natural **girar o objeto na mão** enquanto o celular fica fixo?

O segundo ponto foi o gatilho real do pivot. O autor percebeu que frascos de perfume são objetos de mesa, não itens grandes estacionários — o caso de uso "girar na mão" é muito mais natural que "andar ao redor".

## `63f2d07` — "Add OpenCV and DartCV4…"

O **pivot técnico**. Este commit reescreve a base do *live feedback*:

### Adições

- **`opencv_dart ^1.3.0`** no `pubspec.yaml` (com `dartcv4` como transitivo).
- **`orb_similarity_tracker.dart`** — o novo coração: compara o frame atual com as fotos já tiradas usando ORB + BFMatcher + Lowe's ratio test.
- **`tilt_tracker.dart`** — substitui o giroscópio por **acelerômetro** para medir apenas se o celular está inclinado (pitch), sem tentar rastrear rotação acumulada.

### Mudanças

- **`FrameAnalyzer`** passa a trabalhar em **YUV420** (o novo formato da câmera) em vez de JPEG decodificado — muito mais eficiente.
- A `CameraController` configura `ImageFormatGroup.yuv420` explicitamente para habilitar isso.
- O `LiveCaptureController` é reescrito para orquestrar os três utilitários novos em vez de angle tracking.
- `test/widget_test.dart` é removido (era o boilerplate do `flutter create` para um app contador — não tinha nada a ver com este projeto).

### A nova ideia: ORB em vez de giroscópio

Em vez de perguntar "o usuário girou o suficiente?" (dependente de inércia, drift, movimento físico), o app passa a perguntar **"o frame atual é similar demais às fotos já tiradas?"** — uma pergunta de visão computacional, frame-a-frame, **sem memória temporal e sem drift**.

Funciona igual se o usuário andar ao redor OU girar o objeto na mão OU ambos. Só importa o que a câmera vê.

### Por que ORB (e não SIFT/SURF)

- **Livre de patentes**: ORB (Oriented FAST and Rotated BRIEF) foi criado pelo OpenCV Labs justamente para substituir SIFT/SURF, que são patenteados pela University of British Columbia e pela Surrey.
- **Rápido**: descritores binários (32 bytes) comparam em norma de Hamming (XOR + popcount), ordens de grandeza mais eficientes que floats em euclidiana.
- **Suficientemente robusto**: não é o detector mais preciso do mundo, mas para a tarefa "esses dois frames mostram a mesma face do objeto?" é mais que o suficiente.

## `a8b85e7` — "Remove unused AngleTracker…"

O commit de **polimento e calibração** pós-pivot. Três ações distintas:

### 1. Deleta os órfãos do paradigma antigo

Com o ORB funcionando, `angle_tracker.dart` e `coverage_wheel.dart` não são mais referenciados por nada. Este commit remove os dois arquivos. Reduz ~200 linhas de código morto.

### 2. Calibra os thresholds do ORB

Durante testes com um frasco real, observou-se que **perfumes são objetos difíceis** para detecção de features:

- **Simétricos**: o lado esquerdo e o direito de muitos frascos são idênticos. O ORB matcheava agressivamente, achando que ângulos opostos eram "o mesmo ângulo".
- **Reflexivos**: vidro e superfícies espelhadas criam features ilusórias que mudam com a iluminação. Um match hoje pode não ser um match amanhã.

Os valores iniciais `duplicate=60` e `partial=20` falhavam em reconhecer ângulos realmente novos. A calibração subiu os thresholds:

- `duplicateThreshold: 60 → 90` (precisa de mais matches para considerar "mesmo ângulo").
- `partialThreshold: 20 → 40` (faixa de "parecido mas aceitável" também sobe proporcionalmente).

Isso **tolera** a ambiguidade natural de um frasco simétrico.

### 3. Endurece a detecção de blur, **com histerese**

No estado anterior, o `_blurryThreshold` era 60 (variância do Laplaciano). Parecia razoável em fotos estáticas, mas no stream de câmera isso gerava muitos falso-negativos: variâncias entre 25 e 60 frequentemente correspondiam a frames perfeitamente bons com pouco detalhe visual, e o app dizia "está borrado" quando não estava.

A mudança foi dupla:

- **Abaixa o threshold**: `60 → 25`. Agora só frames realmente borrados passam.
- **Adiciona histerese**: `_blurStreakThreshold = 3`. Só marca "borrado" depois de **3 leituras consecutivas** abaixo do threshold.

Por quê? Sem a histerese, baixar o threshold não ajudava — leituras esporádicas abaixo de 25 (o usuário respirando, um reflexo súbito) ainda ativariam o banner. A histerese filtra falsos-positivos transitórios. O banner só pisca vermelho quando o celular realmente está em movimento por meio segundo ou mais.

Esse é o tipo de ajuste fino que **só aparece ao testar com usuários reais**. Valores teoricamente "certos" do paper canônico de Pech-Pacheco et al. (2000, que propôs a variância do Laplaciano) precisam ser recalibrados para o caso de uso.

## Por que o pivot aconteceu — em uma frase

**Giroscópio é integrador e frágil; ORB é comparador e direto.** Um sensor que precisa saber "onde eu estava em relação a onde comecei" sofre com drift e pressupõe um padrão de movimento. Um detector de features frame-a-frame não tem história, não sofre com drift, e funciona para qualquer padrão de movimento — mão parada com objeto girando, objeto parado com mão girando, ou ambos.

## Evolução futura (não commitada)

Itens que estão na mente do autor mas ainda não viraram código:

- **Cache offline dos modelos .glb** (hoje toda abertura da viewer baixa de novo).
- **Histórico de capturas** — botão placeholder na home.
- **AR** — `ModelViewer(ar: true)` com configuração ARCore/USDZ.
- **Testes** — `test/` está vazio; o primeiro teste natural seria unitário do `OrbSimilarityTracker` com fixtures de imagens.
- **Internacionalização** — strings hoje hardcoded em pt-BR.

Ver [01 — Visão geral](01-visao-geral.md) seção "Escopo do MVP — o que está fora" para a lista completa.

## Para onde ir agora

- A implementação atual do ORB e do TiltTracker (pós-pivot): [07 — Camada `core/`](07-camada-core.md).
- O *design* final do live feedback: [09 — Feature `product_capture`](09-feature-product-capture.md).
