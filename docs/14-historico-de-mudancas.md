# 14 - Historico de mudancas

Este historico resume a evolucao do front-end a partir dos commits locais.

## Linha do tempo

| Commit | Resumo |
|---|---|
| `c303de7` | Primeiro commit do app Flutter. |
| `63f2d07` | Adiciona OpenCV/DartCV4 e tracking por ORB/tilt. |
| `a8b85e7` | Remove `AngleTracker`/`CoverageWheel` e calibra thresholds. |
| `9bd5cc2` | Adiciona documentacao tecnica inicial. |
| `c46f1c9` | Configura tema e formatadores do app. |
| `f5ea231` | Adiciona fluxo comercial no front. |
| `650166b` | Ajusta wizard de venda e navegacao ao design. |
| `91eaaaa` | Atualiza base URL do backend local. |

## Fase 1 - MVP de captura 3D

O app nasceu como um fluxo linear:

```text
Home -> Intro -> Camera -> Review -> Processing -> Viewer
```

O objetivo era demonstrar a captura guiada de imagens para reconstrucao 3D de um frasco de perfume.

## Fase 2 - Pivot tecnico da captura

A abordagem antiga tentava medir cobertura angular pelo movimento do aparelho. Isso evoluiu para:

- `FrameAnalyzer` para brilho/nitidez/saturacao;
- `TiltTracker` para inclinacao do celular;
- `OrbSimilarityTracker` para detectar se o angulo visual ja foi capturado.

Esse pivot foi importante porque o resultado visual do frame e mais relevante do que confiar apenas em sensor inercial.

## Fase 3 - Tema e formatadores

O commit `c46f1c9` iniciou a camada visual atual:

- `AppColors`, `AppRadius`, `AppSpacing`;
- `AppTheme.light()`;
- fonte Plus Jakarta Sans via `google_fonts`;
- `AppFormatters` com moeda/data pt-BR.

Isso preparou o app para uma experiencia mais proxima de produto, nao apenas demo tecnica.

## Fase 4 - Modulo comercial

O commit `f5ea231` adicionou a maior mudanca de produto: a feature `sales`.

Entraram:

- dashboard financeiro;
- clientes e detalhe de cliente;
- wizard de venda;
- detalhe de venda;
- cobranca;
- produtos;
- viewer 3D de produto;
- notificacoes;
- mock repository com `SalesSnapshot` (implementacao historica, removida na fase atual).

A rota inicial `/` passou a abrir `HomeDashboardPage`.

## Fase 5 - Ajustes de UX e testes

O commit `650166b` alinhou o wizard e a navegacao ao design atual. O teste [sale_wizard_test.dart](../test/sale_wizard_test.dart) cobre selecao de produto, quantidade, voltar no wizard e detalhe gerado por venda draft.

## Fase 6 - Backend local

O commit `91eaaaa` mudou `AppConstants.backendBaseUrl` para:

```dart
http://192.168.0.3:8000
```

Isso reflete uso com aparelho fisico na mesma rede local.

## Estado atual da documentacao

Esta revisao dos docs considera o codigo atual da arvore de trabalho, incluindo o modulo `sales` como experiencia principal e o pipeline de captura como modulo especializado.

## Fase 7 - Remocao da massa ficticia

O repositorio mock e todos os clientes, produtos, vendas e URLs 3D ficticios
foram removidos do codigo de producao.

## Fase 8 - Operacao comercial offline-first

O app passou a persistir em `shared_preferences` somente dados reais e registros
criados pelo usuario. Falhas de conexao entram em uma outbox duravel, sincronizada
em ordem a cada 10 segundos. IDs locais de cliente, produto, venda e parcela sao
remapeados para os IDs do PostgreSQL. A geracao 3D permanece online-only.

## Proximos passos naturais

- Persistir automaticamente o job ativo para retomar o acompanhamento depois
  de o aplicativo ser encerrado.
- Acrescentar uma tela dedicada de diagnostico e resolucao de conflitos da outbox.
- Adicionar permissoes nativas formais para camera/galeria antes de release.
