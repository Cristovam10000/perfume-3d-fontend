import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_offline_store.dart';
import 'package:perfume_3d_mvp/features/sales/data/sales_repository.dart';
import 'package:perfume_3d_mvp/features/sales/presentation/pages/sale_wizard_page.dart';

void main() {
  test('estado comercial inicia vazio e sem dados de demonstracao', () {
    final controller = SalesController(autoLoad: false);

    expect(controller.state.clientes, isEmpty);
    expect(controller.state.produtos, isEmpty);
    expect(controller.state.vendas, isEmpty);
    expect(controller.state.parcelas, isEmpty);
  });

  test('cliente criado offline permanece salvo depois de recriar controller',
      () async {
    final store = _MemorySalesStore();
    final dio = _salesDio(online: () => false);
    final first = SalesController(
      dio: dio,
      store: store,
      retryInterval: const Duration(days: 1),
    );
    await first.ready;

    final client = await first.createClient(
      nome: 'Maria Offline',
      telefone: '85999998888',
      bairro: 'Centro',
    );

    expect(client.syncStatus.name, 'pending');
    expect(first.pendingOperations, 1);
    expect(store.value, contains('Maria Offline'));
    first.dispose();

    final restored = SalesController(
      dio: dio,
      store: store,
      retryInterval: const Duration(days: 1),
    );
    await restored.ready;
    expect(restored.state.clientes.single.nome, 'Maria Offline');
    expect(restored.pendingOperations, 1);
    restored.dispose();
  });

  test('fila envia cliente e troca id local quando backend volta', () async {
    var online = false;
    var createRequests = 0;
    final store = _MemorySalesStore();
    final dio = _salesDio(
      online: () => online,
      onCreateClient: () => createRequests += 1,
    );
    final controller = SalesController(
      dio: dio,
      store: store,
      retryInterval: const Duration(days: 1),
    );
    await controller.ready;
    await controller.createClient(
      nome: 'Maria Offline',
      telefone: '85999998888',
      bairro: 'Centro',
    );

    online = true;
    await controller.synchronize(silent: false);

    expect(controller.pendingOperations, 0);
    expect(controller.state.clientes.single.id, '42');
    expect(controller.state.clientes.single.syncStatus.name, 'synced');
    expect(createRequests, 1);
    controller.dispose();
  });

  test('cliente criado offline pode ser excluido antes da sincronizacao',
      () async {
    final store = _MemorySalesStore();
    final dio = _salesDio(online: () => false);
    final controller = SalesController(
      dio: dio,
      store: store,
      retryInterval: const Duration(days: 1),
    );
    await controller.ready;
    final client = await controller.createClient(
      nome: 'Cliente Temporario',
      telefone: '85999998888',
      bairro: 'Centro',
    );

    await controller.deleteClient(client.id);

    expect(controller.state.clientes, isEmpty);
    expect(controller.pendingOperations, 0);
    expect(store.value, isNot(contains('Cliente Temporario')));
    controller.dispose();

    final restored = SalesController(
      dio: dio,
      store: store,
      retryInterval: const Duration(days: 1),
    );
    await restored.ready;
    expect(restored.state.clientes, isEmpty);
    restored.dispose();
  });

  test('cliente sincronizado e removido quando backend confirma o DELETE',
      () async {
    var deleted = false;
    final controller = SalesController(
      dio: _salesDio(
        online: () => true,
        onDeleteClient: () => deleted = true,
        includeClient: () => !deleted,
      ),
      store: _MemorySalesStore(),
      retryInterval: const Duration(days: 1),
    );
    await controller.ready;
    await controller.synchronize(silent: false);
    expect(controller.state.clientes.single.id, '42');

    await controller.deleteClient('42');
    await Future<void>.delayed(Duration.zero);

    expect(deleted, isTrue);
    expect(controller.state.clientes, isEmpty);
    controller.dispose();
  });

  testWidgets('nova venda orienta o cadastro quando o banco esta vazio',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesControllerProvider.overrideWith(
            (ref) => SalesController(autoLoad: false),
          ),
        ],
        child: const MaterialApp(home: SaleWizardPage()),
      ),
    );
    await tester.pump();

    expect(
      find.text('Nenhum cliente cadastrado no banco.'),
      findsOneWidget,
    );
    expect(find.text('Cadastrar cliente'), findsOneWidget);
  });
}

class _MemorySalesStore implements SalesOfflineStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

Dio _salesDio({
  required bool Function() online,
  void Function()? onCreateClient,
  void Function()? onDeleteClient,
  bool Function()? includeClient,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!online()) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'offline',
            ),
          );
          return;
        }
        if (options.path == '/sales/clients') {
          onCreateClient?.call();
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: _clientJson,
            ),
          );
          return;
        }
        if (options.method == 'DELETE' && options.path == '/sales/clients/42') {
          onDeleteClient?.call();
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 204,
            ),
          );
          return;
        }
        if (options.path == '/sales/snapshot') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'hoje': DateTime(2026, 7, 23).toIso8601String(),
                'clientes':
                    includeClient?.call() == false ? const [] : [_clientJson],
                'produtos': const [],
                'vendas': const [],
                'parcelas': const [],
                'pagamentos': const [],
                'notificacoes': const [],
              },
            ),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 404),
          ),
        );
      },
    ),
  );
  return dio;
}

final Map<String, dynamic> _clientJson = jsonDecode('''
{
  "id": "42",
  "nome": "Maria Offline",
  "telefone": "85999998888",
  "bairro": "Centro",
  "score": 0,
  "status": "warn",
  "emAberto": 0,
  "totalCompras": 0,
  "parcelasAtraso": 0,
  "totalComprado": 0,
  "syncStatus": "synced"
}
''') as Map<String, dynamic>;
