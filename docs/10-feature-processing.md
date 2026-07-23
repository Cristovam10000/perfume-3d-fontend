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
| `error` | Falha terminal retornada pelo backend. |
| `pollingWarning` | Falha temporaria ao consultar o andamento; nao encerra o job. |

Atalhos:

- `isCompleted`;
- `hasError`;
- `hasPollingWarning`;
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

Erros de Dio viram `ProcessingException` com mensagens compreensiveis para
timeout, conexao local, resposta HTTP, cancelamento e demais falhas. A resposta
tambem e validada antes do mapeamento.

## State

### `ProcessingController`

Responsabilidades:

- `start(jobId)`: define estado `uploaded` e inicia polling;
- `_poll()`: chama repositorio e atualiza estado;
- `pollNow()`: permite uma consulta manual imediata;
- `retry()`: limpa erro e reinicia polling;
- `reset()`: cancela timer e volta para estado inicial.

O polling usa:

```dart
Timer.periodic(AppConstants.processingPollInterval, (_) => _poll());
_poll(); // primeira consulta imediata
```

O controller impede consultas simultaneas e ignora respostas atrasadas de um
job anterior. O timer para somente quando o backend informa `completed` ou
`error`.

Uma falha isolada de rede nao transforma o job em `error`: o estado atual e
preservado, `pollingWarning` explica que o backend pode continuar processando e
o timer tenta novamente. Uma resposta valida seguinte remove o aviso.

## UI

### `ProcessingStatusPage`

Mostra:

- icone por status;
- label do status;
- `jobId`, quando existe;
- barra de progresso enquanto nao finaliza;
- mensagem do backend, erro ou mensagem padrao;
- aviso de reconexao e botao `Consultar agora` quando uma consulta falha;
- botao `Visualizar modelo 3D` quando `completed` e `modelUrl != null`;
- botoes `Revisar e reenviar` e `Voltar ao inicio` em erro terminal.

Ao visualizar:

```dart
ref.read(viewerControllerProvider.notifier).load(job.modelUrl!);
context.goNamed(AppRoutes.viewerName);
```

## Rotas

| Rota | Estado atual |
|---|---|
| `/processing` | usada pelo fluxo de captura. |
| `/processando/:jobId` | inicia ou retoma o polling usando o parametro da rota. |

## Proxima leitura

- Viewer final: [11 - Feature `product_viewer`](11-feature-product-viewer.md).
- Contrato HTTP: [16 - Contrato do backend](16-contrato-backend.md).
