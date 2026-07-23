# Documentacao tecnica - `perfume_3d_mvp`

Esta pasta descreve o estado atual do front-end Flutter em `C:\TCC\perfume-3d-frontend`.

O projeto evoluiu: ele nao e mais apenas uma jornada linear de captura 3D. A tela inicial atual e um painel comercial para venda de perfumes, com clientes, cobrancas, produtos, notificacoes, wizard de venda e visualizacao 3D de produtos. O fluxo antigo de captura, upload, processamento e viewer 3D continua no codigo como modulo especializado.

## Ordem sugerida de leitura

1. [01 - Visao geral](01-visao-geral.md): o que o app faz hoje.
2. [04 - Estrutura de pastas](04-estrutura-de-pastas.md): mapa dos arquivos atuais.
3. [05 - Arquitetura](05-arquitetura.md): camadas, providers e responsabilidades.
4. [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md): inicializacao, tema e rotas.
5. [18 - Feature `sales`](18-feature-sales.md): modulo principal da experiencia atual.
6. [09 - Feature `product_capture`](09-feature-product-capture.md), [10 - `processing`](10-feature-processing.md) e [11 - `product_viewer`](11-feature-product-viewer.md): pipeline 3D.
7. [16 - Contrato do backend](16-contrato-backend.md): endpoints usados pelo pipeline de captura.

## Indice completo

| # | Documento | Assunto |
|---|---|---|
| 01 | [Visao geral](01-visao-geral.md) | Produto atual, jornadas e escopo. |
| 02 | [Stack tecnologico](02-stack-tecnologico.md) | Dependencias, SDKs e uso de cada pacote. |
| 03 | [Inicializacao do projeto](03-inicializacao-do-projeto.md) | Como preparar, rodar e testar. |
| 04 | [Estrutura de pastas](04-estrutura-de-pastas.md) | Arvore atual de `lib/` e `test/`. |
| 05 | [Arquitetura](05-arquitetura.md) | Feature-first, Riverpod, rotas e estado. |
| 06 | [Bootstrap e roteamento](06-bootstrap-e-roteamento.md) | `main`, `MaterialApp.router`, tema e `GoRouter`. |
| 07 | [Camada `core`](07-camada-core.md) | Constantes, Dio, formatadores e algoritmos. |
| 08 | [Feature `home`](08-feature-home.md) | Home antiga de captura, hoje fora da rota inicial. |
| 09 | [Feature `product_capture`](09-feature-product-capture.md) | Captura guiada com camera, sensores e ORB. |
| 10 | [Feature `processing`](10-feature-processing.md) | Polling de processamento do backend. |
| 11 | [Feature `product_viewer`](11-feature-product-viewer.md) | Viewer 3D final do pipeline de captura. |
| 12 | [Widgets compartilhados](12-widgets-compartilhados.md) | Componentes comuns e widgets de vendas. |
| 13 | [Fluxos de dados](13-fluxos-de-dados.md) | Como dados passam pelo app. |
| 14 | [Historico de mudancas](14-historico-de-mudancas.md) | Evolucao do front por commits. |
| 15 | [Configuracao de plataformas](15-configuracao-de-plataformas.md) | Android, iOS, Web e Desktop. |
| 16 | [Contrato do backend](16-contrato-backend.md) | API esperada para captura e processamento. |
| 17 | [Glossario](17-glossario.md) | Termos do dominio, Flutter, CV e vendas. |
| 18 | [Feature `sales`](18-feature-sales.md) | Dashboard, clientes, vendas, cobranca e produtos. |

## Convencoes

- Caminhos sao relativos a raiz do repositorio `perfume-3d-frontend/`.
- O codigo Dart e a fonte canonica; quando houver divergencia, atualize os docs.
- A feature `sales` inicia com dados de demonstracao, restaura o snapshot local quando disponivel e tenta sincronizar com `/sales/*`; se o backend falhar, continua com o estado local/mockado.
- A documentacao evita prometer comportamento que ainda nao existe: cadastro real, persistencia, autenticacao e sincronizacao remota estao fora do estado atual.

## Como manter

Ao mudar uma rota, provider, modelo ou dependencia, atualize pelo menos:

- [04 - Estrutura de pastas](04-estrutura-de-pastas.md), se arquivos mudarem.
- [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md), se rotas mudarem.
- [05 - Arquitetura](05-arquitetura.md), se providers/responsabilidades mudarem.
- O documento da feature afetada.
