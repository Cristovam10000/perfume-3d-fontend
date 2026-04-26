# 10 - Feature `processing`

`processing` acompanha o job de reconstrucao 3D criado apos o upload de imagens.

## Estrutura

```text
lib/features/processing/
  data/
    processing_repository.dart
  domain/
    processing_job.dart
  presentation/
    pages/
      processing_status_page.dart
    state/
      processing_controller.dart
```

## Domain

### `ProcessingStatus`

Valores atuais:

- `idle`
- `waiting`
- `uploaded`
- `processing`
- `completed`
- `error`

Cada status tem `label` para exibicao em tela.

### `ProcessingJob`

Campos:

| Campo | Uso |
|---|---|
| `jobId` | Identificador retornado por `POST /captures`. |
| `status` | Estado atual do processamento. |
| `message` | Mensagem opcional do backend. |
| `modelUrl` | URL do `.glb`/`.gltf` quando completo. |
| `error` | Falha retornada ou gerada no front. |

Atalhos:

- `isCompleted`;
- `hasError`;
- `parseStatus(String?)`.

## Data

### `ProcessingRepository`

Consulta:

```dart
GET /captures/{jobId}/status
```

Mapeia o JSON para `ProcessingJob`:

```dart
ProcessingJob(
  jobId: jobId,
  status: ProcessingJob.parseStatus(data['status'] as String?),
  message: data['message'] as String?,
  modelUrl: data['modelUrl'] as String?,
  error: data['error'] as String?,
)
```

Erros de Dio viram `ProcessingException`.

## State

### `ProcessingController`

Responsabilidades:

- `start(jobId)`: define estado `uploaded` e inicia polling;
- `_poll()`: chama repositorio e atualiza estado;
- `retry()`: limpa erro e reinicia polling;
- `reset()`: cancela timer e volta para estado inicial.

O polling usa:

```dart
Timer.periodic(AppConstants.processingPollInterval, (_) => _poll());
_poll(); // primeira consulta imediata
```

O timer para quando o status chega em `completed` ou `error`.

## UI

### `ProcessingStatusPage`

Mostra:

- icone por status;
- label do status;
- `jobId`, quando existe;
- barra de progresso enquanto nao finaliza;
- mensagem do backend, erro ou mensagem padrao;
- botao `Visualizar modelo 3D` quando `completed` e `modelUrl != null`;
- botoes `Tentar novamente` e `Voltar ao inicio` em erro.

Ao visualizar:

```dart
ref.read(viewerControllerProvider.notifier).load(job.modelUrl!);
context.goNamed(AppRoutes.viewerName);
```

## Rotas

| Rota | Estado atual |
|---|---|
| `/processing` | usada pelo fluxo de captura. |
| `/processando/:jobId` | existe para fluxo por produto/job, mas ainda nao usa o parametro para iniciar polling. |

## Proxima leitura

- Viewer final: [11 - Feature `product_viewer`](11-feature-product-viewer.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
