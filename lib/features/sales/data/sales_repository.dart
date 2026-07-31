import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_math.dart';
import '../domain/sales_models.dart';
import 'sales_offline_store.dart';

final salesControllerProvider =
    StateNotifierProvider<SalesController, SalesSnapshot>((ref) {
  return SalesController();
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesControllerProvider);
});

class SalesController extends StateNotifier<SalesSnapshot> {
  final Dio _dio;
  final SalesOfflineStore _store;
  final Duration retryInterval;
  final Completer<void> _ready = Completer<void>();
  final List<_PendingSalesOperation> _outbox = [];
  final Map<String, String> _idMap = {};
  Timer? _retryTimer;
  bool _syncing = false;

  SalesController({
    Dio? dio,
    SalesOfflineStore? store,
    bool autoLoad = true,
    this.retryInterval = const Duration(seconds: 10),
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.backendBaseUrl,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
                responseType: ResponseType.json,
              ),
            ),
        _store = store ?? SharedPreferencesSalesOfflineStore(),
        super(SalesSnapshot.empty()) {
    if (autoLoad) {
      unawaited(_initialize());
    } else {
      _ready.complete();
    }
  }

  Future<void> get ready => _ready.future;
  int get pendingOperations => _outbox.length;

  Future<void> _initialize() async {
    try {
      final raw = await _store.read();
      if (raw != null && raw.isNotEmpty) {
        final envelope = jsonDecode(raw) as Map<String, dynamic>;
        final snapshot = envelope['snapshot'];
        if (snapshot is Map) {
          state = _snapshotFromMap(Map<String, dynamic>.from(snapshot));
        }
        _outbox
          ..clear()
          ..addAll(
            _list(envelope['outbox']).map(_PendingSalesOperation.fromJson),
          );
        final mappings = envelope['idMap'];
        if (mappings is Map) {
          _idMap.addAll(
            mappings.map((key, value) => MapEntry('$key', '$value')),
          );
        }
      }
    } catch (_) {
      // Mantem o estado vazio se o arquivo local estiver corrompido.
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
    await synchronize(silent: true);
    _retryTimer = Timer.periodic(
      retryInterval,
      (_) => unawaited(synchronize(silent: true)),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    await _ready.future;
    await synchronize(silent: silent);
  }

  Future<void> synchronize({bool silent = true}) async {
    await _ready.future;
    while (_syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _syncing = true;
    try {
      await _syncOutbox();
      if (_outbox.isNotEmpty) return;
      final response = await _dio.get('/sales/snapshot');
      final data = response.data;
      if (data is! Map) {
        throw const AppException('Resposta comercial invalida.');
      }
      state = _snapshotFromMap(Map<String, dynamic>.from(data)).copyWith(
        hoje: dateOnly(DateTime.now()),
      );
      await _persist();
    } catch (error) {
      if (!silent) throw _asAppException(error);
    } finally {
      _syncing = false;
    }
  }

  Future<Cliente> createClient({
    required String nome,
    required String telefone,
    required String bairro,
  }) async {
    await _ready.future;
    final operationId = _newId('client');
    final local = Cliente(
      id: 'local-$operationId',
      nome: nome,
      telefone: telefone,
      bairro: bairro,
      score: 0,
      status: ClienteStatus.warn,
      emAberto: 0,
      totalCompras: 0,
      parcelasAtraso: 0,
      totalComprado: 0,
      syncStatus: SyncStatus.pending,
    );
    try {
      final response = await _dio.post(
        '/sales/clients',
        data: {
          'requestId': operationId,
          'nome': nome,
          'telefone': telefone,
          'bairro': bairro,
        },
      );
      final client = _clienteFromJson(_responseMap(response.data));
      _upsertClient(client);
      _idMap[local.id] = client.id;
      await _persist();
      unawaited(refresh(silent: true));
      return client;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        _upsertClient(local);
        await _enqueue(
          _PendingSalesOperation(
            id: operationId,
            type: 'createClient',
            payload: {'client': _clienteToJson(local)},
          ),
        );
        return local;
      }
      throw _asAppException(error);
    }
  }

  Future<Cliente> updateClient(Cliente client) async {
    await _ready.future;
    final operationId = _newId('client-update');
    if (_isLocalId(client.id)) {
      final pending = client.copyWith(syncStatus: SyncStatus.pending);
      _upsertClient(pending);
      await _enqueue(
        _PendingSalesOperation(
          id: operationId,
          type: 'updateClient',
          payload: {'client': _clienteToJson(pending)},
        ),
      );
      return pending;
    }
    try {
      final response = await _dio.patch(
        '/sales/clients/${client.id}',
        data: {
          'requestId': operationId,
          'nome': client.nome,
          'telefone': client.telefone,
          'bairro': client.bairro,
        },
      );
      final updated = _clienteFromJson(_responseMap(response.data));
      _upsertClient(updated);
      await _persist();
      unawaited(refresh(silent: true));
      return updated;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        final pending = client.copyWith(syncStatus: SyncStatus.pending);
        _upsertClient(pending);
        await _enqueue(
          _PendingSalesOperation(
            id: operationId,
            type: 'updateClient',
            payload: {'client': _clienteToJson(pending)},
          ),
        );
        return pending;
      }
      throw _asAppException(error);
    }
  }

  Future<Produto> createProduct(Produto product) async {
    await _ready.future;
    final operationId = _newId('product');
    final local = product.copyWith(
      id: 'local-$operationId',
      tem3D: false,
      syncStatus: SyncStatus.pending,
    );
    try {
      final response = await _dio.post(
        '/sales/products',
        data: {
          'requestId': operationId,
          ..._productWriteJson(product, includeStock: true),
        },
      );
      final created = _produtoFromJson(_responseMap(response.data));
      _upsertProduct(created);
      _idMap[local.id] = created.id;
      await _persist();
      unawaited(refresh(silent: true));
      return created;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        _upsertProduct(local);
        await _enqueue(
          _PendingSalesOperation(
            id: operationId,
            type: 'createProduct',
            payload: {'product': _produtoToJson(local)},
          ),
        );
        return local;
      }
      throw _asAppException(error);
    }
  }

  Future<Produto> updateProduct(Produto product) async {
    await _ready.future;
    final operationId = _newId('product-update');
    if (_isLocalId(product.id)) {
      final pending = product.copyWith(syncStatus: SyncStatus.pending);
      _upsertProduct(pending);
      await _enqueue(
        _PendingSalesOperation(
          id: operationId,
          type: 'updateProduct',
          payload: {'product': _produtoToJson(pending)},
        ),
      );
      return pending;
    }
    try {
      final response = await _dio.patch(
        '/sales/products/${product.id}',
        data: _productWriteJson(product),
      );
      final updated = _produtoFromJson(_responseMap(response.data));
      _upsertProduct(updated);
      await _persist();
      unawaited(refresh(silent: true));
      return updated;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        final pending = product.copyWith(syncStatus: SyncStatus.pending);
        _upsertProduct(pending);
        await _enqueue(
          _PendingSalesOperation(
            id: operationId,
            type: 'updateProduct',
            payload: {'product': _produtoToJson(pending)},
          ),
        );
        return pending;
      }
      throw _asAppException(error);
    }
  }

  Future<Produto> restockProduct(String produtoId, int amount) {
    if (amount <= 0) {
      throw const AppException('Informe uma quantidade maior que zero.');
    }
    return _updateRemoteStock(produtoId, mode: 'add', quantity: amount);
  }

  Future<Produto> adjustProductStock(String produtoId, int quantity) {
    if (quantity < 0) {
      throw const AppException('O estoque nao pode ser negativo.');
    }
    return _updateRemoteStock(produtoId, mode: 'set', quantity: quantity);
  }

  Future<Produto> _updateRemoteStock(
    String productId, {
    required String mode,
    required int quantity,
  }) async {
    await _ready.future;
    final current = state.produtoById(productId);
    if (current == null) {
      throw const AppException('Produto nao encontrado.');
    }
    final desiredQuantity =
        mode == 'add' ? current.estoque + quantity : quantity;
    final operationId = _newId('stock');
    if (_isLocalId(productId)) {
      return _queueStock(
        current,
        desiredQuantity,
        operationId,
      );
    }
    try {
      final response = await _dio.patch(
        '/sales/products/$productId/stock',
        data: {'mode': mode, 'quantity': quantity},
      );
      final updated = _produtoFromJson(_responseMap(response.data));
      _upsertProduct(updated);
      await _persist();
      unawaited(refresh(silent: true));
      return updated;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        return _queueStock(current, desiredQuantity, operationId);
      }
      throw _asAppException(error);
    }
  }

  Future<Venda> confirmSale(Venda sale) async {
    await _ready.future;
    final operationId = _newId('sale');
    final local = sale.copyWith(
      id: 'local-$operationId',
      syncStatus: SyncStatus.pending,
    );
    final hasLocalDependency = _isLocalId(sale.clienteId) ||
        sale.itens.any((item) => _isLocalId(item.produtoId));
    if (hasLocalDependency) {
      return _queueSale(local, operationId);
    }
    try {
      final response = await _dio.post(
        '/sales/sales',
        data: {
          ..._vendaToJson(sale),
          'requestId': operationId,
        },
      );
      final id = _responseMap(response.data)['id'].toString();
      final confirmed = sale.copyWith(id: id, syncStatus: SyncStatus.synced);
      final soldByProduct = <String, int>{};
      for (final item in sale.itens) {
        soldByProduct.update(
          item.produtoId,
          (value) => value + item.quantidade,
          ifAbsent: () => item.quantidade,
        );
      }
      state = state.copyWith(
        vendas: [...state.vendas.where((item) => item.id != id), confirmed],
        produtos: state.produtos.map((product) {
          final sold = soldByProduct[product.id] ?? 0;
          return sold == 0
              ? product
              : product.copyWith(
                  estoque: (product.estoque - sold).clamp(0, 999999).toInt(),
                );
        }).toList(),
      );
      _idMap[local.id] = confirmed.id;
      await _persist();
      unawaited(refresh(silent: true));
      return confirmed;
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        return _queueSale(local, operationId);
      }
      throw _asAppException(error);
    }
  }

  Future<void> receivePayment({
    required String installmentId,
    required double value,
    required DateTime date,
    required String method,
    String? notes,
    String? requestId,
  }) async {
    await _ready.future;
    final operationId = requestId ?? _newId('payment');
    final installment = _parcelaById(installmentId);
    if (installment == null) {
      throw const AppException('Parcela nao encontrada.');
    }
    if (_isLocalId(installmentId)) {
      await _queuePayment(
        installment,
        operationId,
        value,
        date,
        method,
        notes,
      );
      return;
    }
    try {
      final response = await _dio.post(
        '/sales/installments/$installmentId/payments',
        data: {
          'requestId': operationId,
          'valor': value,
          'data': _apiDate(date),
          'forma': method,
          'observacoes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        },
      );
      final body = _responseMap(response.data);
      final payment = _pagamentoFromJson(body['payment']);
      final installment = _parcelaFromJson(body['installment']);
      state = state.copyWith(
        pagamentos: [
          ...state.pagamentos.where((item) => item.id != payment.id),
          payment,
        ],
        parcelas: state.parcelas
            .map((item) => item.id == installment.id ? installment : item)
            .toList(),
      );
      await _persist();
      unawaited(refresh(silent: true));
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        await _queuePayment(
          installment,
          operationId,
          value,
          date,
          method,
          notes,
        );
        return;
      }
      throw _asAppException(error);
    }
  }

  Future<void> renegotiateInstallment({
    required String installmentId,
    required DateTime dueDate,
    String? notes,
  }) async {
    await _ready.future;
    final operationId = _newId('due-date');
    final installment = _parcelaById(installmentId);
    if (installment == null) {
      throw const AppException('Parcela nao encontrada.');
    }
    if (_isLocalId(installmentId)) {
      await _queueDueDate(
        installment,
        operationId,
        dueDate,
        notes,
      );
      return;
    }
    try {
      final response = await _dio.patch(
        '/sales/installments/$installmentId/due-date',
        data: {
          'requestId': operationId,
          'dueDate': _apiDate(dueDate),
          'observacoes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        },
      );
      final installment = _parcelaFromJson(_responseMap(response.data));
      state = state.copyWith(
        parcelas: state.parcelas
            .map((item) => item.id == installment.id ? installment : item)
            .toList(),
      );
      await _persist();
      unawaited(refresh(silent: true));
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        await _queueDueDate(
          installment,
          operationId,
          dueDate,
          notes,
        );
        return;
      }
      throw _asAppException(error);
    }
  }

  /// Recalcula o vencimento das parcelas seguintes a [installmentId] mantendo
  /// um intervalo de um mes a partir de [anchorDate].
  ///
  /// Parcelas anteriores e ja pagas nao sao tocadas. Retorna quantas parcelas
  /// foram remarcadas.
  Future<int> shiftFollowingInstallments({
    required String installmentId,
    required DateTime anchorDate,
    String? notes,
  }) async {
    await _ready.future;
    final current = _parcelaById(installmentId);
    if (current == null) {
      throw const AppException('Parcela nao encontrada.');
    }
    final following = state.parcelasSeguintes(current);
    var updated = 0;
    for (final installment in following) {
      await renegotiateInstallment(
        installmentId: installment.id,
        dueDate: addMonthsClamped(
          dateOnly(anchorDate),
          installment.numero - current.numero,
        ),
        notes: notes,
      );
      updated += 1;
    }
    return updated;
  }

  Future<void> markNotificationRead(
    String notificationId, {
    bool read = true,
  }) async {
    await _ready.future;
    final operationId = _newId('notification');
    Notificacao? current;
    for (final notification in state.notificacoes) {
      if (notification.id == notificationId) {
        current = notification;
        break;
      }
    }
    if (current == null) {
      throw const AppException('Notificacao nao encontrada.');
    }
    try {
      final response = await _dio.patch(
        '/sales/notifications/$notificationId/read',
        data: {'lida': read},
      );
      final notification = _notificacaoFromJson(_responseMap(response.data));
      state = state.copyWith(
        notificacoes: state.notificacoes
            .map((item) => item.id == notification.id ? notification : item)
            .toList(),
      );
      await _persist();
    } catch (error) {
      if (_isTemporaryConnectionError(error)) {
        final pending = current.copyWith(lida: read);
        state = state.copyWith(
          notificacoes: state.notificacoes
              .map((item) => item.id == notificationId ? pending : item)
              .toList(),
        );
        await _enqueue(
          _PendingSalesOperation(
            id: operationId,
            type: 'notificationRead',
            payload: {
              'notificationId': notificationId,
              'read': read,
            },
          ),
        );
        return;
      }
      throw _asAppException(error);
    }
  }

  Future<void> _enqueue(_PendingSalesOperation operation) async {
    _outbox.add(operation);
    await _persist();
  }

  Future<Produto> _queueStock(
    Produto current,
    int quantity,
    String operationId,
  ) async {
    final pending = current.copyWith(
      estoque: quantity.clamp(0, 999999).toInt(),
      syncStatus: SyncStatus.pending,
    );
    _upsertProduct(pending);
    await _enqueue(
      _PendingSalesOperation(
        id: operationId,
        type: 'setStock',
        payload: {
          'productId': current.id,
          'quantity': pending.estoque,
        },
      ),
    );
    return pending;
  }

  Future<Venda> _queueSale(Venda sale, String operationId) async {
    final sold = <String, int>{};
    for (final item in sale.itens) {
      sold.update(
        item.produtoId,
        (value) => value + item.quantidade,
        ifAbsent: () => item.quantidade,
      );
    }
    final products = state.produtos.map((product) {
      final quantity = sold[product.id] ?? 0;
      return quantity == 0
          ? product
          : product.copyWith(
              estoque: (product.estoque - quantity).clamp(0, 999999).toInt(),
              syncStatus: SyncStatus.pending,
            );
    }).toList();
    final installments = _localInstallments(sale);
    state = state.copyWith(
      produtos: products,
      vendas: [...state.vendas, sale],
      parcelas: [...state.parcelas, ...installments],
    );
    await _enqueue(
      _PendingSalesOperation(
        id: operationId,
        type: 'createSale',
        payload: {
          'sale': _vendaToJson(sale),
          'installments': installments.map(_parcelaToJson).toList(),
        },
      ),
    );
    return sale;
  }

  Future<void> _queuePayment(
    Parcela installment,
    String operationId,
    double value,
    DateTime date,
    String method,
    String? notes,
  ) async {
    if (value <= 0 || value > installment.restante + 0.005) {
      throw const AppException('Valor de pagamento invalido.');
    }
    final paid = installment.valorPago + value;
    final status =
        paid >= installment.valor ? ParcelaStatus.paga : ParcelaStatus.parcial;
    final updated = installment.copyWith(
      valorPago: paid,
      status: status,
      syncStatus: SyncStatus.pending,
      eventos: [
        ...installment.eventos,
        EventoParcela(
          tipo: status == ParcelaStatus.paga
              ? EventoTipo.pagamento
              : EventoTipo.parcial,
          data: date,
          descricao: 'Pagamento pendente via $method',
          valor: value,
        ),
      ],
    );
    final payment = Pagamento(
      id: 'local-$operationId',
      parcelaId: installment.id,
      data: date,
      valor: value,
      forma: method,
      observacoes: notes,
      syncStatus: SyncStatus.pending,
    );
    state = state.copyWith(
      parcelas: state.parcelas
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
      pagamentos: [...state.pagamentos, payment],
    );
    await _enqueue(
      _PendingSalesOperation(
        id: operationId,
        type: 'payment',
        payload: {
          'payment': _pagamentoToJson(payment),
          'installment': _parcelaToJson(updated),
        },
      ),
    );
  }

  Future<void> _queueDueDate(
    Parcela installment,
    String operationId,
    DateTime dueDate,
    String? notes,
  ) async {
    final updated = installment.copyWith(
      vencimento: dueDate,
      status: installment.valorPago > 0
          ? ParcelaStatus.parcial
          : ParcelaStatus.pendente,
      syncStatus: SyncStatus.pending,
      eventos: [
        ...installment.eventos,
        EventoParcela(
          tipo: EventoTipo.remarca,
          data: DateTime.now(),
          descricao: notes ?? 'Vencimento alterado offline',
        ),
      ],
    );
    state = state.copyWith(
      parcelas: state.parcelas
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    await _enqueue(
      _PendingSalesOperation(
        id: operationId,
        type: 'dueDate',
        payload: {
          'installment': _parcelaToJson(updated),
          'notes': notes,
        },
      ),
    );
  }

  Future<void> _syncOutbox() async {
    while (_outbox.isNotEmpty) {
      final operation = _outbox.first;
      try {
        await _executeOperation(operation);
        _outbox.removeAt(0);
        await _persist();
      } catch (error) {
        operation
          ..attempts += 1
          ..lastError = _asAppException(error).message;
        await _persist();
        break;
      }
    }
  }

  Future<void> _executeOperation(_PendingSalesOperation operation) async {
    final payload = operation.payload;
    // Operacoes enfileiradas offline podem ter ids compostos longos; o backend
    // limita o requestId a 80 chars. Limita aqui para destravar a fila.
    final requestId = _capRequestId(operation.id);
    switch (operation.type) {
      case 'createClient':
        final local = _clienteFromJson(payload['client']);
        final response = await _dio.post('/sales/clients', data: {
          'requestId': requestId,
          'nome': local.nome,
          'telefone': local.telefone,
          'bairro': local.bairro,
        });
        final remote = _clienteFromJson(_responseMap(response.data));
        _remapClient(local.id, remote);
        return;
      case 'updateClient':
        final local = _clienteFromJson(payload['client']);
        final response =
            await _dio.patch('/sales/clients/${_resolveId(local.id)}', data: {
          'requestId': requestId,
          'nome': local.nome,
          'telefone': local.telefone,
          'bairro': local.bairro,
        });
        _upsertClient(_clienteFromJson(_responseMap(response.data)));
        return;
      case 'createProduct':
        final local = _produtoFromJson(payload['product']);
        final response = await _dio.post('/sales/products', data: {
          'requestId': requestId,
          ..._productWriteJson(local, includeStock: true),
        });
        _remapProduct(
          local.id,
          _produtoFromJson(_responseMap(response.data)),
        );
        return;
      case 'updateProduct':
        final local = _produtoFromJson(payload['product']);
        final response =
            await _dio.patch('/sales/products/${_resolveId(local.id)}', data: {
          ..._productWriteJson(local),
        });
        _upsertProduct(_produtoFromJson(_responseMap(response.data)));
        return;
      case 'setStock':
        final response = await _dio.patch(
          '/sales/products/${_resolveId('${payload['productId']}')}/stock',
          data: {'mode': 'set', 'quantity': payload['quantity']},
        );
        _upsertProduct(_produtoFromJson(_responseMap(response.data)));
        return;
      case 'createSale':
        final local = _resolvedSale(_vendaFromJson(payload['sale']));
        final response = await _dio.post('/sales/sales', data: {
          ..._vendaToJson(local),
          'requestId': requestId,
        });
        final remoteId = _responseMap(response.data)['id'].toString();
        _remapSale(local.id, remoteId);
        return;
      case 'payment':
        final payment = _pagamentoFromJson(payload['payment']);
        final installment = _parcelaFromJson(payload['installment']);
        final installmentId = await _resolveInstallmentId(installment);
        final response = await _dio.post(
          '/sales/installments/$installmentId/payments',
          data: {
            'requestId': requestId,
            'valor': payment.valor,
            'data': _apiDate(payment.data),
            'forma': payment.forma,
            'observacoes': payment.observacoes,
          },
        );
        final body = _responseMap(response.data);
        final remotePayment = _pagamentoFromJson(body['payment']);
        final remoteInstallment = _parcelaFromJson(body['installment']);
        state = state.copyWith(
          pagamentos: [
            ...state.pagamentos.where((item) => item.id != payment.id),
            remotePayment,
          ],
          parcelas: state.parcelas
              .map((item) =>
                  item.id == installment.id ? remoteInstallment : item)
              .toList(),
        );
        return;
      case 'dueDate':
        final installment = _parcelaFromJson(payload['installment']);
        final installmentId = await _resolveInstallmentId(installment);
        final response = await _dio.patch(
          '/sales/installments/$installmentId/due-date',
          data: {
            'requestId': requestId,
            'dueDate': _apiDate(installment.vencimento),
            'observacoes': payload['notes'],
          },
        );
        final remote = _parcelaFromJson(_responseMap(response.data));
        state = state.copyWith(
          parcelas: state.parcelas
              .map((item) => item.id == installment.id ? remote : item)
              .toList(),
        );
        return;
      case 'notificationRead':
        final id = '${payload['notificationId']}';
        final response = await _dio.patch(
          '/sales/notifications/$id/read',
          data: {'lida': payload['read']},
        );
        final remote = _notificacaoFromJson(_responseMap(response.data));
        state = state.copyWith(
          notificacoes: state.notificacoes
              .map((item) => item.id == id ? remote : item)
              .toList(),
        );
        return;
    }
    throw AppException('Operacao offline desconhecida: ${operation.type}');
  }

  Future<String> _resolveInstallmentId(Parcela installment) async {
    final mapped = _resolveId(installment.id);
    if (!_isLocalId(mapped)) return mapped;
    final saleId = _resolveId(installment.vendaId);
    if (_isLocalId(saleId)) {
      throw const AppException('A venda ainda nao foi sincronizada.');
    }
    final response = await _dio.get('/sales/snapshot');
    final remote = _snapshotFromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
    final match = remote.parcelas.firstWhere(
      (item) => item.vendaId == saleId && item.numero == installment.numero,
    );
    _idMap[installment.id] = match.id;
    return match.id;
  }

  void _remapClient(String localId, Cliente remote) {
    _idMap[localId] = remote.id;
    state = state.copyWith(
      clientes: [
        ...state.clientes.where((item) => item.id != localId),
        remote,
      ],
      vendas: state.vendas
          .map((sale) => sale.clienteId == localId
              ? sale.copyWith(clienteId: remote.id)
              : sale)
          .toList(),
    );
  }

  void _remapProduct(String localId, Produto remote) {
    _idMap[localId] = remote.id;
    state = state.copyWith(
      produtos: [
        ...state.produtos.where((item) => item.id != localId),
        remote,
      ],
      vendas: state.vendas.map((sale) {
        return sale.copyWith(
          itens: sale.itens
              .map((item) => item.produtoId == localId
                  ? ItemVenda(
                      produtoId: remote.id,
                      quantidade: item.quantidade,
                      precoUnitario: item.precoUnitario,
                    )
                  : item)
              .toList(),
        );
      }).toList(),
    );
  }

  void _remapSale(String localId, String remoteId) {
    _idMap[localId] = remoteId;
    state = state.copyWith(
      vendas: state.vendas
          .map((sale) => sale.id == localId
              ? sale.copyWith(id: remoteId, syncStatus: SyncStatus.synced)
              : sale)
          .toList(),
      parcelas: state.parcelas
          .map((item) =>
              item.vendaId == localId ? item.copyWith(vendaId: remoteId) : item)
          .toList(),
    );
  }

  Venda _resolvedSale(Venda sale) {
    return sale.copyWith(
      clienteId: _resolveId(sale.clienteId),
      itens: sale.itens
          .map((item) => ItemVenda(
                produtoId: _resolveId(item.produtoId),
                quantidade: item.quantidade,
                precoUnitario: item.precoUnitario,
              ))
          .toList(),
    );
  }

  String _resolveId(String id) => _idMap[id] ?? id;
  bool _isLocalId(String id) => id.startsWith('local-');

  Parcela? _parcelaById(String id) {
    for (final installment in state.parcelas) {
      if (installment.id == id) return installment;
    }
    return null;
  }

  Future<void> _persist() {
    return _store.write(jsonEncode({
      'snapshot': _snapshotToJson(state),
      'outbox': _outbox.map((item) => item.toJson()).toList(),
      'idMap': _idMap,
    }));
  }

  String _newId(String prefix) {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  /// Garante que o requestId nunca ultrapasse o limite de 80 caracteres do
  /// backend. Preserva o final (onde fica o timestamp em micros que garante
  /// unicidade), de forma deterministica e estavel entre reenvios.
  static String _capRequestId(String id) =>
      id.length <= 80 ? id : id.substring(id.length - 80);

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _upsertClient(Cliente client) {
    state = state.copyWith(
      clientes: [
        ...state.clientes.where((item) => item.id != client.id),
        client,
      ],
    );
  }

  void _upsertProduct(Produto product) {
    state = state.copyWith(
      produtos: [
        ...state.produtos.where((item) => item.id != product.id),
        product,
      ],
    );
  }
}

SalesSnapshot _snapshotFromMap(Map<String, dynamic> json) {
  return SalesSnapshot(
    hoje: DateTime.parse(json['hoje'] as String),
    clientes: _list(json['clientes']).map(_clienteFromJson).toList(),
    produtos: _list(json['produtos']).map(_produtoFromJson).toList(),
    vendas: _list(json['vendas']).map(_vendaFromJson).toList(),
    parcelas: _list(json['parcelas']).map(_parcelaFromJson).toList(),
    pagamentos: _list(json['pagamentos']).map(_pagamentoFromJson).toList(),
    notificacoes:
        _list(json['notificacoes']).map(_notificacaoFromJson).toList(),
  );
}

Cliente _clienteFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Cliente(
    id: json['id'].toString(),
    nome: json['nome'] as String,
    telefone: json['telefone'] as String,
    bairro: json['bairro'] as String,
    score: (json['score'] as num).toInt(),
    status:
        _enumByName(ClienteStatus.values, json['status'], ClienteStatus.warn),
    emAberto: (json['emAberto'] as num).toDouble(),
    totalCompras: (json['totalCompras'] as num).toInt(),
    parcelasAtraso: (json['parcelasAtraso'] as num).toInt(),
    totalComprado: (json['totalComprado'] as num).toDouble(),
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

Produto _produtoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Produto(
    id: json['id'].toString(),
    nome: json['nome'] as String,
    categoria: json['categoria'] as String,
    precoBase: (json['precoBase'] as num).toDouble(),
    custo: (json['custo'] as num?)?.toDouble() ?? 0,
    estoque: (json['estoque'] as num?)?.toInt() ?? 0,
    estoqueMinimo: (json['estoqueMinimo'] as num?)?.toInt() ?? 1,
    volumeMl: (json['volumeMl'] as num?)?.toInt() ?? 100,
    frascoColorValue: (json['frascoColorValue'] as num?)?.toInt() ?? 0xFFCB3E7B,
    tem3D: json['tem3D'] as bool,
    modelo3DPath: json['modelo3DPath'] as String?,
    previewImg: json['previewImg'] as String?,
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

Map<String, dynamic> _vendaToJson(Venda venda) => {
      'id': venda.id,
      'clienteId': venda.clienteId,
      'data': venda.data.toIso8601String(),
      'itens': venda.itens.map(_itemVendaToJson).toList(),
      'total': venda.total,
      'entrada': venda.entrada,
      'numParcelas': venda.numParcelas,
      'observacoes': venda.observacoes,
      'syncStatus': venda.syncStatus.name,
    };

Venda _vendaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Venda(
    id: json['id'].toString(),
    clienteId: json['clienteId'].toString(),
    data: DateTime.parse(json['data'] as String),
    itens: _list(json['itens']).map(_itemVendaFromJson).toList(),
    total: (json['total'] as num).toDouble(),
    entrada: (json['entrada'] as num).toDouble(),
    numParcelas: (json['numParcelas'] as num).toInt(),
    observacoes: json['observacoes'] as String?,
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

Map<String, dynamic> _itemVendaToJson(ItemVenda item) => {
      'produtoId': item.produtoId,
      'quantidade': item.quantidade,
      'precoUnitario': item.precoUnitario,
    };

ItemVenda _itemVendaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return ItemVenda(
    produtoId: json['produtoId'].toString(),
    quantidade: (json['quantidade'] as num).toInt(),
    precoUnitario: (json['precoUnitario'] as num).toDouble(),
  );
}

Parcela _parcelaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Parcela(
    id: json['id'].toString(),
    vendaId: json['vendaId'].toString(),
    numero: (json['numero'] as num).toInt(),
    total: (json['total'] as num).toInt(),
    valor: (json['valor'] as num).toDouble(),
    vencimento: DateTime.parse(json['vencimento'] as String),
    status: _enumByName(
        ParcelaStatus.values, json['status'], ParcelaStatus.pendente),
    valorPago: (json['valorPago'] as num?)?.toDouble() ?? 0,
    eventos: _list(json['eventos']).map(_eventoParcelaFromJson).toList(),
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

Pagamento _pagamentoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Pagamento(
    id: json['id'].toString(),
    parcelaId: json['parcelaId'].toString(),
    data: DateTime.parse(json['data'] as String),
    valor: (json['valor'] as num).toDouble(),
    forma: json['forma'] as String,
    observacoes: json['observacoes'] as String?,
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

EventoParcela _eventoParcelaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return EventoParcela(
    tipo: _enumByName(EventoTipo.values, json['tipo'], EventoTipo.pagamento),
    data: DateTime.parse(json['data'] as String),
    descricao: json['descricao'] as String,
    valor: (json['valor'] as num?)?.toDouble(),
  );
}

Notificacao _notificacaoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Notificacao(
    id: json['id'].toString(),
    clienteId: json['clienteId'].toString(),
    parcelaId: json['parcelaId'].toString(),
    tipo: _enumByName(
      NotificacaoTipo.values,
      json['tipo'],
      NotificacaoTipo.venceHoje,
    ),
    data: DateTime.parse(json['data'] as String),
    texto: json['texto'] as String,
    valor: (json['valor'] as num).toDouble(),
    lida: json['lida'] as bool? ?? false,
  );
}

List<Object?> _list(Object? value) => (value as List?)?.cast<Object?>() ?? [];

Map<String, dynamic> _responseMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const AppException('Resposta inesperada do backend.');
}

Map<String, dynamic> _productWriteJson(
  Produto product, {
  bool includeStock = false,
}) {
  return {
    'nome': product.nome,
    'categoria': product.categoria,
    'precoBase': product.precoBase,
    'custo': product.custo,
    if (includeStock) 'estoque': product.estoque,
    'estoqueMinimo': product.estoqueMinimo,
    'volumeMl': product.volumeMl,
    'frascoColorValue': product.frascoColorValue,
  };
}

String _apiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Map<String, dynamic> _snapshotToJson(SalesSnapshot snapshot) => {
      'hoje': snapshot.hoje.toIso8601String(),
      'clientes': snapshot.clientes.map(_clienteToJson).toList(),
      'produtos': snapshot.produtos.map(_produtoToJson).toList(),
      'vendas': snapshot.vendas.map(_vendaToJson).toList(),
      'parcelas': snapshot.parcelas.map(_parcelaToJson).toList(),
      'pagamentos': snapshot.pagamentos.map(_pagamentoToJson).toList(),
      'notificacoes': snapshot.notificacoes.map(_notificacaoToJson).toList(),
    };

Map<String, dynamic> _clienteToJson(Cliente value) => {
      'id': value.id,
      'nome': value.nome,
      'telefone': value.telefone,
      'bairro': value.bairro,
      'score': value.score,
      'status': value.status.name,
      'emAberto': value.emAberto,
      'totalCompras': value.totalCompras,
      'parcelasAtraso': value.parcelasAtraso,
      'totalComprado': value.totalComprado,
      'syncStatus': value.syncStatus.name,
    };

Map<String, dynamic> _produtoToJson(Produto value) => {
      'id': value.id,
      'nome': value.nome,
      'categoria': value.categoria,
      'precoBase': value.precoBase,
      'custo': value.custo,
      'estoque': value.estoque,
      'estoqueMinimo': value.estoqueMinimo,
      'volumeMl': value.volumeMl,
      'frascoColorValue': value.frascoColorValue,
      'tem3D': value.tem3D,
      'modelo3DPath': value.modelo3DPath,
      'previewImg': value.previewImg,
      'syncStatus': value.syncStatus.name,
    };

Map<String, dynamic> _parcelaToJson(Parcela value) => {
      'id': value.id,
      'vendaId': value.vendaId,
      'numero': value.numero,
      'total': value.total,
      'valor': value.valor,
      'vencimento': value.vencimento.toIso8601String(),
      'status': value.status.name,
      'valorPago': value.valorPago,
      'eventos': value.eventos
          .map((event) => {
                'tipo': event.tipo.name,
                'data': event.data.toIso8601String(),
                'descricao': event.descricao,
                'valor': event.valor,
              })
          .toList(),
      'syncStatus': value.syncStatus.name,
    };

Map<String, dynamic> _pagamentoToJson(Pagamento value) => {
      'id': value.id,
      'parcelaId': value.parcelaId,
      'data': value.data.toIso8601String(),
      'valor': value.valor,
      'forma': value.forma,
      'observacoes': value.observacoes,
      'syncStatus': value.syncStatus.name,
    };

Map<String, dynamic> _notificacaoToJson(Notificacao value) => {
      'id': value.id,
      'clienteId': value.clienteId,
      'parcelaId': value.parcelaId,
      'tipo': value.tipo.name,
      'data': value.data.toIso8601String(),
      'texto': value.texto,
      'valor': value.valor,
      'lida': value.lida,
    };

List<Parcela> _localInstallments(Venda sale) {
  final remaining = sale.restante;
  if (remaining <= 0 || sale.numParcelas <= 0) return const [];
  final base = (remaining / sale.numParcelas * 100).round() / 100;
  final values = List<double>.filled(sale.numParcelas, base);
  values[values.length - 1] =
      (remaining - values.take(values.length - 1).fold(0.0, (a, b) => a + b));
  return [
    for (var index = 0; index < values.length; index++)
      Parcela(
        id: 'local-installment-${sale.id}-${index + 1}',
        vendaId: sale.id,
        numero: index + 1,
        total: values.length,
        valor: values[index],
        vencimento: addMonthsClamped(dateOnly(sale.data), index + 1),
        status: ParcelaStatus.pendente,
        syncStatus: SyncStatus.pending,
      ),
  ];
}

bool _isTemporaryConnectionError(Object error) {
  if (error is! DioException) return false;
  if (error.response?.statusCode case final int status when status >= 500) {
    return true;
  }
  return error.response == null &&
      {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.unknown,
      }.contains(error.type);
}

AppException _asAppException(Object error) {
  if (error is AppException) return error;
  if (error is DioException) {
    final responseData = error.response?.data;
    String? detail;
    if (responseData is Map) {
      final raw = responseData['detail'] ?? responseData['error'];
      if (raw is String) {
        detail = raw;
      } else if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is Map && first['msg'] != null) {
          detail = first['msg'].toString();
        }
      }
    }
    return AppException(
      detail ??
          (error.type == DioExceptionType.connectionError
              ? 'Nao foi possivel conectar ao backend.'
              : 'A operacao nao foi confirmada pelo backend.'),
      error,
    );
  }
  return AppException('Nao foi possivel concluir a operacao.', error);
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => fallback,
  );
}

class _PendingSalesOperation {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int attempts;
  String? lastError;

  _PendingSalesOperation({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.attempts = 0,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now();

  factory _PendingSalesOperation.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    return _PendingSalesOperation(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };
}
