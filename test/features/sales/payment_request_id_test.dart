import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_offline_store.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_repository.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';

void main() {
  test('requestId de pagamento na fila e limitado a 80 chars no envio',
      () async {
    var online = false;
    String? sentRequestId;

    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (online && options.path.contains('/payments')) {
            final data = options.data;
            if (data is Map) {
              sentRequestId = data['requestId'] as String?;
            }
          }
          // Sempre rejeita como erro de conexao: offline enfileira o pagamento;
          // online, ja capturamos o requestId e evitamos montar uma resposta.
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'test',
            ),
          );
        },
      ),
    );

    final controller = _PaymentTestController(dio: dio, store: _MemoryStore());
    await controller.ready;

    // Simula um requestId longo (parcela local de venda offline) que ja estava
    // enfileirado antes da correcao — 83 caracteres.
    const longId =
        'payment-local-installment-local-sale-1784826029285708-dc1a2e3c-3-1784826075650052';
    expect(longId.length, greaterThan(80));

    await controller.receivePayment(
      installmentId: '31',
      value: 50,
      date: DateTime(2026, 7, 23),
      method: 'Dinheiro',
      requestId: longId,
    );
    expect(controller.pendingOperations, 1);

    online = true;
    await controller.synchronize(silent: true);

    expect(sentRequestId, isNotNull);
    expect(sentRequestId!.length, lessThanOrEqualTo(80));
    // Preserva o final (timestamp em micros) para manter unicidade.
    expect(sentRequestId, longId.substring(longId.length - 80));

    controller.dispose();
  });
}

class _PaymentTestController extends SalesController {
  _PaymentTestController({required Dio dio, required SalesOfflineStore store})
      : super(
          dio: dio,
          store: store,
          autoLoad: false,
          retryInterval: const Duration(days: 1),
        ) {
    state = SalesSnapshot(
      hoje: DateTime(2026, 7, 23),
      clientes: const [],
      produtos: const [],
      vendas: const [],
      parcelas: [
        Parcela(
          id: '31',
          vendaId: 'server-sale-1',
          numero: 1,
          total: 1,
          valor: 100,
          vencimento: DateTime(2026, 8, 10),
          status: ParcelaStatus.pendente,
        ),
      ],
      pagamentos: const [],
      notificacoes: const [],
    );
  }
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
