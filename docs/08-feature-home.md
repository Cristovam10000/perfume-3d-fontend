# 08 — Feature `home`

A feature `home` é a mais simples do app e serve bem como introdução ao padrão Feature-First: ela não tem `domain/`, `data/` nem `state/` porque **não precisa**. É uma tela estática com um botão de ação.

## Estrutura

```
lib/features/home/
└── presentation/
    └── home_page.dart
```

Só isso. Quando uma feature não mantém estado, não faz requests e não tem modelos de domínio, as subpastas simplesmente não existem. O padrão Clean Architecture não obriga criar pastas vazias — ele pede que *se existirem* dependências, elas fluam nas direções corretas.

## `home_page.dart`

[lib/features/home/presentation/home_page.dart](../lib/features/home/presentation/home_page.dart) é um `StatelessWidget`:

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Perfume 3D MVP',
      body: Column(
        children: [
          // Branding / hero
          // 3 InstructionCards em "como funciona"
          // PrimaryButton: "Iniciar captura" → captureIntroName
          // Botão desabilitado: "Histórico (em breve)"
        ],
      ),
    );
  }
}
```

Componentes consumidos:

- **`AppScaffold`** ([lib/shared/widgets/app_scaffold.dart](../lib/shared/widgets/app_scaffold.dart)): o wrapper padrão do app com `AppBar` e `SafeArea`.
- **`InstructionCard`** ([lib/shared/widgets/instruction_card.dart](../lib/shared/widgets/instruction_card.dart)): card com ícone, título e descrição. Usado aqui para os três cards de "como funciona":
  1. "Capture várias fotos" — ícone de câmera.
  2. "Envie para processamento" — ícone de upload.
  3. "Visualize em 3D" — ícone de cubo.
- **`PrimaryButton`** ([lib/shared/widgets/primary_button.dart](../lib/shared/widgets/primary_button.dart)): botão preenchido com tamanho generoso.

## Navegação

O único botão ativo chama:

```dart
onPressed: () => context.goNamed(AppRoutes.captureIntroName),
```

Note o uso de `goNamed` (constante do `AppRoutes`) em vez de `go('/capture/intro')` — evita strings mágicas. O botão "Histórico (em breve)" está presente como *placeholder* de funcionalidade planejada:

```dart
PrimaryButton(
  label: 'Histórico (em breve)',
  onPressed: null, // desabilita visualmente
),
```

Quando o projeto evoluir para ter histórico de capturas, esse botão fica pronto para receber o handler.

## Por que `StatelessWidget` e não `ConsumerWidget`

A home não observa nenhum provider — não precisa do `ref`. Usar `StatelessWidget` deixa claro que é uma tela "burra", o que é um sinal positivo de baixa complexidade. Se no futuro ela precisar, por exemplo, mostrar "Último modelo gerado há 2 dias" (consumindo um hipotético `lastJobProvider`), basta promover para `ConsumerWidget`.

## Tema e responsividade

Como toda a UI, herda o tema de [app_theme.dart](../lib/app/theme/app_theme.dart) — cores, botões e cards vêm do Material 3. Não há lógica de layout responsiva específica: a coluna com os cards funciona bem tanto em retrato quanto em paisagem dentro do escopo dos dispositivos alvo (Android físicos, e secundariamente tablets).

## Para onde ir agora

- A próxima tela na jornada, agora com três camadas completas: [09 — Feature `product_capture`](09-feature-product-capture.md).
- Os widgets compartilhados usados aqui: [12 — Widgets compartilhados](12-widgets-compartilhados.md).
