# 01 - Visao geral

## O que e o Perfume 3D MVP hoje

O **Perfume 3D MVP** e um front-end Flutter para um TCC sobre venda de perfumes com apoio de visualizacao 3D. O app atual tem duas partes:

- **Modulo comercial**: dashboard, lista de clientes, detalhes de cliente, wizard de venda, cobranca de parcelas, catalogo de produtos, notificacoes e visualizacao 3D de produtos do catalogo.
- **Modulo de captura 3D**: captura guiada de fotos, upload multipart para backend, polling de processamento e viewer final do modelo `.glb`/`.gltf`.

A primeira tela do app hoje nao e mais a `HomePage` antiga de captura. A rota `/` abre [HomeDashboardPage](../lib/features/sales/presentation/pages/home_dashboard_page.dart), dentro da feature `sales`.

## Problema que resolve

O app simula a rotina de uma vendedora de perfumes que precisa:

- acompanhar clientes e historico de compras;
- vender parcelado com controle de entrada e parcelas;
- saber quem vence hoje, amanha ou esta em atraso;
- consultar um catalogo de perfumes;
- abrir modelos 3D quando disponiveis;
- capturar novas fotos de produto para gerar um modelo 3D em backend externo.

O modulo 3D continua resolvendo o problema original do TCC: orientar um usuario leigo a capturar imagens boas o suficiente para fotogrametria, usando camera, acelerometro, analise de frame e comparacao ORB.

## Jornadas principais

### Jornada comercial

1. **Dashboard** - [HomeDashboardPage](../lib/features/sales/presentation/pages/home_dashboard_page.dart): mostra total a receber no mes, valores de hoje, atrasos, atalhos e top pagadores.
2. **Clientes** - [ClientsPage](../lib/features/sales/presentation/pages/clients_page.dart): busca por nome/telefone e filtros por status.
3. **Detalhe do cliente** - [ClientDetailPage](../lib/features/sales/presentation/pages/client_detail_page.dart): score, valores em aberto, compras e linha do tempo.
4. **Nova venda** - [SaleWizardPage](../lib/features/sales/presentation/pages/sale_wizard_page.dart): wizard em 4 etapas para cliente, itens, pagamento e revisao.
5. **Detalhe da venda** - [SaleDetailPage](../lib/features/sales/presentation/pages/sale_detail_page.dart): total, progresso de pagamento, parcelas e itens vendidos.
6. **Cobranca** - [BillingPage](../lib/features/sales/presentation/pages/billing_page.dart): abas para hoje, amanha e atraso.
7. **Produtos** - [ProductsPage](../lib/features/sales/presentation/pages/products_page.dart): grid de produtos com preco e marcador 3D.
8. **Produto 3D** - [Product3DPage](../lib/features/sales/presentation/pages/product_3d_page.dart): viewer 3D direto do catalogo mockado.
9. **Notificacoes** - [NotificationsPage](../lib/features/sales/presentation/pages/notifications_page.dart): lembretes de cobranca.

### Jornada de captura 3D

1. **Intro de captura** - [CaptureIntroPage](../lib/features/product_capture/presentation/pages/capture_intro_page.dart): orientacoes antes da camera.
2. **Camera** - [CaptureCameraPage](../lib/features/product_capture/presentation/pages/capture_camera_page.dart): preview, overlay, banners de qualidade e captura/galeria.
3. **Revisao** - [CaptureReviewPage](../lib/features/product_capture/presentation/pages/capture_review_page.dart): grid de imagens, remocao e upload.
4. **Processamento** - [ProcessingStatusPage](../lib/features/processing/presentation/pages/processing_status_page.dart): polling do backend a cada 3 segundos.
5. **Viewer final** - [Product3DViewerPage](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart): renderiza o modelo retornado pelo backend.

## Publico-alvo

- **Banca e orientador do TCC**: precisam entender a proposta, a evolucao e as decisoes tecnicas.
- **Desenvolvedor continuando o projeto**: precisa encontrar rapidamente rotas, providers, modelos e pontos de integracao.
- **Usuario simulado**: uma vendedora de perfumes que gerencia clientes, vendas parceladas e produtos com demonstracao 3D.

## Dentro do escopo atual

- App Flutter em pt-BR, com tema claro customizado.
- Dashboard comercial baseado em dados mockados.
- Modelos de dominio para clientes, produtos, vendas, parcelas, pagamentos e notificacoes.
- Wizard de venda com testes de widget.
- Catalogo com visualizacao 3D quando `modelo3DPath` existe.
- Captura guiada com camera, acelerometro e ORB.
- Upload multipart para backend local.
- Polling de status ate `completed` ou `error`.
- Viewer 3D com `model_viewer_plus`.

## Fora do escopo atual

- Persistencia local real para vendas/clientes.
- Backend comercial para `sales`.
- Login, contas e permissoes de usuario.
- Sincronizacao remota real, apesar de existir `SyncStatus` visual.
- Cadastro real de cliente/produto; alguns botoes sao placeholders.
- AR no viewer (`ar: false` no pipeline de captura).
- Cache offline de modelos 3D.
- Telemetria, crash reporting e analytics.

## Por que Flutter

Flutter permite demonstrar o app em Android, desktop e web com uma base unica. Para este projeto, os pacotes prontos reduzem o risco tecnico:

- `camera` para preview e stream de frames;
- `sensors_plus` para acelerometro;
- `opencv_dart` para ORB e matching;
- `model_viewer_plus` para `.glb`/`.gltf`;
- `flutter_riverpod` para estado e injecao de dependencias;
- `go_router` para rotas nomeadas.

## Para onde ir agora

- Mapa dos arquivos: [04 - Estrutura de pastas](04-estrutura-de-pastas.md).
- Arquitetura e providers: [05 - Arquitetura](05-arquitetura.md).
- Modulo principal atual: [18 - Feature `sales`](18-feature-sales.md).
- Pipeline 3D: [09 - Feature `product_capture`](09-feature-product-capture.md).
