# 08 - Feature `home`

## Estado atual

`features/home` ainda existe, mas nao e mais a home inicial do aplicativo.

Arquivo:

```text
lib/features/home/presentation/home_page.dart
```

A rota `/` hoje aponta para [HomeDashboardPage](../lib/features/sales/presentation/pages/home_dashboard_page.dart). A `HomePage` antiga ficou como tela simples do fluxo original de captura 3D.

## `home_page.dart`

[home_page.dart](../lib/features/home/presentation/home_page.dart) e um `StatelessWidget` com:

- titulo `Perfume 3D`;
- subtitulo de captura/visualizacao;
- tres `InstructionCard`s:
  - captura guiada;
  - processamento externo;
  - visualizacao 3D;
- `PrimaryButton` para `AppRoutes.captureIntroName`;
- botao desabilitado `Historico (em breve)`.

## Quando usar

Ela ainda pode ser util se o projeto quiser voltar para uma demo focada apenas na captura 3D. Para isso, bastaria alterar o builder da rota `home` em [app_router.dart](../lib/app/router/app_router.dart):

```dart
builder: (_, __) => const HomePage(),
```

No estado atual, a tela correta para documentar a home do app e [18 - Feature `sales`](18-feature-sales.md), porque `HomeDashboardPage` representa a experiencia principal.

## Dependencias

`HomePage` depende apenas de:

- `go_router`;
- `AppRoutes`;
- `InstructionCard`;
- `PrimaryButton`.

Nao tem repository, controller nem provider proprio.

## Proxima leitura

- Home atual: [18 - Feature `sales`](18-feature-sales.md).
- Roteamento: [06 - Bootstrap e roteamento](06-bootstrap-e-roteamento.md).
