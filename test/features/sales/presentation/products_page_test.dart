import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_repository.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';
import 'package:perfume_3d_mvp/features/sales/presentation/pages/products_page.dart';

void main() {
  testWidgets('ajustar quantidade fecha o modal sem erro de dependentes',
      (tester) async {
    final controller = _StockTestController();
    await _pumpProducts(tester, controller);

    await tester.tap(find.text('Produto teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar quantidade'));
    await tester.pumpAndSettle();

    final field = find.byType(TextField).last;
    await tester.enterText(field, '7');
    await tester.tap(find.text('Salvar ajuste'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Salvar ajuste'), findsNothing);
    expect(controller.state.produtos.single.estoque, 7);
  });

  testWidgets('repor estoque fecha o modal sem erro de dependentes',
      (tester) async {
    final controller = _StockTestController();
    await _pumpProducts(tester, controller);

    await tester.tap(find.text('Produto teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repor estoque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar reposicao'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Salvar reposicao'), findsNothing);
    expect(controller.state.produtos.single.estoque, 4);
  });

  testWidgets('editar valor do produto fecha o modal sem erro de dependentes',
      (tester) async {
    final controller = _StockTestController();
    await _pumpProducts(tester, controller);

    await tester.tap(find.text('Produto teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar produto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Preco*'), '250');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Salvar alterações'), findsNothing);
    expect(controller.state.produtos.single.precoBase, 250);
  });
}

Future<void> _pumpProducts(
  WidgetTester tester,
  _StockTestController controller,
) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salesControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: ProductsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _StockTestController extends SalesController {
  _StockTestController() : super(autoLoad: false) {
    state = SalesSnapshot(
      hoje: DateTime(2026, 7, 23),
      clientes: const [],
      produtos: const [
        Produto(
          id: '1',
          nome: 'Produto teste',
          categoria: 'Perfume',
          precoBase: 200,
          custo: 100,
          estoque: 3,
          estoqueMinimo: 1,
          volumeMl: 100,
          tem3D: false,
        ),
      ],
      vendas: const [],
      parcelas: const [],
      pagamentos: const [],
      notificacoes: const [],
    );
  }

  @override
  Future<Produto> adjustProductStock(String produtoId, int quantity) async {
    return _update(quantity);
  }

  @override
  Future<Produto> restockProduct(String produtoId, int amount) async {
    return _update(state.produtos.single.estoque + amount);
  }

  @override
  Future<Produto> updateProduct(Produto product) async {
    final updated = state.produtos.single.copyWith(
      precoBase: product.precoBase,
      custo: product.custo,
    );
    state = state.copyWith(produtos: [updated]);
    return updated;
  }

  Produto _update(int quantity) {
    final updated = state.produtos.single.copyWith(estoque: quantity);
    state = state.copyWith(produtos: [updated]);
    return updated;
  }
}
