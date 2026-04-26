# 12 - Widgets compartilhados

## `shared/widgets`

Widgets realmente compartilhados e independentes de dominio ficam em `lib/shared/widgets`.

### `AppScaffold`

Scaffold simples usado principalmente no pipeline de captura/processamento/viewer.

Props:

- `title`;
- `body`;
- `bottomBar`;
- `actions`;
- `showBack`.

Ele cria `AppBar`, `SafeArea` no corpo e padding padrao para `bottomBar`.

### `PrimaryButton` e `SecondaryButton`

Wrappers sobre `FilledButton` e `OutlinedButton`.

`PrimaryButton` aceita:

- `label`;
- `icon`;
- `loading`;
- `onPressed`.

Quando `loading == true`, mostra `CircularProgressIndicator` e desabilita o clique.

### `InstructionCard`

Card com icone, titulo e descricao. Usado na `HomePage` antiga e na intro de captura.

### `ImageCounter`

Mostra progresso de imagens capturadas:

- `count / AppConstants.recommendedImages`;
- label de minimo atingido ou minimo necessario;
- `LinearProgressIndicator`.

### `QualityBanner`

Renderiza `QualityMessage` com cor e icone baseados em `QualityLevel`:

- `ok`: secundario;
- `warning`: terciario;
- `blocker`: erro.

### `CaptureOverlay`

Overlay de camera com `CustomPainter`:

- retangulo central;
- cantos destacados;
- hint opcional no rodape.

### `CapturedImageGrid`

Grid 3 colunas para `List<File>`, com botao de remover quando `onRemove` nao e nulo.

### `LoadingView`

Centro com `CircularProgressIndicator` e mensagem opcional.

### `ErrorView`

Estado de erro padrao com icone, titulo, mensagem e botao opcional de retry.

## Widgets de vendas

Os widgets comerciais ficam em [features/sales/presentation/widgets/sales_widgets.dart](../lib/features/sales/presentation/widgets/sales_widgets.dart), nao em `shared`, porque conhecem modelos e regras de vendas.

Principais:

| Widget | Uso |
|---|---|
| `SalesScaffold` | Scaffold com app bar e bottom navigation comercial. |
| `CircleIconButton` | Botoes circulares de acao. |
| `SectionHeader` | Titulo de secao com acao opcional. |
| `MoneyText` | Moeda pt-BR com `AppFormatters.brl`. |
| `ClienteAvatar` | Avatar por iniciais e cor de status. |
| `StatusPill` | Status do cliente. |
| `SyncBadge` | Marcador visual de local/falhou. |
| `PaymentDueCard` | Card de parcela a cobrar. |
| `ScoreRing` | Indicador circular do score do cliente. |

Funcoes auxiliares:

- `statusColor`;
- `statusSoftColor`;
- `statusLabel`.

## Criterio

Promova um widget para `shared/widgets` apenas se ele nao depender de modelos de uma feature. Caso ele precise de `Cliente`, `ParcelaResumo`, `Produto` ou `Venda`, mantenha dentro de `features/sales`.

## Proxima leitura

- Widgets comerciais em contexto: [18 - Feature `sales`](18-feature-sales.md).
- Captura usando widgets shared: [09 - Feature `product_capture`](09-feature-product-capture.md).
