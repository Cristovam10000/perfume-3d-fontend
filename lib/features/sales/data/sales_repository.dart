import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sales_models.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return MockSalesRepository();
});

final salesSnapshotProvider = Provider<SalesSnapshot>((ref) {
  return ref.watch(salesRepositoryProvider).loadSnapshot();
});

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
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-khamrah.glb',
      ),
      Produto(
        id: 'p2',
        nome: 'Armaf Club de Nuit',
        categoria: 'Masculino',
        precoBase: 360,
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-club.glb',
      ),
      Produto(
        id: 'p3',
        nome: 'Maison Alhambra Layali',
        categoria: 'Feminino',
        precoBase: 280,
        tem3D: false,
      ),
      Produto(
        id: 'p4',
        nome: 'Al Haramain Amber Oud',
        categoria: 'Unissex',
        precoBase: 420,
        tem3D: true,
        modelo3DPath: 'http://localhost:8000/files/models/demo-amber.glb',
      ),
      Produto(
        id: 'p5',
        nome: 'Lattafa Yara',
        categoria: 'Feminino',
        precoBase: 240,
        tem3D: false,
        syncStatus: SyncStatus.pending,
      ),
      Produto(
        id: 'p6',
        nome: 'Rasasi Hawas',
        categoria: 'Masculino',
        precoBase: 380,
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
