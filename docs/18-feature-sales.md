# 18 - Feature `sales`

`sales` e a feature principal da experiencia atual. Ela transforma o app em uma ferramenta de apoio para venda de perfumes: clientes, cobranca, catalogo, vendas parceladas e modelos 3D.

A camada de dados e **HTTP-first com fallback mock** - o `SalesController` consome `/sales/*` do backend FastAPI ([13 - Endpoints HTTP](../../back/docs/13-endpoints-http.md)) e, em offline, mantem o estado em `localStorage` + dados sementes do `MockSalesRepository`. Detalhes em [16 - Contrato do backend](16-contrato-backend.md) e na secao **Data** abaixo.

## Estrutura

```text
lib/features/sales/
  data/
    sales_repository.dart   # SalesController + MockSalesRepository + helpers JSON
    sales_local_storage.dart # wrapper SharedPreferences/localStorage
  domain/
    sales_models.dart
  presentation/
    pages/
      billing_page.dart
      client_detail_page.dart
      clients_page.dart
      home_dashboard_page.dart
      notifications_page.dart
      product_3d_page.dart
      products_page.dart
      sale_detail_page.dart
      sale_wizard_page.dart
    widgets/
      sales_widgets.dart
```

## Domain

Arquivo: [sales_models.dart](../lib/features/sales/domain/sales_models.dart).

### Enums

| Enum | Valores | Uso |
|---|---|---|
| `ClienteStatus` | `good`, `warn`, `bad` | Saude do cliente. |
| `ParcelaStatus` | `paga`, `pendente`, `atrasada`, `parcial` | Estado da parcela. |
| `EventoTipo` | `pagamento`, `venda`, `atraso`, `remarca`, `parcial` | Linha do tempo. |
| `SyncStatus` | `synced`, `pending`, `failed` | Badge visual de sincronizacao. |
| `NotificacaoTipo` | `venceHoje`, `venceAmanha`, `atraso`, `pagamento` | Tom da notificacao. |

### Modelos

- `Cliente`: dados pessoais, score, status e valores.
- `Produto`: nome, categoria, preco, flags/URL 3D.
- `Venda`: cliente, data, itens, total, entrada e parcelas.
- `ItemVenda`: produto, quantidade e preco unitario.
- `Parcela`: vencimento, valor, status e eventos.
- `Pagamento`: pagamento realizado.
- `EventoParcela`: item da linha do tempo.
- `Notificacao`: lembrete de cobranca.
- `ParcelaResumo`: junta parcela, venda e cliente.
- `SalesSnapshot`: snapshot completo da tela comercial.

### Getters importantes

`Cliente.iniciais` cria iniciais para avatar.

`Venda.restante` calcula total menos entrada.

`Parcela.restante` calcula valor em aberto da parcela.

`SalesSnapshot` calcula:

- mapas por id;
- parcelas resumidas;
- vencimentos de hoje/amanha;
- atrasos;
- top pagadores;
- totais financeiros.

## Data

Arquivo: [sales_repository.dart](../lib/features/sales/data/sales_repository.dart).

A camada de dados e composta por tres pecas: o controller, o repositorio mock e o storage local.

### `SalesController` (`StateNotifier<SalesSnapshot>`)

Provider exposto:

```dart
final salesControllerProvider =
    StateNotifierProvider<SalesController, SalesSnapshot>((ref) {
  return SalesController(SalesLocalStorage());
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesControllerProvider);
});
```

O controller usa um `Dio` configurado com `AppConstants.backendBaseUrl` e timeouts curtos (connect 900ms, receive/send 3s) - parametros calibrados para detectar rapidamente backend offline.

**Sequencia de boot** (construtor de `SalesController`):

1. `super(MockSalesRepository().loadSnapshot())` - inicializa com dados de exemplo (6 clientes, 6 produtos, 4 vendas, 10 parcelas, 3 pagamentos, 3 notificacoes), garantindo que o app abra sem tela em branco mesmo offline.
2. `_restore()` - le o JSON do `localStorage` (chave `perfume_3d_sales_snapshot_v2`) e substitui o snapshot mockado, se houver.
3. `_loadRemote()` - dispara `GET /sales/snapshot` para o backend e, em sucesso, sobrescreve o estado local + persiste no `localStorage`. Falha silenciosa em offline.

**Acoes do usuario** seguem sempre o padrao "local-first, sync best-effort":

| Acao | Metodo no controller | Endpoint backend | Comportamento |
|---|---|---|---|
| Criar produto | `addProduct(Produto)` | `POST /sales/products` | State + localStorage atualizados imediatamente. Sync remoto e *fire-and-forget*. |
| Reabastecer | `restockProduct(id, amount)` | `PATCH /sales/products/{id}/stock` (`mode: add`) | Apenas se `_isRemoteId` aceitar o id. |
| Ajustar estoque | `adjustProductStock(id, qty)` | `PATCH /sales/products/{id}/stock` (`mode: set`) | Idem. |
| Confirmar venda | `confirmSale(Venda)` | `POST /sales/sales` | Decrementa estoque local, adiciona venda. Sync apenas se `_canSyncSale` (todos os itens com id remoto). |

**`nextProductId()`** gera ids locais incrementais (`p1`, `p2`, ...) usados ate o backend responder com um id remoto via `_loadRemote()`. Produtos com id local sao **invisiveis** para o backend - so produtos cuja existencia o backend ja confirmou recebem operacoes de PATCH.

**Limitacoes registradas** (sem outbox / sem retry):

- Apos um *write* falhar offline, nao ha re-tentativa automatica.
- Quando o backend volta online e `_loadRemote()` roda, escritas locais nao sincronizadas com id local sao **sobrescritas** pelo snapshot remoto.
- Para producao real, evoluir para outbox + reconciliacao por client-id.

### `MockSalesRepository`

Implementa `SalesRepository` com dados estaticos relativos a `DateTime.now()`. Continua sendo o ponto de entrada do estado inicial e o fallback quando o backend nao responde no boot:

- 6 clientes;
- 6 produtos (alguns com `modelo3DPath` apontando para `http://localhost:8000/files/models/...`);
- 4 vendas;
- 10 parcelas;
- 3 pagamentos;
- 3 notificacoes.

### `SalesLocalStorage`

Wrapper minimalista sobre `SharedPreferences` (ou `localStorage` no web). Expoe `read(key)` / `write(key, value)`. O snapshot e serializado para JSON via `_snapshotToJson()` antes de gravar.

## Paginas

### `HomeDashboardPage`

Rota: `/`.

Mostra:

- saudacao `Bom dia, Dona Marli`;
- card hero com `A receber este mes`;
- metricas de hoje e atraso;
- atalhos `Vender`, `Cliente`, `Capturar`, `3D`;
- vencimentos de hoje;
- atrasos;
- top pagadores;
- icone de notificacoes.

Usa `SalesScaffold(currentIndex: 0)`.

### `ClientsPage`

Rota: `/clientes`.

Recursos:

- busca por nome/telefone;
- filtros `Todos`, `Bons`, `Atencao`, `Atraso`;
- lista com avatar, bairro, compras, aberto e `SyncBadge`;
- navega para detalhe do cliente.

### `ClientDetailPage`

Rota: `/cliente/:id`.

Mostra:

- cabecalho do cliente;
- `StatusPill`;
- `ScoreRing`;
- cards de em aberto, compras, atrasos e total comprado;
- botoes `Nova venda`, telefone e chat;
- linha do tempo com vendas e parcelas.

Se o id nao existir, mostra `Cliente nao encontrado.`

### `SaleWizardPage`

Rota: `/venda/nova`.

Wizard em 4 etapas:

1. cliente;
2. produtos vendidos;
3. entrada/parcelas/observacoes;
4. revisao.

Estado local:

- `_step`;
- `_clienteId`;
- `_items`;
- `_entrada`;
- `_parcelas`;
- `_catalogExpanded`.

Ao confirmar, cria uma `Venda` com `SyncStatus.pending` e navega para `sale-detail` passando a venda por `extra`.

### `SaleDetailPage`

Rota: `/venda/:id`.

Recebe:

- venda persistida do snapshot, quando existe;
- ou `draftVenda` via `GoRouter.extra`.

Mostra:

- cliente e data;
- total, pago, restante e progresso;
- parcelas;
- itens vendidos.

Se a venda veio do wizard e ainda nao existe no snapshot, a pagina calcula parcelas draft em memoria.

### `BillingPage`

Rota: `/cobranca`.

Abas:

- Hoje;
- Amanha;
- Atraso.

Cada item usa `PaymentDueCard` e navega para o detalhe da venda.

### `ProductsPage`

Rota: `/produtos`.

Recursos:

- busca por nome/categoria;
- grid 2 colunas;
- arte de frasco desenhada em Flutter;
- badge `3D` para produtos com modelo;
- toque em produto com 3D abre `Product3DPage`.

### `Product3DPage`

Rota: `/produto/:id/3d`.

Busca o produto no snapshot e usa:

```dart
ModelViewer(src: produto.modelo3DPath)
```

Tambem mostra categoria, preco e botao `Vender`.

Se nao houver URL, mostra `Produto ainda nao tem modelo 3D.`

### `NotificationsPage`

Rota: `/notificacoes`.

Lista notificacoes mockadas com tom por tipo:

- vence hoje;
- vence amanha;
- atraso;
- pagamento.

As acoes `WhatsApp` e `Marcar lida` ainda sao placeholders.

## Widgets

Arquivo: [sales_widgets.dart](../lib/features/sales/presentation/widgets/sales_widgets.dart).

Componentes principais:

- `SalesScaffold`: app bar, padding e bottom nav comercial;
- `_SalesBottomNav`: abas Inicio, Clientes, Produtos, Cobranca e botao central de nova venda;
- `CircleIconButton`;
- `SectionHeader`;
- `MoneyText`;
- `ClienteAvatar`;
- `StatusPill`;
- `SyncBadge`;
- `PaymentDueCard`;
- `ScoreRing`.

## Rotas

| Nome | Path |
|---|---|
| `home` | `/` |
| `clients` | `/clientes` |
| `client-detail` | `/cliente/:id` |
| `sale-new` | `/venda/nova` |
| `sale-detail` | `/venda/:id` |
| `billing` | `/cobranca` |
| `products` | `/produtos` |
| `product-3d` | `/produto/:id/3d` |
| `notifications` | `/notificacoes` |

Rotas de ponte com o pipeline 3D:

| Nome | Path | Estado |
|---|---|---|
| `capture-by-product` | `/captura/:produtoId` | abre camera, ainda nao usa produto. |
| `processing-by-job` | `/processando/:jobId` | abre status, ainda nao usa jobId. |

## Testes

[test/sale_wizard_test.dart](../test/sale_wizard_test.dart) cobre:

- abrir catalogo, selecionar produto e atualizar quantidade/total;
- voltar da etapa 2 para etapa 1 e depois para Home;
- confirmar venda e abrir detalhe com cliente, parcelas e itens.

O teste usa `ProviderScope(child: PerfumeApp())`, entao valida o app real com router.

## Limitacoes atuais

- Dados nao persistem.
- `SyncStatus` e visual.
- Cadastro de cliente/produto nao implementado.
- Acoes de telefone/chat/WhatsApp sao placeholders.
- Venda criada pelo wizard existe apenas via `GoRouter.extra`.
- Captura por produto ainda nao vincula imagens ao produto.

## Proxima leitura

- Fluxos de dados: [13 - Fluxos de dados](13-fluxos-de-dados.md).
- Widgets compartilhados/comerciais: [12 - Widgets compartilhados](12-widgets-compartilhados.md).
- Roteamento: [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
