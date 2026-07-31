import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:perfume_3d_mvp/app/app.dart';
import 'package:perfume_3d_mvp/app/router/app_router.dart';
import 'package:perfume_3d_mvp/app/router/app_routes.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_offline_store.dart';
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

  testWidgets('tres pontos do cliente abre as mesmas acoes da venda',
      (tester) async {
    await _openClientDetail(tester);

    await tester.tap(find.byKey(const ValueKey('sale-actions-button')));
    await tester.pumpAndSettle();

    expect(find.text('Editar cliente'), findsOneWidget);
    expect(find.text('Cobrar pelo WhatsApp'), findsOneWidget);
    expect(find.text('Renegociar vencimento'), findsOneWidget);
    // Ja estamos na tela do cliente.
    expect(find.text('Ver cliente'), findsNothing);
  });

  testWidgets('venda da linha do tempo abre a visualizacao, nao o wizard',
      (tester) async {
    await _openClientDetail(tester);

    await tester.ensureVisible(find.text('Venda #v1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Venda #v1'));
    await tester.pumpAndSettle();

    expect(find.text('PARCELAS'), findsOneWidget);
    expect(find.text('Parcela 1/3'), findsOneWidget);
    expect(find.byType(SaleWizardPage), findsNothing);
    // A visualizacao da venda tem as mesmas acoes.
    expect(find.byKey(const ValueKey('sale-actions-button')), findsOneWidget);
  });

  testWidgets('parcela abre com o vencimento cadastrado e calendario pt-BR',
      (tester) async {
    await _openSaleDetail(tester);

    await tester.tap(find.text('Parcela 1/3'));
    await tester.pumpAndSettle();

    expect(find.text('Data do recebimento'), findsOneWidget);
    // Vencimento da parcela, nao a data de hoje.
    expect(find.text('31/01/2030'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    // Calendario traduzido e aberto numa data futura (lastDate nao limita
    // mais ao dia de hoje).
    expect(find.text('janeiro de 2030'), findsOneWidget);
    expect(find.text('qui., 31 de jan.'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('receber em data diferente oferece alterar as proximas parcelas',
      (tester) async {
    final controller = await _openSaleDetail(tester);

    await tester.tap(find.text('Parcela 1/3'));
    await tester.pumpAndSettle();

    await _pickDate(tester, '15/02/2030');
    expect(find.text('15/02/2030'), findsOneWidget);

    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();

    expect(
      find.text('Deseja alterar também as datas das parcelas seguintes?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Alterar as próximas parcelas'));
    await tester.pumpAndSettle();

    final due = {
      for (final item in controller.state.parcelas)
        item.numero: item.vencimento,
    };
    expect(due[2], DateTime(2030, 3, 15));
    expect(due[3], DateTime(2030, 4, 15));
  });

  testWidgets('manter as proximas parcelas preserva os vencimentos',
      (tester) async {
    final controller = await _openSaleDetail(tester);

    await tester.tap(find.text('Parcela 1/3'));
    await tester.pumpAndSettle();

    await _pickDate(tester, '15/02/2030');
    await tester.tap(find.text('Confirmar recebimento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manter as próximas parcelas'));
    await tester.pumpAndSettle();

    final due = {
      for (final item in controller.state.parcelas)
        item.numero: item.vencimento,
    };
    expect(due[2], DateTime(2030, 2, 28));
    expect(due[3], DateTime(2030, 3, 31));
  });

  testWidgets('detalhe do cliente nao estoura com fonte ampliada',
      (tester) async {
    _useSmallScreenWithLargeFont(tester);

    await _openClientDetail(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe da venda nao estoura com fonte ampliada',
      (tester) async {
    _useSmallScreenWithLargeFont(tester);

    await _openSaleDetail(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('telas comerciais nao estouram com fonte ampliada',
      (tester) async {
    _useSmallScreenWithLargeFont(tester);

    // Home (rota inicial) e as demais abas do modulo comercial.
    final router = await _pumpApp(tester);
    expect(tester.takeException(), isNull, reason: AppRoutes.homeName);

    for (final route in const [
      AppRoutes.clientsName,
      AppRoutes.billingName,
      AppRoutes.productsName,
      AppRoutes.notificationsName,
    ]) {
      router.pushNamed(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      router.pop();
      await tester.pumpAndSettle();
    }
  });
}

/// Tela pequena com fonte ampliada. A fonte de teste e monoespacada e bem mais
/// larga que a real, entao 1.3 aqui corresponde a um aparelho com a fonte do
/// sistema bastante aumentada.
void _useSmallScreenWithLargeFont(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Troca o seletor de data para entrada por texto e confirma [date].
Future<void> _pickDate(WidgetTester tester, String date) async {
  await tester.tap(find.byIcon(Icons.calendar_month_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, date);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<_ActionsTestController> _openClientDetail(WidgetTester tester) =>
    _pumpAt(tester, AppRoutes.clientDetailName, {'id': 'c1'});

Future<_ActionsTestController> _openSaleDetail(WidgetTester tester) =>
    _pumpAt(tester, AppRoutes.saleDetailName, {'id': 'v1'});

Future<_ActionsTestController> _pumpAt(
  WidgetTester tester,
  String routeName,
  Map<String, String> pathParameters,
) async {
  final controller = _ActionsTestController();
  final router = await _pumpApp(tester, controller: controller);
  router.pushNamed(routeName, pathParameters: pathParameters);
  await tester.pumpAndSettle();
  return controller;
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  _ActionsTestController? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salesControllerProvider.overrideWith(
          (ref) => controller ?? _ActionsTestController(),
        ),
      ],
      child: const PerfumeApp(),
    ),
  );
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(PerfumeApp)),
  );
  return container.read(appRouterProvider);
}

/// Controller offline: ids `local-*` mantem escrita e remarcacao no estado
/// local, sem HTTP.
class _ActionsTestController extends SalesController {
  _ActionsTestController()
      : super(
          dio: Dio(BaseOptions(baseUrl: 'http://test')),
          store: _MemoryStore(),
          autoLoad: false,
          retryInterval: const Duration(days: 1),
        ) {
    state = SalesSnapshot(
      hoje: DateTime(2026, 7, 31),
      clientes: const [
        Cliente(
          id: 'c1',
          nome: 'Dona Marta Oliveira',
          telefone: '(11) 98876-2310',
          bairro: 'Vila Madalena',
          score: 92,
          status: ClienteStatus.good,
          emAberto: 300,
          totalCompras: 12,
          parcelasAtraso: 0,
          totalComprado: 3200,
        ),
      ],
      produtos: const [
        Produto(
          id: 'p1',
          nome: 'Lattafa Khamrah',
          categoria: 'Arabe doce',
          precoBase: 300,
          custo: 180,
          estoque: 8,
          tem3D: false,
        ),
      ],
      vendas: [
        Venda(
          id: 'v1',
          clienteId: 'c1',
          data: DateTime(2029, 12, 31),
          itens: const [
            ItemVenda(produtoId: 'p1', quantidade: 1, precoUnitario: 300),
          ],
          total: 300,
          entrada: 0,
          numParcelas: 3,
        ),
      ],
      parcelas: [
        _parcela(1, DateTime(2030, 1, 31)),
        _parcela(2, DateTime(2030, 2, 28)),
        _parcela(3, DateTime(2030, 3, 31)),
      ],
      pagamentos: const [],
      notificacoes: [
        Notificacao(
          id: 'n1',
          clienteId: 'c1',
          parcelaId: 'local-parcela-1',
          tipo: NotificacaoTipo.venceHoje,
          data: DateTime(2026, 7, 31),
          texto: 'Parcela 1/3 de Dona Marta Oliveira vence hoje.',
          valor: 100,
        ),
      ],
    );
  }

  @override
  Future<void> receivePayment({
    required String installmentId,
    required double value,
    required DateTime date,
    required String method,
    String? notes,
    String? requestId,
  }) async {
    state = state.copyWith(
      parcelas: state.parcelas
          .map((item) => item.id == installmentId
              ? item.copyWith(valorPago: value, status: ParcelaStatus.paga)
              : item)
          .toList(),
    );
  }
}

Parcela _parcela(int numero, DateTime vencimento) => Parcela(
      id: 'local-parcela-$numero',
      vendaId: 'v1',
      numero: numero,
      total: 3,
      valor: 100,
      vencimento: vencimento,
      status: ParcelaStatus.pendente,
    );

class _MemoryStore implements SalesOfflineStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
