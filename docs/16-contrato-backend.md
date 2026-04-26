# 16 — Contrato do backend

O app Flutter **não faz a reconstrução 3D** — ele apenas captura as imagens e confia em um backend externo para o trabalho pesado. Este documento descreve o **contrato HTTP** que o app espera desse backend, **inferido do código dos repositórios** ([capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart) e [processing_repository.dart](../lib/features/processing/data/processing_repository.dart)).

**Importante**: o backend em si **não faz parte deste repositório**. É um serviço Python separado (fora do escopo desta documentação). O que segue é apenas o contrato que o app consome.

## Base URL

Configurável via [AppConstants.backendBaseUrl](../lib/core/constants/app_constants.dart):

```dart
static const String backendBaseUrl = 'http://10.0.2.2:8000';
```

Valores típicos conforme o cenário de execução:

| Cenário | Base URL |
|---|---|
| Emulador Android → host local | `http://10.0.2.2:8000` (padrão) |
| Device Android físico na mesma rede | `http://<IP da máquina>:8000` |
| iOS simulator | `http://localhost:8000` |
| Device iOS físico | `http://<IP da máquina>:8000` |
| Produção | `https://api.seu-dominio.com` |

## Endpoints

### `POST /captures`

**Propósito**: enviar um lote de imagens para iniciar um job de reconstrução 3D.

**Request**:

- Método: `POST`
- Content-Type: `multipart/form-data`
- Campo: `images[]` — um ou mais arquivos binários (JPEG). O Dio envia como `MultipartFile` cada um, com o `filename` setado para o `id` do `CapturedImage` (tipicamente o timestamp em ms).

Exemplo equivalente em `curl`:

```bash
curl -X POST http://10.0.2.2:8000/captures \
  -F "images[]=@foto_001.jpg" \
  -F "images[]=@foto_002.jpg" \
  ...
```

**Response (200 OK)**:

```json
{
  "jobId": "abc123-xyz"
}
```

Campos:

- **`jobId`** (string, obrigatório) — identificador opaco do job. O app guarda essa string e passa para o endpoint de status.

**Erros esperados**:

- Rede caiu / timeout → `DioException` no cliente, convertido em `state.errorMessage`.
- Backend retorna 4xx/5xx → mesma coisa. Hoje o app não faz retry automático; o usuário precisa tocar "Enviar" de novo.

**Observações**:

- O `Dio` do cliente usa `sendTimeout: 5 minutes` — generoso para uploads grandes em rede ruim.
- O `onSendProgress` callback recebe `(sent, total)` durante o envio, usado para animar a barra de progresso na UI.

### `GET /captures/{jobId}/status`

**Propósito**: consultar o estado atual de um job de reconstrução.

**Request**:

- Método: `GET`
- Path: `/captures/{jobId}/status` onde `{jobId}` é a string retornada pelo POST acima.

Exemplo:

```bash
curl http://10.0.2.2:8000/captures/abc123-xyz/status
```

**Response (200 OK)** — JSON com o schema abaixo:

```json
{
  "status": "processing",
  "progress": 0.42,
  "message": "Extraindo features...",
  "modelUrl": null,
  "errorCode": null
}
```

Campos:

- **`status`** (string, obrigatório) — um dos valores do enum `ProcessingStatus`:
  - `"queued"` — job recebido, aguardando worker.
  - `"processing"` — reconstrução em andamento.
  - `"uploading"` — modelo gerado, sendo publicado no storage.
  - `"completed"` — pronto. `modelUrl` DEVE estar preenchido.
  - `"failed"` — falha. `errorCode` DEVE estar preenchido.
  - `"cancelled"` — cancelado (hoje não usado pelo app, mas reservado).
- **`progress`** (number, opcional) — fração `0.0..1.0` de completude. Se ausente, o app esconde a barra de progresso e mostra apenas o spinner.
- **`message`** (string, opcional) — texto curto exibido abaixo do ícone (ex: "Extraindo features", "Gerando mesh").
- **`modelUrl`** (string, opcional) — quando `status == "completed"`, URL HTTPS pública do arquivo `.glb` ou `.gltf` gerado. O app **não baixa** esse arquivo explicitamente — ele é passado ao `ModelViewer`, que o baixa internamente via WebView.
- **`errorCode`** (string, opcional) — código opaco do erro (ex: `"insufficient_features"`, `"worker_timeout"`). O app hoje não exibe esse código — apenas marca `status = failed` e mostra "Falha no processamento".

**Parser defensivo**:

```dart
ProcessingStatus _parseStatus(String raw) {
  return ProcessingStatus.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => ProcessingStatus.failed,
  );
}
```

Se o backend mandar um valor que o app não conhece (por exemplo, um status novo adicionado do lado servidor antes do app ser atualizado), o parser presume `failed` em vez de travar.

**Polling**:

- O app consulta este endpoint a cada [`AppConstants.processingPollInterval`](../lib/core/constants/app_constants.dart) = **3 segundos**.
- O polling para automaticamente quando `status` vira `completed`, `failed` ou `cancelled`.
- Erro de rede durante polling → o app transita para `failed` e para o timer. Não há retry automático.

## Endpoints **não** usados pelo app hoje

O app poderia consumir, mas atualmente não consome:

- `DELETE /captures/{jobId}` — cancelar um job em andamento.
- `GET /captures/{jobId}/metadata` — obter detalhes do modelo (nome, thumbnail etc.). O [ViewerRepository](../lib/features/product_viewer/data/viewer_repository.dart) tem um placeholder para isso mas não faz a chamada real.
- `GET /captures/history` — listar jobs anteriores. Funcionalidade "Histórico (em breve)" planejada.

## Autenticação

Hoje **nenhuma** autenticação é implementada no app. O backend presume cliente anônimo. Em um cenário de produção, seria natural adicionar:

- `Authorization: Bearer <token>` via um `Dio` interceptor.
- Tratamento de 401 (token expirado) redirecionando para uma tela de login.

Isso não está no escopo do MVP.

## Formato do modelo 3D retornado

O `modelUrl` aponta para um arquivo **`.glb`** (binário) ou `.gltf` (JSON + assets externos). O `ModelViewer` suporta ambos nativamente via o `<model-viewer>` do Google.

Recomendação técnica: usar `.glb` (binário) em vez de `.gltf` porque:

- Um único arquivo em vez de vários assets (menos chamadas HTTP).
- Menor tamanho total (menos overhead de JSON).
- Carregamento mais rápido no WebView.

O app não valida o formato antes de passar para o `ModelViewer` — se o URL for inválido ou o arquivo corrompido, o erro é reportado pela WebView internamente (e fica visível na tela como "could not load model").

## Para onde ir agora

- A implementação do upload no app: [09 — Feature `product_capture`](09-feature-product-capture.md).
- O polling e seu auto-stop: [10 — Feature `processing`](10-feature-processing.md).
- O consumo do `modelUrl`: [11 — Feature `product_viewer`](11-feature-product-viewer.md).
- Os fluxos completos, incluindo os HTTP requests nos diagramas: [13 — Fluxos de dados](13-fluxos-de-dados.md).
