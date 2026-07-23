# 18 - Feature `sales`

`sales` e a feature principal da experiencia atual. Ela transforma o app em uma ferramenta de apoio para venda de perfumes: clientes, cobranca, catalogo, vendas parceladas e modelos 3D.

A camada de dados e **offline-first**: o `SalesController` consome `/sales/*`,
mas mantem uma outbox duravel para falhas de conexao. Nao existem dados
ficticios; o cache contem somente respostas do backend e registros do usuario.

## Estrutura

```text
lib/features/sales/
  data/
    sales_repository.dart   # SalesController + outbox + helpers JSON
    sales_offline_store.dart # shared_preferences
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

A camada de dados e composta pelo controller HTTP e pelo armazenamento da outbox.

### `SalesController` (`StateNotifier<SalesSnapshot>`)

Provider exposto:

```dart
final salesControllerProvider =
    StateNotifierProvider<SalesController, SalesSnapshot>((ref) {
  return SalesController();
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesControllerProvider);
});
```

O controller usa um `Dio` configurado com `AppConstants.backendBaseUrl`, timeout
de conexao de 4 s e timeout de envio/resposta de 12 s.

**Sequencia de boot** (construtor de `SalesController`):

1. inicia com `SalesSnapshot.empty()`;
2. restaura de `shared_preferences` o ultimo snapshot real, a outbox e o mapa de IDs;
3. tenta sincronizar a outbox em ordem;
4. sem pendencias, carrega `GET /sales/snapshot`;
5. repete a sincronizacao automaticamente a cada 10 segundos.

**Acoes de escrita** aguardam o backend e propagam falhas para a tela:

| Acao | Metodo no controller | Endpoint backend | Comportamento |
|---|---|---|---|
| Criar/editar cliente | `createClient` / `updateClient` | `POST/PATCH /sales/clients` | Insere a resposta confirmada e atualiza o snapshot. |
| Criar/editar produto | `createProduct` / `updateProduct` | `POST/PATCH /sales/products` | Preco e custo obrigatorios. |
| Reabastecer/ajustar | `restockProduct` / `adjustProductStock` | `PATCH /sales/products/{id}/stock` | Usa o produto devolvido pelo backend. |
| Confirmar venda | `confirmSale` | `POST /sales/sales` | So navega ao detalhe apos `201`. |
| Receber | `receivePayment` | `POST /sales/installments/{id}/payments` | Total/parcial com `requestId` idempotente. |
| Renegociar | `renegotiateInstallment` | `PATCH /sales/installments/{id}/due-date` | Atualiza parcela e avisos. |
| Ler notificacao | `markNotificationRead` | `PATCH /sales/notifications/{id}/read` | Atualiza badge e card. |

### `SalesOfflineStore`

Wrapper sobre `shared_preferences`. Persiste um envelope JSON com:

- snapshot materializado;
- operacoes pendentes e numero de tentativas;
- mapeamento de IDs locais para IDs reais.

Clientes, produtos e vendas criados offline recebem IDs `local-*`. A fila
sincroniza primeiro suas dependencias e remapeia referencias antes de enviar
vendas, parcelas e pagamentos. `requestId` protege criacoes e recebimentos
contra duplicacao quando a resposta HTTP se perde.

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

`Nova venda` preserva o cliente atual. Telefone abre o discador com URI `tel:`;
chat abre `wa.me` com saudacao pronta, mantendo a ligacao e o envio sob controle
do usuario.

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

Ao confirmar, aguarda `POST /sales/sales`; so entao navega para o id devolvido.
O cadastro de cliente reutiliza o formulario da lista e seleciona o novo cliente.
Quando a venda nasce do detalhe de um cliente, recebe `clientId` pela rota,
preserva esse cliente e abre diretamente a etapa `O que vendeu?`.

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

O toque em `Receber` abre valor/data/forma/observacao. Os tres pontos permitem
ver/editar cliente, cobrar no WhatsApp e renegociar uma parcela aberta.

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
- cards de estoque com valor por custo (`custo x quantidade`) e potencial de venda;
- arte de frasco desenhada em Flutter;
- badge `3D` para produtos com modelo;
- cadastro/edicao com custo e preco obrigatorios;
- repor, ajustar quantidade, editar, gerar/ver/regenerar molde 3D.

### `Product3DPage`

Rota: `/produto/:id/3d`.

Busca o produto no snapshot, normaliza a URL com `BACKEND_BASE_URL` e usa:

```dart
ModelViewer(src: produto.modelo3DPath)
```

Tambem mostra categoria, preco e botao `Vender`.
O modelo anterior continua acessivel enquanto uma regeneracao esta processando.

Se nao houver URL, mostra `Produto ainda nao tem modelo 3D.`

### `NotificationsPage`

Rota: `/notificacoes`.

Lista notificacoes geradas pelo backend com tom por tipo:

- vence hoje;
- vence amanha;
- atraso;
- pagamento.

Os cards abrem a venda, iniciam a conversa no WhatsApp e podem ser marcados como
lidos. O sino mostra a contagem nao lida.

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
| `capture-by-product` | `/captura/:produtoId` | envia o produto no multipart. |
| `processing-by-job` | `/processando/:jobId` | retoma o polling e recupera `productId`. |

## Testes

[test/sale_wizard_test.dart](../test/sale_wizard_test.dart) cobre:

- abrir catalogo, selecionar produto e atualizar quantidade/total;
- voltar da etapa 2 para etapa 1 e depois para Home;
- confirmar venda e abrir detalhe com cliente, parcelas e itens.

O teste usa `ProviderScope(child: PerfumeApp())`, entao valida o app real com router.

A suite completa tem **27 testes**: wizard, cliente pre-selecionado, links de
telefone/WhatsApp, polling, recuperacao da captura, `productId`, calculo de
estoque, badge de notificacoes, persistencia offline, sincronizacao com
remapeamento de ID e fechamento seguro dos modais de reposicao/ajuste.
`flutter analyze` passa sem problemas na
verificacao de 2026-07-23.

## Limitacoes atuais

- A fila e single-tenant e nao resolve edicoes concorrentes feitas por varios dispositivos.
- Operacoes rejeitadas por regra de negocio permanecem pendentes para diagnostico; ainda nao ha uma tela dedicada para editar/remover a pendencia.
- Cancelamento de venda, exclusao de cliente e estorno nao fazem parte desta fase.
- O envio da mensagem do WhatsApp continua sob controle do usuario.

## Proxima leitura

- Fluxos de dados: [13 - Fluxos de dados](13-fluxos-de-dados.md).
- Widgets compartilhados/comerciais: [12 - Widgets compartilhados](12-widgets-compartilhados.md).
- Roteamento: [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
