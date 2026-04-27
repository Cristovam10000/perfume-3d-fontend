import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sales_models.dart';
import 'sales_local_storage.dart';

const _storageKey = 'perfume_3d_sales_snapshot_v2';

final salesControllerProvider =
    StateNotifierProvider<SalesController, SalesSnapshot>((ref) {
  return SalesController(SalesLocalStorage());
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesControllerProvider);
});

class SalesController extends StateNotifier<SalesSnapshot> {
  final SalesLocalStorage _storage;

  SalesController(this._storage) : super(MockSalesRepository().loadSnapshot()) {
    _restore();
  }

  String nextProductId() {
    final next = state.produtos.map((produto) {
          final raw = RegExp(r'\d+').firstMatch(produto.id)?.group(0);
          return int.tryParse(raw ?? '') ?? 0;
        }).fold<int>(0, (max, id) => id > max ? id : max) +
        1;
    return 'p$next';
  }

  void addProduct(Produto produto) {
    state = state.copyWith(produtos: [...state.produtos, produto]);
    _persist();
  }

  void restockProduct(String produtoId, int amount) {
    if (amount <= 0) return;
    _replaceProduct(
      produtoId,
      (produto) => produto.copyWith(estoque: produto.estoque + amount),
    );
  }

  void adjustProductStock(String produtoId, int quantity) {
    _replaceProduct(
      produtoId,
      (produto) => produto.copyWith(estoque: quantity.clamp(0, 999999).toInt()),
    );
  }

  void confirmSale(Venda venda) {
    final soldByProduct = <String, int>{};
    for (final item in venda.itens) {
      soldByProduct.update(
        item.produtoId,
        (quantity) => quantity + item.quantidade,
        ifAbsent: () => item.quantidade,
      );
    }

    final produtos = state.produtos.map((produto) {
      final sold = soldByProduct[produto.id] ?? 0;
      if (sold == 0) return produto;
      return produto.copyWith(
        estoque: (produto.estoque - sold).clamp(0, 999999).toInt(),
      );
    }).toList();

    state = state.copyWith(
      produtos: produtos,
      vendas: [...state.vendas, venda],
    );
    _persist();
  }

  void _replaceProduct(String produtoId, Produto Function(Produto) update) {
    final produtos = state.produtos
        .map((produto) => produto.id == produtoId ? update(produto) : produto)
        .toList();
    state = state.copyWith(produtos: produtos);
    _persist();
  }

  void _restore() {
    final raw = _storage.read(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      state = _snapshotFromJson(raw).copyWith(hoje: _dateOnly(DateTime.now()));
    } catch (_) {
      // Mantem o snapshot padrao se o localStorage estiver em formato antigo.
    }
  }

  void _persist() {
    _storage.write(_storageKey, _snapshotToJson(state));
  }
}

abstract class SalesRepository {
  SalesSnapshot loadSnapshot();
}

class MockSalesRepository implements SalesRepository {
  @override
  SalesSnapshot loadSnapshot() {
    final hoje = _dateOnly(DateTime.now());
    final ontem = hoje.subtract(const Duration(days: 1));
    final amanha = hoje.add(const Duration(days: 1));
    final proximaSemana = hoje.add(const Duration(days: 8));

    const clientes = [
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
        syncStatus: SyncStatus.pending,
      ),
      Cliente(
        id: 'c3',
        nome: 'Tia Cleuza',
        telefone: '(11) 96620-4421',
        bairro: 'Pinheiros',
        score: 86,
        status: ClienteStatus.good,
        emAberto: 150,
        totalCompras: 8,
        parcelasAtraso: 0,
        totalComprado: 910,
      ),
      Cliente(
        id: 'c4',
        nome: 'Roberval Souza',
        telefone: '(11) 95514-8011',
        bairro: 'Tatuape',
        score: 48,
        status: ClienteStatus.bad,
        emAberto: 580,
        totalCompras: 3,
        parcelasAtraso: 3,
        totalComprado: 720,
      ),
      Cliente(
        id: 'c5',
        nome: 'Seu Nelson',
        telefone: '(11) 94410-1200',
        bairro: 'Mooca',
        score: 82,
        status: ClienteStatus.warn,
        emAberto: 90,
        totalCompras: 5,
        parcelasAtraso: 0,
        totalComprado: 640,
      ),
      Cliente(
        id: 'c6',
        nome: 'Ana Paula',
        telefone: '(11) 93222-7099',
        bairro: 'Santana',
        score: 95,
        status: ClienteStatus.good,
        emAberto: 0,
        totalCompras: 9,
        parcelasAtraso: 0,
        totalComprado: 1360,
      ),
    ];

    const produtos = [
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
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-khamrah.glb',
      ),
      Produto(
        id: 'p2',
        nome: 'Armaf Club de Nuit',
        categoria: 'Masculino',
        precoBase: 360,
        custo: 210,
        estoque: 5,
        estoqueMinimo: 1,
        volumeMl: 105,
        frascoColorValue: 0xFF4863A8,
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-club.glb',
      ),
      Produto(
        id: 'p3',
        nome: 'Maison Alhambra Layali',
        categoria: 'Feminino',
        precoBase: 280,
        custo: 155,
        estoque: 2,
        estoqueMinimo: 1,
        volumeMl: 100,
        frascoColorValue: 0xFFB13B72,
        tem3D: false,
      ),
      Produto(
        id: 'p4',
        nome: 'Al Haramain Amber Oud',
        categoria: 'Unissex',
        precoBase: 420,
        custo: 230,
        estoque: 12,
        estoqueMinimo: 1,
        volumeMl: 60,
        frascoColorValue: 0xFF94683E,
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-amber.glb',
      ),
      Produto(
        id: 'p5',
        nome: 'Lattafa Yara',
        categoria: 'Feminino',
        precoBase: 240,
        custo: 130,
        estoque: 0,
        estoqueMinimo: 1,
        volumeMl: 100,
        frascoColorValue: 0xFFC83D7B,
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-yara.glb',
        syncStatus: SyncStatus.pending,
      ),
      Produto(
        id: 'p6',
        nome: 'Rasasi Hawas',
        categoria: 'Masculino',
        precoBase: 380,
        custo: 220,
        estoque: 6,
        estoqueMinimo: 1,
        volumeMl: 100,
        frascoColorValue: 0xFF336D88,
        tem3D: false,
      ),
    ];

    final vendas = [
      Venda(
        id: '001',
        clienteId: 'c1',
        data: hoje.subtract(const Duration(days: 3)),
        itens: const [
          ItemVenda(produtoId: 'p1', quantidade: 1, precoUnitario: 320),
          ItemVenda(produtoId: 'p3', quantidade: 1, precoUnitario: 240),
        ],
        total: 560,
        entrada: 80,
        numParcelas: 4,
      ),
      Venda(
        id: '002',
        clienteId: 'c3',
        data: hoje.subtract(const Duration(days: 20)),
        itens: const [
          ItemVenda(produtoId: 'p2', quantidade: 1, precoUnitario: 360),
        ],
        total: 360,
        entrada: 60,
        numParcelas: 2,
      ),
      Venda(
        id: '003',
        clienteId: 'c4',
        data: hoje.subtract(const Duration(days: 12)),
        itens: const [
          ItemVenda(produtoId: 'p4', quantidade: 2, precoUnitario: 280),
        ],
        total: 560,
        entrada: 0,
        numParcelas: 4,
        syncStatus: SyncStatus.pending,
      ),
      Venda(
        id: '004',
        clienteId: 'c2',
        data: hoje,
        itens: const [
          ItemVenda(produtoId: 'p1', quantidade: 1, precoUnitario: 320),
        ],
        total: 320,
        entrada: 80,
        numParcelas: 2,
        syncStatus: SyncStatus.pending,
      ),
    ];

    final parcelas = [
      Parcela(
        id: 'pa1',
        vendaId: '001',
        numero: 1,
        total: 4,
        valor: 120,
        valorPago: 120,
        vencimento: hoje.subtract(const Duration(days: 26)),
        status: ParcelaStatus.paga,
        eventos: [
          EventoParcela(
            tipo: EventoTipo.pagamento,
            data: hoje.subtract(const Duration(days: 25)),
            descricao: 'Pagamento recebido via Pix',
            valor: 120,
          ),
        ],
      ),
      Parcela(
        id: 'pa2',
        vendaId: '001',
        numero: 2,
        total: 4,
        valor: 120,
        valorPago: 120,
        vencimento: hoje.subtract(const Duration(days: 4)),
        status: ParcelaStatus.paga,
      ),
      Parcela(
        id: 'pa3',
        vendaId: '001',
        numero: 3,
        total: 4,
        valor: 120,
        valorPago: 40,
        vencimento: ontem,
        status: ParcelaStatus.parcial,
      ),
      Parcela(
        id: 'pa4',
        vendaId: '001',
        numero: 4,
        total: 4,
        valor: 80,
        vencimento: hoje,
        status: ParcelaStatus.pendente,
      ),
      Parcela(
        id: 'pa5',
        vendaId: '002',
        numero: 1,
        total: 2,
        valor: 150,
        valorPago: 150,
        vencimento: hoje.subtract(const Duration(days: 30)),
        status: ParcelaStatus.paga,
      ),
      Parcela(
        id: 'pa6',
        vendaId: '002',
        numero: 2,
        total: 2,
        valor: 150,
        vencimento: hoje,
        status: ParcelaStatus.pendente,
      ),
      Parcela(
        id: 'pa7',
        vendaId: '003',
        numero: 1,
        total: 4,
        valor: 140,
        vencimento: ontem.subtract(const Duration(days: 4)),
        status: ParcelaStatus.atrasada,
        syncStatus: SyncStatus.pending,
      ),
      Parcela(
        id: 'pa8',
        vendaId: '003',
        numero: 2,
        total: 4,
        valor: 140,
        vencimento: ontem,
        status: ParcelaStatus.atrasada,
      ),
      Parcela(
        id: 'pa9',
        vendaId: '004',
        numero: 1,
        total: 2,
        valor: 120,
        vencimento: amanha,
        status: ParcelaStatus.pendente,
        syncStatus: SyncStatus.pending,
      ),
      Parcela(
        id: 'pa10',
        vendaId: '004',
        numero: 2,
        total: 2,
        valor: 120,
        vencimento: proximaSemana,
        status: ParcelaStatus.pendente,
        syncStatus: SyncStatus.pending,
      ),
    ];

    final pagamentos = [
      Pagamento(
        id: 'pg1',
        parcelaId: 'pa1',
        data: hoje.subtract(const Duration(days: 25)),
        valor: 120,
        forma: 'Pix',
      ),
      Pagamento(
        id: 'pg2',
        parcelaId: 'pa2',
        data: hoje.subtract(const Duration(days: 3)),
        valor: 120,
        forma: 'Dinheiro',
      ),
      Pagamento(
        id: 'pg3',
        parcelaId: 'pa3',
        data: hoje,
        valor: 40,
        forma: 'Pix',
        syncStatus: SyncStatus.pending,
      ),
    ];

    final notificacoes = [
      Notificacao(
        id: 'n1',
        clienteId: 'c1',
        parcelaId: 'pa4',
        tipo: NotificacaoTipo.venceHoje,
        data: hoje.add(const Duration(hours: 8)),
        texto: 'Cobrar Dona Marta hoje',
        valor: 80,
      ),
      Notificacao(
        id: 'n2',
        clienteId: 'c2',
        parcelaId: 'pa9',
        tipo: NotificacaoTipo.venceAmanha,
        data: amanha.add(const Duration(hours: 8)),
        texto: 'Junior Alves vence amanha',
        valor: 120,
      ),
      Notificacao(
        id: 'n3',
        clienteId: 'c4',
        parcelaId: 'pa7',
        tipo: NotificacaoTipo.atraso,
        data: hoje.add(const Duration(hours: 7, minutes: 30)),
        texto: 'Roberval Souza esta atrasado ha 4 dias',
        valor: 140,
      ),
    ];

    return SalesSnapshot(
      hoje: hoje,
      clientes: clientes,
      produtos: produtos,
      vendas: vendas,
      parcelas: parcelas,
      pagamentos: pagamentos,
      notificacoes: notificacoes,
    );
  }
}

String _snapshotToJson(SalesSnapshot snapshot) {
  return jsonEncode({
    'hoje': snapshot.hoje.toIso8601String(),
    'clientes': snapshot.clientes.map(_clienteToJson).toList(),
    'produtos': snapshot.produtos.map(_produtoToJson).toList(),
    'vendas': snapshot.vendas.map(_vendaToJson).toList(),
    'parcelas': snapshot.parcelas.map(_parcelaToJson).toList(),
    'pagamentos': snapshot.pagamentos.map(_pagamentoToJson).toList(),
    'notificacoes': snapshot.notificacoes.map(_notificacaoToJson).toList(),
  });
}

SalesSnapshot _snapshotFromJson(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
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

Map<String, dynamic> _clienteToJson(Cliente cliente) => {
      'id': cliente.id,
      'nome': cliente.nome,
      'telefone': cliente.telefone,
      'bairro': cliente.bairro,
      'score': cliente.score,
      'status': cliente.status.name,
      'emAberto': cliente.emAberto,
      'totalCompras': cliente.totalCompras,
      'parcelasAtraso': cliente.parcelasAtraso,
      'totalComprado': cliente.totalComprado,
      'syncStatus': cliente.syncStatus.name,
    };

Cliente _clienteFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Cliente(
    id: json['id'] as String,
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

Map<String, dynamic> _produtoToJson(Produto produto) => {
      'id': produto.id,
      'nome': produto.nome,
      'categoria': produto.categoria,
      'precoBase': produto.precoBase,
      'custo': produto.custo,
      'estoque': produto.estoque,
      'estoqueMinimo': produto.estoqueMinimo,
      'volumeMl': produto.volumeMl,
      'frascoColorValue': produto.frascoColorValue,
      'tem3D': produto.tem3D,
      'modelo3DPath': produto.modelo3DPath,
      'previewImg': produto.previewImg,
      'syncStatus': produto.syncStatus.name,
    };

Produto _produtoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Produto(
    id: json['id'] as String,
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
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
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
    produtoId: json['produtoId'] as String,
    quantidade: (json['quantidade'] as num).toInt(),
    precoUnitario: (json['precoUnitario'] as num).toDouble(),
  );
}

Map<String, dynamic> _parcelaToJson(Parcela parcela) => {
      'id': parcela.id,
      'vendaId': parcela.vendaId,
      'numero': parcela.numero,
      'total': parcela.total,
      'valor': parcela.valor,
      'vencimento': parcela.vencimento.toIso8601String(),
      'status': parcela.status.name,
      'valorPago': parcela.valorPago,
      'eventos': parcela.eventos.map(_eventoParcelaToJson).toList(),
      'syncStatus': parcela.syncStatus.name,
    };

Parcela _parcelaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Parcela(
    id: json['id'] as String,
    vendaId: json['vendaId'] as String,
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

Map<String, dynamic> _pagamentoToJson(Pagamento pagamento) => {
      'id': pagamento.id,
      'parcelaId': pagamento.parcelaId,
      'data': pagamento.data.toIso8601String(),
      'valor': pagamento.valor,
      'forma': pagamento.forma,
      'observacoes': pagamento.observacoes,
      'syncStatus': pagamento.syncStatus.name,
    };

Pagamento _pagamentoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Pagamento(
    id: json['id'] as String,
    parcelaId: json['parcelaId'] as String,
    data: DateTime.parse(json['data'] as String),
    valor: (json['valor'] as num).toDouble(),
    forma: json['forma'] as String,
    observacoes: json['observacoes'] as String?,
    syncStatus:
        _enumByName(SyncStatus.values, json['syncStatus'], SyncStatus.synced),
  );
}

Map<String, dynamic> _eventoParcelaToJson(EventoParcela evento) => {
      'tipo': evento.tipo.name,
      'data': evento.data.toIso8601String(),
      'descricao': evento.descricao,
      'valor': evento.valor,
    };

EventoParcela _eventoParcelaFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return EventoParcela(
    tipo: _enumByName(EventoTipo.values, json['tipo'], EventoTipo.pagamento),
    data: DateTime.parse(json['data'] as String),
    descricao: json['descricao'] as String,
    valor: (json['valor'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _notificacaoToJson(Notificacao notificacao) => {
      'id': notificacao.id,
      'clienteId': notificacao.clienteId,
      'parcelaId': notificacao.parcelaId,
      'tipo': notificacao.tipo.name,
      'data': notificacao.data.toIso8601String(),
      'texto': notificacao.texto,
      'valor': notificacao.valor,
      'lida': notificacao.lida,
    };

Notificacao _notificacaoFromJson(Object? value) {
  final json = value as Map<String, dynamic>;
  return Notificacao(
    id: json['id'] as String,
    clienteId: json['clienteId'] as String,
    parcelaId: json['parcelaId'] as String,
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

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => fallback,
  );
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
