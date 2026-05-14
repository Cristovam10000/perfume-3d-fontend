# 16 - Contrato do backend

O backend cobre dois domínios:

1. **Captura/processamento 3D** (`/captures/*`, `/files/*`) - sempre via HTTP.
2. **Operação comercial** (`/sales/*`) - usado pelo `HttpSalesRepository` quando online; cai para `MockSalesRepository` em modo offline ou quando o backend nao responde.

O front Flutter consome ambos atraves do mesmo `Dio` centralizado em [AppConstants](../lib/core/constants/app_constants.dart).

## Base URL

Fonte: [AppConstants.backendBaseUrl](../lib/core/constants/app_constants.dart).

```dart
static const String backendBaseUrl = 'http://192.168.0.3:8000';
```

Troque conforme ambiente:

- Android Emulator: `http://10.0.2.2:8000`;
- aparelho fisico: IP da maquina na mesma rede;
- desktop/web local: `http://localhost:8000`, se aplicavel.

## `POST /captures`

Usado por [capture_repository.dart](../lib/features/product_capture/data/capture_repository.dart).

### Request

Multipart form-data:

| Campo | Tipo | Descricao |
|---|---|---|
| `images` | arquivo repetido | Fotos capturadas/selecionadas. |

O front monta:

```dart
FormData.fromMap({
  'images': [
    for (final f in images)
      await MultipartFile.fromFile(f.path, filename: f.uri.pathSegments.last),
  ],
})
```

### Response esperada

```json
{
  "jobId": "abc123"
}
```

`jobId` precisa ser string. Caso contrario, o front lanca:

```text
Resposta de upload invalida do servidor.
```

### Erros

Erros de rede/Dio viram `UploadException` com mensagem:

```text
Falha ao enviar imagens: ...
```

## `GET /captures/{jobId}/status`

Usado por [processing_repository.dart](../lib/features/processing/data/processing_repository.dart).

### Response esperada

```json
{
  "status": "processing",
  "message": "Gerando malha 3D...",
  "modelUrl": null,
  "error": null
}
```

Campos:

| Campo | Tipo | Obrigatorio | Descricao |
|---|---|---|---|
| `status` | string | recomendado | Estado do job. |
| `message` | string/null | nao | Mensagem amigavel. |
| `modelUrl` | string/null | quando completo | URL do modelo 3D. |
| `error` | string/null | quando erro | Erro do backend. |

Status aceitos pelo front:

- `waiting`;
- `uploaded`;
- `processing`;
- `completed`;
- `error`.

Qualquer outro valor vira `idle`.

### Exemplo completo

```json
{
  "status": "completed",
  "message": "Modelo pronto.",
  "modelUrl": "http://192.168.0.3:8000/files/models/job-abc123.glb",
  "error": null
}
```

## Modelos 3D do catalogo

Produtos mockados em [sales_repository.dart](../lib/features/sales/data/sales_repository.dart) podem ter `modelo3DPath`, por exemplo:

```dart
modelo3DPath: 'http://localhost:8000/files/models/demo-khamrah.glb'
```

Essas URLs nao passam por `Dio`; sao entregues diretamente ao `ModelViewer`. O device precisa conseguir acessa-las.

## Autenticacao

Nao ha autenticacao no front atual. Todas as chamadas presumem backend local anonimo.

## Backend comercial - `/sales/*`

Usado por [sales_repository.dart](../lib/features/sales/data/sales_repository.dart) - especificamente pela classe `HttpSalesRepository` (com fallback para `MockSalesRepository` quando offline). Todos os payloads usam camelCase ja convertido pelo Pydantic do backend.

### `GET /sales/snapshot`

Devolve o estado completo (clientes, produtos, vendas, parcelas, pagamentos, notificacoes) num unico payload. O `HttpSalesRepository` chama isso no boot do app e usa para hidratar o estado em memoria. Resposta:

```json
{
  "hoje": "2026-05-09T00:00:00",
  "clientes": [ { "id": "...", "nome": "...", "telefone": "...", "score": 0, "status": "...", "emAberto": 0.0, "totalCompras": 0, "parcelasAtraso": 0, "totalComprado": 0.0, "syncStatus": "synced" } ],
  "produtos": [ { "id": "...", "nome": "...", "categoria": "...", "precoBase": 0.0, "custo": 0.0, "estoque": 0, "estoqueMinimo": 1, "volumeMl": 100, "frascoColorValue": 4285558395, "tem3D": false, "modelo3DPath": null, "previewImg": null, "syncStatus": "synced" } ],
  "vendas": [ ... ],
  "parcelas": [ ... ],
  "pagamentos": [ ... ],
  "notificacoes": [ ... ]
}
```

### `POST /sales/products`

Cria um produto novo. Body:

```json
{
  "nome": "Empire Sport 100ml",
  "categoria": "Perfume",
  "precoBase": 199.90,
  "custo": 80.0,
  "estoque": 12,
  "estoqueMinimo": 2,
  "volumeMl": 100,
  "frascoColorValue": 4292216955
}
```

Resposta `201 Created` com o `ProdutoOut` completo.

### `PATCH /sales/products/{produtoId}/stock`

Ajusta estoque. Body:

```json
{ "mode": "add", "quantity": 5 }
```

`mode` aceita `"add"` (incrementa) ou `"set"` (substitui). Resposta `200` com o produto atualizado, ou `404` se inexistente.

### `POST /sales/sales`

Registra uma venda completa (cabecalho + itens, parcelas geradas no backend). Body:

```json
{
  "clienteId": "...",
  "data": "2026-05-09T14:30:00",
  "itens": [
    { "produtoId": "...", "quantidade": 1, "precoUnitario": 199.90 }
  ],
  "total": 199.90,
  "entrada": 50.0,
  "numParcelas": 3,
  "observacoes": null
}
```

Resposta `201 Created`:

```json
{ "id": "<uuid-da-venda>" }
```

Erros de regra de negocio (cliente inativo, estoque insuficiente, total inconsistente) retornam `422` com mensagem do `ValidationError` do backend.

### Sincronizacao e fallback

A arquitetura real do `SalesController` ([sales_repository.dart:21](../lib/features/sales/data/sales_repository.dart)):

1. **Boot**: parte do snapshot `MockSalesRepository` (dados de exemplo), tenta `_restore()` do `localStorage` (`perfume_3d_sales_snapshot_v2`), e dispara `_loadRemote()` para sobrescrever com `GET /sales/snapshot`.
2. **Escrita local imediata**: cada acao do usuario (criar produto, ajustar estoque, confirmar venda) atualiza o `StateNotifier` e o `localStorage` *antes* de chamar a API.
3. **Sincronizacao best-effort**: depois da escrita local, dispara `_createRemoteProduct` / `_syncRemoteStock` / `_createRemoteSale`. Se a chamada Dio falhar (timeout 900ms / 3s, `SocketException`, etc), o `try/catch` engole o erro silenciosamente. **Nao ha outbox nem retry**: o estado local fica dessincronizado do backend ate o proximo `_loadRemote()` bem-sucedido.
4. **`_isRemoteId` / `_canSyncSale`**: produtos criados offline tem id local (`p<n>`) e *nao* sincronizam ate o backend devolver um id remoto via `_loadRemote()`. Vendas com itens contendo apenas ids locais sao puladas pelo `_canSyncSale`.

Implicacoes praticas:

- Apos o backend voltar a responder, o `_loadRemote()` do proximo boot **sobrescreve** o estado local — escritas feitas offline que nao foram sincronizadas sao **perdidas** (exceto se ja tinham id remoto).
- Para um MVP de TCC isso e aceitavel. Producao real exigiria outbox + reconciliacao.

Detalhes em [18 - Feature `sales`](18-feature-sales.md).

## Proxima leitura

- Upload no front: [09 - Feature `product_capture`](09-feature-product-capture.md).
- Polling: [10 - Feature `processing`](10-feature-processing.md).
- Modulo comercial: [18 - Feature `sales`](18-feature-sales.md).
- Contrato no backend: [`13 - Endpoints HTTP`](../../back/docs/13-endpoints-http.md), [`12 - Armazenamento e banco`](../../back/docs/12-armazenamento-e-banco.md).
