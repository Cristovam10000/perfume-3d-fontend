# 18 - Feature `sales`

`sales` e a feature principal da experiencia atual. Ela transforma o app em uma ferramenta de apoio para venda de perfumes: clientes, cobranca, catalogo, vendas parceladas e modelos 3D.

## Estrutura

```text
lib/features/sales/
  data/
    sales_repository.dart
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

Providers:

```dart
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return MockSalesRepository();
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesRepositoryProvider).loadSnapshot();
});
```

`MockSalesRepository` monta dados relativos a `DateTime.now()`:

- 6 clientes;
- 6 produtos;
- 4 vendas;
- 10 parcelas;
- 3 pagamentos;
- 3 notificacoes.

Alguns produtos tem `modelo3DPath` apontando para backend local/demo.

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
