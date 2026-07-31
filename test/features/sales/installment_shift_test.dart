import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_offline_store.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_repository.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';

void main() {
  test('parcelasSeguintes ignora anteriores, a propria e as ja pagas', () {
    final controller = _controller();
    final snapshot = controller.state;
    final segunda = snapshot.parcelas.firstWhere((item) => item.numero == 2);

    final seguintes = snapshot.parcelasSeguintes(segunda);

    expect(seguintes.map((item) => item.numero), [3, 4]);
    controller.dispose();
  });

  test('desloca so as parcelas seguintes mantendo um mes de intervalo',
      () async {
    final controller = _controller();
    await controller.ready;
    final segunda =
        controller.state.parcelas.firstWhere((item) => item.numero == 2);

    final updated = await controller.shiftFollowingInstallments(
      installmentId: segunda.id,
      anchorDate: DateTime(2026, 8, 15),
    );

    expect(updated, 2);
    final due = {
      for (final item in controller.state.parcelas)
        if (item.vendaId == 'local-venda-1') item.numero: item.vencimento,
    };
    // Paga: intocada.
    expect(due[1], DateTime(2026, 7, 31));
    // A propria parcela ancora nao muda aqui (quem muda e o recebimento).
    expect(due[2], DateTime(2026, 8, 31));
    expect(due[3], DateTime(2026, 9, 15));
    expect(due[4], DateTime(2026, 10, 15));
    // Parcela de outra venda permanece intacta.
    expect(
      controller.state.parcelas
          .firstWhere((item) => item.id == 'local-outra-1')
          .vencimento,
      DateTime(2026, 9, 5),
    );
    controller.dispose();
  });

  test('respeita meses curtos ao deslocar a partir do dia 31', () async {
    final controller = _controller();
    await controller.ready;
    final segunda =
        controller.state.parcelas.firstWhere((item) => item.numero == 2);

    await controller.shiftFollowingInstallments(
      installmentId: segunda.id,
      anchorDate: DateTime(2026, 1, 31),
    );

    final due = {
      for (final item in controller.state.parcelas)
        if (item.vendaId == 'local-venda-1') item.numero: item.vencimento,
    };
    expect(due[3], DateTime(2026, 2, 28));
    expect(due[4], DateTime(2026, 3, 31));
    controller.dispose();
  });

  test('parcela sem seguintes em aberto nao gera remarcacao', () async {
    final controller = _controller();
    await controller.ready;
    final ultima =
        controller.state.parcelas.firstWhere((item) => item.numero == 4);

    final updated = await controller.shiftFollowingInstallments(
      installmentId: ultima.id,
      anchorDate: DateTime(2026, 12, 5),
    );

    expect(updated, 0);
    controller.dispose();
  });
}

_ShiftTestController _controller() => _ShiftTestController();

/// Usa ids `local-*` para que a remarcacao siga o caminho offline e nao
/// dependa de HTTP.
class _ShiftTestController extends SalesController {
  _ShiftTestController()
      : super(
          dio: Dio(BaseOptions(baseUrl: 'http://test')),
          store: _MemoryStore(),
          autoLoad: false,
          retryInterval: const Duration(days: 1),
        ) {
    state = SalesSnapshot(
      hoje: DateTime(2026, 7, 31),
      clientes: const [],
      produtos: const [],
      vendas: const [],
      parcelas: [
        _parcela(1, DateTime(2026, 7, 31), status: ParcelaStatus.paga),
        _parcela(2, DateTime(2026, 8, 31)),
        _parcela(3, DateTime(2026, 9, 30)),
        _parcela(4, DateTime(2026, 10, 31)),
        // Parcela de outra venda: nao pode ser tocada.
        Parcela(
          id: 'local-outra-1',
          vendaId: 'local-venda-2',
          numero: 2,
          total: 2,
          valor: 50,
          vencimento: DateTime(2026, 9, 5),
          status: ParcelaStatus.pendente,
        ),
      ],
      pagamentos: const [],
      notificacoes: const [],
    );
  }
}

Parcela _parcela(
  int numero,
  DateTime vencimento, {
  ParcelaStatus status = ParcelaStatus.pendente,
}) {
  return Parcela(
    id: 'local-parcela-$numero',
    vendaId: 'local-venda-1',
    numero: numero,
    total: 4,
    valor: 100,
    vencimento: vencimento,
    status: status,
    valorPago: status == ParcelaStatus.paga ? 100 : 0,
  );
}

class _MemoryStore implements SalesOfflineStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
