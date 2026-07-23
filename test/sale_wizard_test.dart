import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:perfume_3d_mvp/app/app.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_repository.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';
import 'package:perfume_3d_mvp/features/sales/presentation/pages/sale_wizard_page.dart';

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

  testWidgets('confirmar venda abre detalhe com cliente, parcelas e itens',
      (tester) async {
    await _openWizardStep2(tester);

    await tester.tap(find.byKey(const ValueKey('toggle-product-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-product-p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar venda'));
    await tester.pumpAndSettle();

    expect(find.text('Venda #005'), findsOneWidget);
    expect(find.text('Dona Marta Oliveira'), findsOneWidget);
    expect(find.text('PARCELAS'), findsOneWidget);
    expect(find.textContaining('3x'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ITENS VENDIDOS'), 500);
    await tester.pumpAndSettle();

    expect(find.text('ITENS VENDIDOS'), findsOneWidget);
    expect(find.text('Lattafa Khamrah'), findsOneWidget);
  });

  testWidgets('nova venda do detalhe preserva cliente e pula primeira etapa',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesControllerProvider.overrideWith((ref) => _TestSalesController()),
        ],
        child: const MaterialApp(
          home: SaleWizardPage(initialClientId: 'c2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2. O QUE VENDEU?'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sale-client-c2-selected')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salesControllerProvider.overrideWith((ref) => _TestSalesController()),
      ],
      child: const PerfumeApp(),
    ),
  );
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

class _TestSalesController extends SalesController {
  _TestSalesController() : super(autoLoad: false) {
    state = _salesTestSnapshot();
  }

  @override
  Future<Venda> confirmSale(Venda sale) async {
    final confirmed = sale.copyWith(
      id: '005',
      syncStatus: SyncStatus.synced,
    );
    state = state.copyWith(vendas: [...state.vendas, confirmed]);
    return confirmed;
  }
}

SalesSnapshot _salesTestSnapshot() {
  final today = DateTime.now();
  return SalesSnapshot(
    hoje: DateTime(today.year, today.month, today.day),
    clientes: const [
      Cliente(
        id: 'c1',
        nome: 'Dona Marta Oliveira',
        telefone: '(11) 98876-2310',
        bairro: 'Vila Madalena',
        score: 92,
        status: ClienteStatus.good,
        emAberto: 0,
        totalCompras: 12,
        parcelasAtraso: 0,
        totalComprado: 320,
      ),
      Cliente(
        id: 'c2',
        nome: 'Junior Alves',
        telefone: '(11) 97731-0021',
        bairro: 'Centro',
        score: 74,
        status: ClienteStatus.warn,
        emAberto: 240,
        totalCompras: 4,
        parcelasAtraso: 1,
        totalComprado: 1180,
      ),
    ],
    produtos: const [
      Produto(
        id: 'p1',
        nome: 'Lattafa Khamrah',
        categoria: 'Arabe doce',
        precoBase: 320,
        custo: 180,
        estoque: 8,
        estoqueMinimo: 1,
        volumeMl: 100,
        frascoColorValue: 0xFFCB3E7B,
        tem3D: false,
      ),
    ],
    vendas: const [],
    parcelas: const [],
    pagamentos: const [],
    notificacoes: const [],
  );
}
