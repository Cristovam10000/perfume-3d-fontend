import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/commercial_actions.dart';
import '../widgets/sales_widgets.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  final String id;
  final Venda? draftVenda;

  const SaleDetailPage({
    super.key,
    required this.id,
    this.draftVenda,
  });

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    final storedVenda = data.vendaById(widget.id);
    final venda = storedVenda ?? widget.draftVenda;
    if (venda == null) {
      return const SalesScaffold(
        title: 'Venda',
        showBack: true,
        body: Center(child: Text('Venda nao encontrada.')),
      );
    }
    final cliente = data.clienteById(venda.clienteId);
    if (cliente == null) {
      return const SalesScaffold(
        title: 'Venda',
        showBack: true,
        body: Center(child: Text('Cliente nao encontrado.')),
      );
    }

    final storedParcelas =
        data.parcelas.where((parcela) => parcela.vendaId == venda.id).toList();
    final parcelas = storedParcelas.isEmpty
        ? _buildDraftInstallments(venda)
        : storedParcelas;
    final pago = venda.entrada +
        parcelas.fold<double>(0, (sum, parcela) => sum + parcela.valorPago);
    final restante = (venda.total - pago).clamp(0, venda.total).toDouble();
    final parcelaBase = parcelas.isEmpty
        ? 0
        : parcelas.fold<double>(0, (s, p) => s + p.valor) / parcelas.length;

    return SalesScaffold(
      title: 'Venda #${venda.id}',
      showBack: true,
      actions: [
        CircleIconButton(
          icon: _busy ? Icons.hourglass_top_rounded : Icons.more_horiz,
          onPressed:
              _busy ? null : () => _showSaleActions(venda, cliente, parcelas),
        ),
      ],
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClienteAvatar(cliente: cliente),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nome,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          AppFormatters.date(venda.data),
                          style: const TextStyle(
                            color: AppColors.ink3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chat_bubble_outline, color: AppColors.ink3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: AppColors.ink3,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      MoneyText(value: venda.total, size: 22),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: venda.total == 0 ? 0 : pago / venda.total,
                        minHeight: 8,
                        backgroundColor: AppColors.bgSunken,
                        color: AppColors.good,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Pago ${AppFormatters.brl(pago)}',
                        style: const TextStyle(
                          color: AppColors.good,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Restante ${AppFormatters.brl(restante)}',
                        style: const TextStyle(
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SaleSectionHeader(
            title: 'Parcelas',
            pill: parcelas.isEmpty
                ? null
                : '${parcelas.length}x ${AppFormatters.brl(parcelaBase)}',
          ),
          const SizedBox(height: 8),
          for (final parcela in parcelas) ...[
            _InstallmentButton(
              parcela: parcela,
              onTap: _busy ? null : () => _receive(parcela),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const _SaleSectionHeader(title: 'Itens vendidos'),
          const SizedBox(height: 8),
          _SoldItemsCard(venda: venda, data: data),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _receive(Parcela installment) async {
    final value = await showPaymentForm(context, installment: installment);
    if (value == null || !mounted) return;
    final requestId =
        'payment-${installment.id}-${DateTime.now().microsecondsSinceEpoch}';
    await _run(
      () => ref.read(salesControllerProvider.notifier).receivePayment(
            installmentId: installment.id,
            value: value.value,
            date: value.date,
            method: value.method,
            notes: value.notes,
            requestId: requestId,
          ),
      success: 'Pagamento registrado.',
    );
  }

  Future<void> _showSaleActions(
    Venda sale,
    Cliente client,
    List<Parcela> installments,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Ver cliente'),
              onTap: () => Navigator.pop(sheetContext, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar cliente'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Cobrar pelo WhatsApp'),
              onTap: () => Navigator.pop(sheetContext, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: const Text('Renegociar vencimento'),
              onTap: installments.any((item) => item.estaAberta)
                  ? () => Navigator.pop(sheetContext, 'dueDate')
                  : null,
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'view':
        context.pushNamed(
          AppRoutes.clientDetailName,
          pathParameters: {'id': client.id},
        );
        return;
      case 'edit':
        final value = await showClientForm(context, client: client);
        if (value == null || !mounted) return;
        await _run(
          () => ref.read(salesControllerProvider.notifier).updateClient(
                client.copyWith(
                  nome: value.name,
                  telefone: value.phone,
                  bairro: value.neighborhood,
                ),
              ),
          success: 'Cliente atualizado.',
        );
        return;
      case 'whatsapp':
        final openItems =
            installments.where((item) => item.estaAberta).toList();
        final open = openItems.isEmpty ? null : openItems.first;
        await _run(
          () => openWhatsAppCollection(client: client, installment: open),
        );
        return;
      case 'dueDate':
        final installment = await _chooseOpenInstallment(installments);
        if (installment == null || !mounted) return;
        final date = await showRenegotiationDate(
          context,
          installment: installment,
        );
        if (date == null || !mounted) return;
        await _run(
          () =>
              ref.read(salesControllerProvider.notifier).renegotiateInstallment(
                    installmentId: installment.id,
                    dueDate: date,
                  ),
          success: 'Vencimento renegociado.',
        );
        return;
    }
  }

  Future<Parcela?> _chooseOpenInstallment(List<Parcela> installments) {
    final open = installments.where((item) => item.estaAberta).toList();
    if (open.length == 1) return Future.value(open.first);
    return showDialog<Parcela>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Escolha a parcela'),
        children: [
          for (final installment in open)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, installment),
              child: Text(
                'Parcela ${installment.numero}/${installment.total} · '
                '${AppFormatters.brl(installment.restante)}',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    Future<void> Function() operation, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (!mounted) return;
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          action: SnackBarAction(
            label: 'Tentar novamente',
            onPressed: () => _run(operation, success: success),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Parcela> _buildDraftInstallments(Venda venda) {
    final restante = venda.restante.clamp(0, venda.total).toDouble();
    if (restante <= 0) return const [];

    final count = venda.numParcelas <= 0 ? 1 : venda.numParcelas;
    final baseValue = restante / count;
    final startDate =
        DateTime(venda.data.year, venda.data.month, venda.data.day);

    return List.generate(count, (index) {
      final numero = index + 1;
      return Parcela(
        id: '${venda.id}-$numero',
        vendaId: venda.id,
        numero: numero,
        total: count,
        valor: baseValue,
        vencimento: DateTime(
          startDate.year,
          startDate.month + numero,
          startDate.day,
        ),
        status: ParcelaStatus.pendente,
        syncStatus: SyncStatus.pending,
      );
    });
  }
}

class _SaleSectionHeader extends StatelessWidget {
  final String title;
  final String? pill;

  const _SaleSectionHeader({
    required this.title,
    this.pill,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.ink3,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),
        if (pill != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              pill!,
              style: const TextStyle(
                color: AppColors.ink2,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _SoldItemsCard extends StatelessWidget {
  final Venda venda;
  final SalesSnapshot data;

  const _SoldItemsCard({
    required this.venda,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < venda.itens.length; i++) ...[
            _SoldItemRow(
              item: venda.itens[i],
              produto: data.produtoById(venda.itens[i].produtoId),
            ),
            if (i != venda.itens.length - 1)
              const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _SoldItemRow extends StatelessWidget {
  final ItemVenda item;
  final Produto? produto;

  const _SoldItemRow({
    required this.item,
    required this.produto,
  });

  @override
  Widget build(BuildContext context) {
    final nome = produto?.nome ?? 'Produto removido';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _ProductSwatch(produtoId: item.produtoId),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${item.quantidade}x ${AppFormatters.brl(item.precoUnitario)}',
                  style: const TextStyle(
                    color: AppColors.ink3,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MoneyText(value: item.total, size: 16),
        ],
      ),
    );
  }
}

class _ProductSwatch extends StatelessWidget {
  final String produtoId;

  const _ProductSwatch({required this.produtoId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _productColor(produtoId),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

class _InstallmentButton extends StatelessWidget {
  final Parcela parcela;
  final VoidCallback? onTap;

  const _InstallmentButton({
    required this.parcela,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _tone(parcela.status);
    final subtitle = _subtitle(parcela, tone);
    final actionColor =
        parcela.estaAberta ? AppColors.accent : Colors.transparent;
    return InkWell(
      onTap: parcela.estaAberta ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgElev,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.soft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(tone.icon, color: tone.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parcela ${parcela.numero}/${parcela.total}',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: tone.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(value: parcela.restante, size: 14),
                const SizedBox(height: 4),
                Text(
                  parcela.estaAberta ? 'Receber ->' : 'Recebida',
                  style: TextStyle(
                    color: actionColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _InstallmentTone _tone(ParcelaStatus status) {
    switch (status) {
      case ParcelaStatus.paga:
        return const _InstallmentTone(
          label: 'Paga',
          icon: Icons.check_rounded,
          color: AppColors.good,
          soft: AppColors.goodSoft,
        );
      case ParcelaStatus.parcial:
        return const _InstallmentTone(
          label: 'Parcial',
          icon: Icons.sync_rounded,
          color: AppColors.warn,
          soft: AppColors.warnSoft,
        );
      case ParcelaStatus.atrasada:
        return const _InstallmentTone(
          label: 'Atrasada',
          icon: Icons.warning_amber_rounded,
          color: AppColors.bad,
          soft: AppColors.badSoft,
        );
      case ParcelaStatus.pendente:
        return const _InstallmentTone(
          label: 'Pendente',
          icon: Icons.schedule,
          color: AppColors.ink3,
          soft: AppColors.bgSunken,
        );
    }
  }

  String _subtitle(Parcela parcela, _InstallmentTone tone) {
    switch (parcela.status) {
      case ParcelaStatus.paga:
        return 'Paga em ${AppFormatters.compactDate(parcela.vencimento)}';
      case ParcelaStatus.parcial:
        return 'Parcial - ${AppFormatters.brl(parcela.valorPago)} de ${AppFormatters.brl(parcela.valor)}';
      case ParcelaStatus.atrasada:
        return 'Em atraso - vence ${AppFormatters.compactDate(parcela.vencimento)}';
      case ParcelaStatus.pendente:
        return '${tone.label} - vence ${AppFormatters.compactDate(parcela.vencimento)}';
    }
  }
}

class _InstallmentTone {
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;

  const _InstallmentTone({
    required this.label,
    required this.icon,
    required this.color,
    required this.soft,
  });
}

Color _productColor(String produtoId) {
  final digits = RegExp(r'\d+').firstMatch(produtoId)?.group(0);
  final index = ((int.tryParse(digits ?? '1') ?? 1) - 1).clamp(0, 999).toInt();
  const colors = [
    Color(0xFFCB3E7B),
    Color(0xFF4863A8),
    Color(0xFFB13B72),
    Color(0xFF94683E),
    Color(0xFFC83D7B),
    Color(0xFF336D88),
  ];
  return colors[index % colors.length];
}
