enum ClienteStatus { good, warn, bad }

enum ParcelaStatus { paga, pendente, atrasada, parcial }

enum EventoTipo { pagamento, venda, atraso, remarca, parcial }

enum SyncStatus { synced, pending, failed }

enum NotificacaoTipo { venceHoje, venceAmanha, atraso, pagamento }

class Cliente {
  final String id;
  final String nome;
  final String telefone;
  final String bairro;
  final int score;
  final ClienteStatus status;
  final double emAberto;
  final int totalCompras;
  final int parcelasAtraso;
  final double totalComprado;
  final SyncStatus syncStatus;

  const Cliente({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.bairro,
    required this.score,
    required this.status,
    required this.emAberto,
    required this.totalCompras,
    required this.parcelasAtraso,
    required this.totalComprado,
    this.syncStatus = SyncStatus.synced,
  });

  String get iniciais {
    final parts = nome.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class Produto {
  final String id;
  final String nome;
  final String categoria;
  final double precoBase;
  final double custo;
  final int estoque;
  final int estoqueMinimo;
  final int volumeMl;
  final int frascoColorValue;
  final bool tem3D;
  final String? modelo3DPath;
  final String? previewImg;
  final SyncStatus syncStatus;

  const Produto({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.precoBase,
    this.custo = 0,
    this.estoque = 0,
    this.estoqueMinimo = 1,
    this.volumeMl = 100,
    this.frascoColorValue = 0xFFCB3E7B,
    required this.tem3D,
    this.modelo3DPath,
    this.previewImg,
    this.syncStatus = SyncStatus.synced,
  });

  Produto copyWith({
    String? id,
    String? nome,
    String? categoria,
    double? precoBase,
    double? custo,
    int? estoque,
    int? estoqueMinimo,
    int? volumeMl,
    int? frascoColorValue,
    bool? tem3D,
    String? modelo3DPath,
    String? previewImg,
    SyncStatus? syncStatus,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      precoBase: precoBase ?? this.precoBase,
      custo: custo ?? this.custo,
      estoque: estoque ?? this.estoque,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      volumeMl: volumeMl ?? this.volumeMl,
      frascoColorValue: frascoColorValue ?? this.frascoColorValue,
      tem3D: tem3D ?? this.tem3D,
      modelo3DPath: modelo3DPath ?? this.modelo3DPath,
      previewImg: previewImg ?? this.previewImg,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class Venda {
  final String id;
  final String clienteId;
  final DateTime data;
  final List<ItemVenda> itens;
  final double total;
  final double entrada;
  final int numParcelas;
  final String? observacoes;
  final SyncStatus syncStatus;

  const Venda({
    required this.id,
    required this.clienteId,
    required this.data,
    required this.itens,
    required this.total,
    required this.entrada,
    required this.numParcelas,
    this.observacoes,
    this.syncStatus = SyncStatus.synced,
  });

  double get restante => total - entrada;

  Venda copyWith({
    String? id,
    String? clienteId,
    DateTime? data,
    List<ItemVenda>? itens,
    double? total,
    double? entrada,
    int? numParcelas,
    String? observacoes,
    SyncStatus? syncStatus,
  }) {
    return Venda(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      data: data ?? this.data,
      itens: itens ?? this.itens,
      total: total ?? this.total,
      entrada: entrada ?? this.entrada,
      numParcelas: numParcelas ?? this.numParcelas,
      observacoes: observacoes ?? this.observacoes,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ItemVenda {
  final String produtoId;
  final int quantidade;
  final double precoUnitario;

  const ItemVenda({
    required this.produtoId,
    required this.quantidade,
    required this.precoUnitario,
  });

  double get total => quantidade * precoUnitario;
}

class Parcela {
  final String id;
  final String vendaId;
  final int numero;
  final int total;
  final double valor;
  final DateTime vencimento;
  final ParcelaStatus status;
  final double valorPago;
  final List<EventoParcela> eventos;
  final SyncStatus syncStatus;

  const Parcela({
    required this.id,
    required this.vendaId,
    required this.numero,
    required this.total,
    required this.valor,
    required this.vencimento,
    required this.status,
    this.valorPago = 0,
    this.eventos = const [],
    this.syncStatus = SyncStatus.synced,
  });

  double get restante => (valor - valorPago).clamp(0, valor).toDouble();
  bool get estaAberta => status != ParcelaStatus.paga;
}

class Pagamento {
  final String id;
  final String parcelaId;
  final DateTime data;
  final double valor;
  final String forma;
  final String? observacoes;
  final SyncStatus syncStatus;

  const Pagamento({
    required this.id,
    required this.parcelaId,
    required this.data,
    required this.valor,
    required this.forma,
    this.observacoes,
    this.syncStatus = SyncStatus.synced,
  });
}

class EventoParcela {
  final EventoTipo tipo;
  final DateTime data;
  final String descricao;
  final double? valor;

  const EventoParcela({
    required this.tipo,
    required this.data,
    required this.descricao,
    this.valor,
  });
}

class Notificacao {
  final String id;
  final String clienteId;
  final String parcelaId;
  final NotificacaoTipo tipo;
  final DateTime data;
  final String texto;
  final double valor;
  final bool lida;

  const Notificacao({
    required this.id,
    required this.clienteId,
    required this.parcelaId,
    required this.tipo,
    required this.data,
    required this.texto,
    required this.valor,
    this.lida = false,
  });
}

class ParcelaResumo {
  final Parcela parcela;
  final Venda venda;
  final Cliente cliente;

  const ParcelaResumo({
    required this.parcela,
    required this.venda,
    required this.cliente,
  });
}

class SalesSnapshot {
  final DateTime hoje;
  final List<Cliente> clientes;
  final List<Produto> produtos;
  final List<Venda> vendas;
  final List<Parcela> parcelas;
  final List<Pagamento> pagamentos;
  final List<Notificacao> notificacoes;

  const SalesSnapshot({
    required this.hoje,
    required this.clientes,
    required this.produtos,
    required this.vendas,
    required this.parcelas,
    required this.pagamentos,
    required this.notificacoes,
  });

  SalesSnapshot copyWith({
    DateTime? hoje,
    List<Cliente>? clientes,
    List<Produto>? produtos,
    List<Venda>? vendas,
    List<Parcela>? parcelas,
    List<Pagamento>? pagamentos,
    List<Notificacao>? notificacoes,
  }) {
    return SalesSnapshot(
      hoje: hoje ?? this.hoje,
      clientes: clientes ?? this.clientes,
      produtos: produtos ?? this.produtos,
      vendas: vendas ?? this.vendas,
      parcelas: parcelas ?? this.parcelas,
      pagamentos: pagamentos ?? this.pagamentos,
      notificacoes: notificacoes ?? this.notificacoes,
    );
  }

  Map<String, Cliente> get clientesById => {
        for (final cliente in clientes) cliente.id: cliente,
      };

  Map<String, Produto> get produtosById => {
        for (final produto in produtos) produto.id: produto,
      };

  Map<String, Venda> get vendasById => {
        for (final venda in vendas) venda.id: venda,
      };

  Cliente? clienteById(String id) => clientesById[id];
  Produto? produtoById(String id) => produtosById[id];
  Venda? vendaById(String id) => vendasById[id];

  List<ParcelaResumo> get parcelasResumo {
    final clientesMap = clientesById;
    final vendasMap = vendasById;
    return parcelas
        .where((parcela) => vendasMap.containsKey(parcela.vendaId))
        .map((parcela) {
      final venda = vendasMap[parcela.vendaId]!;
      final cliente = clientesMap[venda.clienteId]!;
      return ParcelaResumo(parcela: parcela, venda: venda, cliente: cliente);
    }).toList();
  }

  List<ParcelaResumo> get vencemHoje => parcelasResumo
      .where((item) =>
          item.parcela.estaAberta && _sameDate(item.parcela.vencimento, hoje))
      .toList();

  List<ParcelaResumo> get vencemAmanha {
    final amanha = hoje.add(const Duration(days: 1));
    return parcelasResumo
        .where((item) =>
            item.parcela.estaAberta &&
            _sameDate(item.parcela.vencimento, amanha))
        .toList();
  }

  List<ParcelaResumo> get emAtraso => parcelasResumo
      .where((item) =>
          item.parcela.estaAberta &&
          (item.parcela.status == ParcelaStatus.atrasada ||
              item.parcela.vencimento.isBefore(hoje)))
      .toList();

  List<Cliente> get topPagadores {
    final list = clientes.where((c) => c.status == ClienteStatus.good).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(3).toList();
  }

  double get totalMesAReceber => parcelas
      .where((p) =>
          p.estaAberta &&
          p.vencimento.year == hoje.year &&
          p.vencimento.month == hoje.month)
      .fold(0, (total, p) => total + p.restante);

  double get totalHoje =>
      vencemHoje.fold(0, (total, item) => total + item.parcela.restante);

  double get totalAtraso =>
      emAtraso.fold(0, (total, item) => total + item.parcela.restante);

  int get unidadesEmEstoque =>
      produtos.fold(0, (total, produto) => total + produto.estoque);

  double get valorEstoqueCusto => produtos.fold(
        0,
        (total, produto) => total + produto.custo * produto.estoque,
      );

  double get valorVendaPotencial => produtos.fold(
        0,
        (total, produto) => total + produto.precoBase * produto.estoque,
      );

  List<Produto> get produtosSemEstoque =>
      produtos.where((produto) => produto.estoque <= 0).toList();

  List<Produto> get produtosEstoqueBaixo => produtos
      .where((produto) =>
          produto.estoque > 0 &&
          produto.estoque <= (produto.estoqueMinimo + 1).clamp(1, 999))
      .toList();

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
