# 12 — Widgets compartilhados

A pasta [lib/shared/widgets/](../lib/shared/widgets/) reúne os componentes de UI reutilizados em múltiplas features. Cada arquivo é um widget, tipicamente stateless, sem lógica de negócio — só visual + callbacks.

O critério para um widget morar aqui (em vez de dentro de uma feature) é simples: **mais de uma feature o usa**. Se apenas a câmera usa, por exemplo, o widget fica em `features/product_capture/presentation/...`.

## `app_scaffold.dart`

[lib/shared/widgets/app_scaffold.dart](../lib/shared/widgets/app_scaffold.dart) — o wrapper padrão do app.

```dart
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
```

Usado por praticamente todas as páginas (home, review, processing, viewer). Garante `SafeArea` consistente (para não sobrepor notch e barra de navegação do Android) e um `AppBar` com o título e as ações padronizadas.

## `primary_button.dart`

[lib/shared/widgets/primary_button.dart](../lib/shared/widgets/primary_button.dart) — o botão principal do app.

```dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed; // null = desabilitado
  final IconData? icon;
  final bool loading;

  // ... build retorna ElevatedButton com estado de loading embutido
}
```

O state `loading: true` troca o label por um `CircularProgressIndicator` e desabilita o botão — usado durante upload na `CaptureReviewPage`.

Há também uma variante **`SecondaryButton`** no mesmo arquivo (ou similar), que é um `OutlinedButton` com as mesmas props. Usada quando o botão precisa ser visualmente menos proeminente (ex: "Cancelar").

## `instruction_card.dart`

[lib/shared/widgets/instruction_card.dart](../lib/shared/widgets/instruction_card.dart) — card com ícone + título + descrição.

```dart
class InstructionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  // ... build retorna Card com layout consistente
}
```

Usado na `HomePage` (3 cards de "como funciona") e na `CaptureIntroPage` (5 cards de "dicas de captura"). Centralizar o layout aqui evita duplicação e mantém consistência visual.

## `image_counter.dart`

[lib/shared/widgets/image_counter.dart](../lib/shared/widgets/image_counter.dart) — badge flutuante com contagem.

```dart
class ImageCounter extends StatelessWidget {
  final int count;
  final int max;

  // ... build: "12/24" em um Container arredondado semi-transparente
}
```

Aparece sobreposto na câmera. A cor muda conforme `count`:

- `count < AppConstants.minImages`: cinza.
- `count >= minImages && count < recommendedImages`: amarelo.
- `count >= recommendedImages`: verde.

## `quality_banner.dart`

[lib/shared/widgets/quality_banner.dart](../lib/shared/widgets/quality_banner.dart) — faixa colorida com texto.

```dart
class QualityBanner extends StatelessWidget {
  final QualityMessage message;

  // ... build: Container com cor mapeada do level (blocker=red, warning=amber, ok=green)
}
```

Usado tanto na câmera (para `LiveCaptureState.message`) quanto na revisão (para `QualityReport` da contagem de fotos). Centraliza o mapeamento `MessageLevel → Color`.

## `capture_overlay.dart`

[lib/shared/widgets/capture_overlay.dart](../lib/shared/widgets/capture_overlay.dart) — moldura de enquadramento sobreposta na câmera.

Este é o widget mais elaborado do `shared/`: usa um `CustomPainter` interno (`_FramePainter`) para desenhar 4 cantos em forma de L nas bordas de um retângulo central. Estilo parecido com apps de código QR e documentos.

```dart
class CaptureOverlay extends StatelessWidget {
  final bool isReady; // troca a cor do frame (cinza → verde)

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(
        color: isReady ? Colors.green : Colors.white,
      ),
      child: Container(),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Color color;
  const _FramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Calcula retângulo central 70% da largura, 50% da altura
    // Desenha 4 cantos com linhas de ~40 px cada
    // ...
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.color != color;
}
```

O overlay cumpre dois papéis:

1. **Guia visual**: mostra ao usuário onde o perfume deve ficar enquadrado.
2. **Feedback de readiness**: cor verde quando `isReady=true` (confirma que pode capturar), branca caso contrário.

## `image_grid.dart`

[lib/shared/widgets/image_grid.dart](../lib/shared/widgets/image_grid.dart) — grid de fotos com opção de remover cada uma.

Nome real da classe: `CapturedImageGrid`.

```dart
class CapturedImageGrid extends StatelessWidget {
  final List<CapturedImage> images;
  final void Function(String id)? onRemove;

  // ... GridView.builder com crossAxisCount=3
  // Cada item é um Image.file com um IconButton de X no canto superior direito
}
```

Usado na `CaptureReviewPage`. O callback `onRemove(id)` permite à página desconectar do controller sem que o widget precise saber de Riverpod.

## `loading_view.dart`

[lib/shared/widgets/loading_view.dart](../lib/shared/widgets/loading_view.dart) — view de carregamento padronizada.

```dart
class LoadingView extends StatelessWidget {
  final String? message;

  // ... Center com CircularProgressIndicator e Text opcional abaixo
}
```

Usada em qualquer lugar que tenha estado "carregando": `Product3dViewerPage` enquanto o modelo não chegou, `ProcessingStatusPage` enquanto o primeiro poll não retorna.

## `error_view.dart`

[lib/shared/widgets/error_view.dart](../lib/shared/widgets/error_view.dart) — view de erro padronizada.

```dart
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  // ... Center com ícone de erro, texto e botão opcional "Tentar novamente"
}
```

Usada em estados de falha: `ProcessingStatus.failed`, erro de upload, erro de carregamento do viewer.

## Por que tudo como `StatelessWidget`

Quase todos os widgets aqui são `StatelessWidget` porque **não gerenciam estado interno**. Recebem props, renderizam. Isso facilita:

- **Testes de widget** — não precisa de `pumpAndSettle` elaborado.
- **Composição** — props explícitas deixam claro o que o widget faz.
- **Performance** — o Flutter pode reutilizá-los sem recriar.

Quando fazem falta animações ou lifecycle (`initState`/`dispose`), promovem para `StatefulWidget`. Nenhum widget em `shared/` precisou disso ainda.

## Para onde ir agora

- As páginas que consomem esses widgets: [08 — Home](08-feature-home.md), [09 — Captura](09-feature-product-capture.md), [10 — Processing](10-feature-processing.md), [11 — Viewer](11-feature-product-viewer.md).
- Os fluxos visuais da jornada: [13 — Fluxos de dados](13-fluxos-de-dados.md).
