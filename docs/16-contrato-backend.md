# 16 - Contrato do backend

O backend e usado apenas pelo pipeline de captura/processamento 3D. O modulo comercial `sales` usa `MockSalesRepository` local e nao faz chamadas HTTP.

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

## Backend comercial

Ainda nao existe contrato para:

- clientes;
- produtos;
- vendas;
- parcelas;
- pagamentos;
- notificacoes;
- sincronizacao.

Quando essa API existir, o primeiro ponto de troca sera `MockSalesRepository`.

## Proxima leitura

- Upload no front: [09 - Feature `product_capture`](09-feature-product-capture.md).
- Polling: [10 - Feature `processing`](10-feature-processing.md).
- Modulo comercial mockado: [18 - Feature `sales`](18-feature-sales.md).
