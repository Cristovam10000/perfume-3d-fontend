# Documentação técnica — `perfume_3d_mvp`

Bem-vindo. Esta pasta reúne a documentação técnica completa do aplicativo **Perfume 3D MVP**, um projeto acadêmico (TCC) em Flutter que captura imagens guiadas de um perfume, envia para um backend que gera um modelo 3D, e apresenta esse modelo ao usuário para rotação e zoom.

A documentação é pensada para quem **nunca viu o projeto** — cada página explica o *o quê*, o *por quê* e o *como*, com referências diretas ao código. Tudo está em português brasileiro, seguindo a convenção do restante do projeto.

## Ordem sugerida de leitura

Para quem está entrando agora:

1. [01 — Visão geral](01-visao-geral.md): contexto, jornada do usuário, escopo do MVP.
2. [05 — Arquitetura](05-arquitetura.md): como o código está organizado em camadas.
3. [04 — Estrutura de pastas](04-estrutura-de-pastas.md): mapa de cada arquivo em `lib/`.
4. [06 — Bootstrap e roteamento](06-bootstrap-e-roteamento.md): como o app sobe e navega.
5. [09 — Feature de captura](09-feature-product-capture.md): o coração do app, onde tudo acontece.
6. Demais arquivos conforme a necessidade.

## Índice completo

| # | Arquivo | Conteúdo |
|---|---|---|
| 01 | [Visão geral](01-visao-geral.md) | Objetivo, jornada do usuário, escopo do MVP. |
| 02 | [Stack tecnológico](02-stack-tecnologico.md) | Todas as dependências do [pubspec.yaml](../pubspec.yaml) com justificativa. |
| 03 | [Inicialização do projeto](03-inicializacao-do-projeto.md) | Como o projeto foi criado e como rodá-lo. |
| 04 | [Estrutura de pastas](04-estrutura-de-pastas.md) | Árvore de `lib/` com papel de cada arquivo. |
| 05 | [Arquitetura](05-arquitetura.md) | Clean Architecture + Feature-First + Riverpod. |
| 06 | [Bootstrap e roteamento](06-bootstrap-e-roteamento.md) | `main.dart`, `app.dart`, rotas, guards, tema. |
| 07 | [Camada `core/`](07-camada-core.md) | Constantes, exceptions, Dio, utilitários (frame, tilt, ORB, qualidade). |
| 08 | [Feature `home`](08-feature-home.md) | Tela inicial. |
| 09 | [Feature `product_capture`](09-feature-product-capture.md) | Captura guiada com feedback ao vivo. |
| 10 | [Feature `processing`](10-feature-processing.md) | Polling do status do job no backend. |
| 11 | [Feature `product_viewer`](11-feature-product-viewer.md) | Visualizador 3D. |
| 12 | [Widgets compartilhados](12-widgets-compartilhados.md) | Componentes reutilizáveis de UI. |
| 13 | [Fluxos de dados](13-fluxos-de-dados.md) | Diagramas textuais dos três fluxos principais. |
| 14 | [Histórico de mudanças](14-historico-de-mudancas.md) | Narrativa dos 3 commits e o pivot walk-around → ORB. |
| 15 | [Configuração de plataformas](15-configuracao-de-plataformas.md) | Android, iOS, demais plataformas. |
| 16 | [Contrato do backend](16-contrato-backend.md) | Endpoints que o app consome. |
| 17 | [Glossário](17-glossario.md) | ORB, Laplaciano, YUV420, Lowe's ratio, etc. |

## Convenções desta documentação

- **Idioma**: português brasileiro, mesmo para termos técnicos sempre que existir tradução estabelecida. Jargões em inglês ficam em *itálico* e aparecem definidos no [glossário](17-glossario.md).
- **Referências a código**: usamos markdown clicável no formato `[nome-do-arquivo](../caminho/arquivo.dart)` — relativo à raiz do repositório. Quando apontamos para uma linha específica, adicionamos `#Lnumero`.
- **Trechos de código**: colamos o mínimo necessário para ilustrar. Para entender o código completo, o link levará você ao arquivo real.
- **Tempo verbal**: tudo escrito no presente, como documentação "viva" do estado atual do código. O único lugar onde descrevemos o passado é [14 — Histórico de mudanças](14-historico-de-mudancas.md).
- **Arquivos deletados** (ex.: `angle_tracker.dart`, `coverage_wheel.dart` removidos no commit `a8b85e7`) são mencionados apenas em [14 — Histórico](14-historico-de-mudancas.md). Em qualquer outro lugar, presumimos o código como ele está hoje.

## Como manter esta documentação

Se você alterar um arquivo de código, atualize também o(s) arquivo(s) `.md` que descrevem ele. Os links clicáveis ajudam a fazer essa varredura: basta `grep`-ar o nome do arquivo `.dart` dentro de `docs/` para encontrar todas as menções.

Divergências entre doc e código: o código é a fonte da verdade. Ajuste a doc.
