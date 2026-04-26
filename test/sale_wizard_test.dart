import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:perfume_3d_mvp/app/app.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Intl.defaultLocale = 'pt_BR';
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('abre catalogo, seleciona produto e atualiza quantidade/total',
      (tester) async {
    await _openWizardStep2(tester);

    expect(find.byKey(const ValueKey('selected-product-p1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-product-catalog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('catalog-product-p1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-product-p1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selected-product-p1')), findsOneWidget);
    expect(find.textContaining('320,00 cada'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quantity-plus-p1')));
    await tester.pumpAndSettle();

    final quantity = tester.widget<Text>(
      find.byKey(const ValueKey('quantity-value-p1')),
    );
    expect(quantity.data, '2');
    expect(find.textContaining('640,00'), findsOneWidget);
  });

  testWidgets('botao voltar retorna etapa e depois volta para a Home',
      (tester) async {
    await _openWizardStep2(tester);

    expect(find.text('2. O QUE VENDEU?'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('1. QUEM COMPROU?'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Bom dia,'), findsOneWidget);
    expect(find.text('Nova venda'), findsNothing);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: PerfumeApp()));
  await tester.pumpAndSettle();
}

Future<void> _openWizardStep2(WidgetTester tester) async {
  await _pumpApp(tester);

  await tester.tap(find.text('Vender').first);
  await tester.pumpAndSettle();

  expect(find.text('Nova venda'), findsOneWidget);

  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}
