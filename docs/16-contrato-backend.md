# 16 - Contrato do backend

O backend cobre dois domínios:

1. **Captura/processamento 3D** (`/captures/*`, `/files/*`) - sempre via HTTP.
2. **Operação comercial** (`/sales/*`) - usado pelo `SalesController`; falhas de conexão são persistidas em uma outbox, sem dados mockados.

Os dois dominios usam a mesma URL de [AppConstants](../lib/core/constants/app_constants.dart). Captura/processamento usa o `dioClientProvider`; vendas cria um cliente Dio proprio com timeouts curtos e fallback local.

## Base URL

Fonte: [AppConstants.backendBaseUrl](../lib/core/constants/app_constants.dart).

```dart
static const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
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
| `views` | string repetida, opcional | Rotulos paralelos: `front`, `left`, `back`, `right` ou `extra`. |
| `productId` | inteiro, opcional | Produto comercial ao qual o GLB concluido deve ser vinculado. |

O front monta:

```dart
final formMap = <String, dynamic>{
  'images': [
    for (final f in images)
      await MultipartFile.fromFile(f.path, filename: f.uri.pathSegments.last),
  ],
};
if (views != null && views.isNotEmpty) {
  formMap['views'] = views;
}
if (productId != null) {
  formMap['productId'] = productId;
}
final formData = FormData.fromMap(formMap);
```

Quando `views` e enviado, precisa ter o mesmo tamanho de `images`. Sem rotulos, o backend tenta classificar as vistas automaticamente.

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
  "productId": 42,
  "error": null
}
```

Campos:

| Campo | Tipo | Obrigatorio | Descricao |
|---|---|---|---|
| `status` | string | recomendado | Estado do job. |
| `message` | string/null | nao | Mensagem amigavel. |
| `modelUrl` | string/null | quando completo | URL do modelo 3D. |
| `productId` | inteiro/null | nao | Recupera o produto vinculado ao job. |
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
  "modelUrl": "/files/models/job-abc123.glb",
  "productId": 42,
  "error": null
}
```

## Modelos 3D do catalogo

Produtos recebidos de `/sales/snapshot` podem ter `modelo3DPath` relativo ou absoluto.

Antes de chegar ao `ModelViewer`, URLs relativas sao resolvidas com
`BACKEND_BASE_URL`; hosts `localhost`/`127.0.0.1` tambem sao trocados pelo host
configurado. Assim o aparelho fisico usa o IP da maquina.

## Autenticacao

Nao ha autenticacao no front atual. Todas as chamadas presumem backend local anonimo.

## Backend comercial - `/sales/*`

Usado pelo `SalesController` em [sales_repository.dart](../lib/features/sales/data/sales_repository.dart). O fallback offline guarda somente dados reais e operações do usuário. Todos os payloads usam camelCase convertido pelo Pydantic do backend.

### `GET /sales/snapshot`

Devolve o estado completo (clientes, produtos, vendas, parcelas, pagamentos, notificacoes) num unico payload. O `SalesController` chama isso no boot do app e usa a resposta para hidratar e persistir o estado disponivel. Resposta:

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

`precoBase` e `custo` precisam ser maiores que zero.

### Clientes e edicao comercial

- `POST /sales/clients`: cria nome, telefone e bairro.
- `PATCH /sales/clients/{id}`: edita os mesmos campos.
- `PATCH /sales/products/{id}`: edita os dados comerciais; estoque permanece
  no endpoint especifico.

### `PATCH /sales/products/{produtoId}/stock`

Ajusta estoque. Body:

```json
{ "mode": "add", "quantity": 5 }
```

`mode` aceita `"add"` (incrementa) ou `"set"` (substitui). Resposta `200` com o produto atualizado, ou `404` se inexistente.

### Recebimento, renegociacao e notificacoes

- `POST /sales/installments/{id}/payments`: valor, data, forma, observacao e
  `requestId`; aceita total/parcial e impede excesso ou duplicidade.
- `PATCH /sales/installments/{id}/due-date`: altera parcela aberta e reagenda
  seus avisos.
- `PATCH /sales/notifications/{id}/read`: marca a notificacao como lida.

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

O boot restaura o snapshot real e a outbox, tenta enviar as pendencias em ordem
e depois carrega `GET /sales/snapshot`. Em falha de conexao:

1. a alteração aparece com `SyncStatus.pending`;
2. snapshot, operação e IDs locais são gravados em `shared_preferences`;
3. o controller tenta novamente a cada 10 segundos;
4. clientes e produtos são sincronizados antes das vendas que os referenciam;
5. ao receber os IDs do PostgreSQL, todas as referências locais são remapeadas.

Criações de cliente, produto e venda, renegociações e pagamentos enviam
`requestId`. O backend mantém chaves únicas para que repetir uma operação não
duplique registros. A captura/modelagem 3D não entra na outbox.

Detalhes em [18 - Feature `sales`](18-feature-sales.md).

## Proxima leitura

- Upload no front: [09 - Feature `product_capture`](09-feature-product-capture.md).
- Polling: [10 - Feature `processing`](10-feature-processing.md).
- Modulo comercial: [18 - Feature `sales`](18-feature-sales.md).
- Contrato no backend: [`13 - Endpoints HTTP`](../../perfume-3d-backend/docs/13-endpoints-http.md), [`12 - Armazenamento e banco`](../../perfume-3d-backend/docs/12-armazenamento-e-banco.md).
