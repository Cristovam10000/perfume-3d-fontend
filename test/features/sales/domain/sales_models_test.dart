import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';

void main() {
  test('valor de estoque usa custo vezes quantidade', () {
    final snapshot = _snapshot(
      produtos: const [
        Produto(
          id: '1',
          nome: 'Perfume',
          categoria: 'Unissex',
          precoBase: 180,
          custo: 100,
          estoque: 3,
          tem3D: false,
        ),
      ],
    );

    expect(snapshot.unidadesEmEstoque, 3);
    expect(snapshot.valorEstoqueCusto, 300);
    expect(snapshot.valorVendaPotencial, 540);
  });

  test('contabiliza produtos sem custo e notificacoes nao lidas', () {
    final snapshot = _snapshot(
      produtos: const [
        Produto(
          id: '1',
          nome: 'Sem custo',
          categoria: 'Perfume',
          precoBase: 100,
          custo: 0,
          tem3D: false,
        ),
      ],
      notificacoes: [
        Notificacao(
          id: '1',
          clienteId: '1',
          parcelaId: '1',
          tipo: NotificacaoTipo.venceHoje,
          data: DateTime(2026, 7, 23),
          texto: 'Vence hoje',
          valor: 100,
        ),
        Notificacao(
          id: '2',
          clienteId: '1',
          parcelaId: '2',
          tipo: NotificacaoTipo.pagamento,
          data: DateTime(2026, 7, 23),
          texto: 'Pagamento',
          valor: 50,
          lida: true,
        ),
      ],
    );

    expect(snapshot.produtosSemCusto, 1);
    expect(snapshot.notificacoesNaoLidas, 1);
  });
}

SalesSnapshot _snapshot({
  List<Produto> produtos = const [],
  List<Notificacao> notificacoes = const [],
}) {
  return SalesSnapshot(
    hoje: DateTime(2026, 7, 23),
    clientes: const [],
    produtos: produtos,
    vendas: const [],
    parcelas: const [],
    pagamentos: const [],
    notificacoes: notificacoes,
  );
}
