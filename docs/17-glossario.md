# 17 - Glossario

## Produto e vendas

### Cliente

Pessoa que compra perfumes. No app, tem nome, telefone, bairro, score, status, valores em aberto e historico.

### Produto

Perfume vendido. Pode ou nao ter modelo 3D associado via `modelo3DPath`.

### Venda

Registro de uma compra, com cliente, data, itens, total, entrada e numero de parcelas.

### Parcela

Parte do pagamento de uma venda. Pode estar `paga`, `pendente`, `atrasada` ou `parcial`.

### Score

Indicador visual de confiabilidade do cliente. No mock, e um numero de 0 a 100 usado para cor/status.

### `SyncStatus`

Estado visual de sincronizacao: `synced`, `pending` ou `failed`. Hoje nao ha sincronizacao real; o status apenas comunica que algo seria local/pendente.

### `SalesSnapshot`

Objeto imutavel que agrupa listas mockadas e getters calculados para as telas comerciais.

## Flutter e arquitetura

### Feature-first

Organizacao por modulo de produto (`sales`, `product_capture`, `processing`, `product_viewer`) em vez de separar tudo globalmente por tipo tecnico.

### Riverpod Provider

Objeto que expoe uma dependencia ou estado para a arvore Flutter sem depender de `BuildContext`.

### `StateNotifierProvider`

Provider usado para estados mutaveis controlados por uma classe (`CaptureController`, `ProcessingController`, `ViewerController`).

### `autoDispose`

Instrucao para Riverpod destruir o provider quando nao houver ouvintes. Usado no live capture para liberar recursos de camera/sensores/OpenCV.

### `GoRouter.extra`

Campo para passar objeto em memoria durante navegacao. Usado pelo wizard para enviar uma `Venda` draft para `SaleDetailPage`.

### Guard de rota

`redirect` em uma rota. Impede abrir tela sem estado necessario, como revisao sem imagens ou viewer sem `modelUrl`.

## Captura e visao computacional

### YUV420

Formato de imagem comum em camera Android. O app usa o plano Y (luminancia) para analise eficiente.

### Brilho

Media dos valores do plano Y. Baixo demais indica ambiente escuro.

### Variancia do Laplaciano

Heuristica de nitidez. Valores baixos sugerem imagem borrada/tremida.

### Saturacao

Percentual aproximado de pixels muito claros. Ajuda a detectar reflexo forte no vidro.

### ORB

`Oriented FAST and Rotated BRIEF`. Algoritmo que detecta pontos visuais e descritores binarios em uma imagem.

### Descritor

Representacao compacta de um ponto visual. No ORB, e comparada por distancia de Hamming.

### BFMatcher

Brute Force Matcher do OpenCV. Compara descritores de duas imagens.

### `knnMatch`

Busca os `k` melhores matches por descritor. O app usa `k=2`.

### Lowe ratio test

Filtro que descarta matches ambiguos comparando a melhor e a segunda melhor distancia.

### `AngleVerdict`

Resultado da comparacao ORB:

- `noReference`;
- `newAngle`;
- `partialOverlap`;
- `duplicate`.

### Histerese

Tecnica para evitar alerta piscando. No blur, o app exige 3 leituras ruins consecutivas antes de avisar.

## Sensores

### Acelerometro

Sensor usado para estimar inclinacao do celular em relacao a gravidade.

### Pitch

Inclinacao vertical do aparelho. O app usa para avisar se a camera esta apontando para cima ou para baixo.

## 3D

### Fotogrametria

Processo de reconstruir um modelo 3D a partir de varias fotos de um objeto.

### `.glb` / `.gltf`

Formatos comuns para modelos 3D. O app renderiza esses arquivos com `model_viewer_plus`.

### `ModelViewer`

Widget Flutter que embute `<model-viewer>` em WebView/browser para exibir modelos 3D.

## Proxima leitura

- Modulo comercial: [18 - Feature `sales`](18-feature-sales.md).
- Algoritmos de captura: [07 - Camada `core`](07-camada-core.md).
