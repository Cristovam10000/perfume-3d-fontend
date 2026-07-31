import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/date_math.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import 'commercial_actions.dart';
import 'sales_widgets.dart';

enum _SaleAction { viewClient, editClient, whatsapp, dueDate, deleteClient }

/// Botao de tres pontos com as acoes comerciais de uma venda.
///
/// A mesma folha e usada na visualizacao da venda e no detalhe do cliente, para
/// que as duas telas ofereçam exatamente as mesmas acoes sem duplicar logica.
class SaleActionsButton extends ConsumerStatefulWidget {
  /// Cliente dono das parcelas em [installments].
  final Cliente client;

  /// Parcelas no escopo da tela (de uma venda ou de todas as vendas do
  /// cliente). Define o que pode ser renegociado e cobrado.
  final List<Parcela> installments;

  /// Some com `Ver cliente` quando a tela ja e a do proprio cliente.
  final bool allowViewClient;

  /// Exibe a exclusao apenas no detalhe do cliente, nunca no menu da venda.
  final bool allowDeleteClient;

  final VoidCallback? onClientDeleted;

  const SaleActionsButton({
    super.key,
    required this.client,
    required this.installments,
    this.allowViewClient = true,
    this.allowDeleteClient = false,
    this.onClientDeleted,
  });

  @override
  ConsumerState<SaleActionsButton> createState() => _SaleActionsButtonState();
}

class _SaleActionsButtonState extends ConsumerState<SaleActionsButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      key: const ValueKey('sale-actions-button'),
      icon: _busy ? Icons.hourglass_top_rounded : Icons.more_horiz,
      onPressed: _busy ? null : _openSheet,
    );
  }

  Future<void> _openSheet() async {
    final hasOpen = widget.installments.any((item) => item.estaAberta);
    final action = await showModalBottomSheet<_SaleAction>(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowViewClient)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Ver cliente'),
                onTap: () =>
                    Navigator.pop(sheetContext, _SaleAction.viewClient),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar cliente'),
              onTap: () => Navigator.pop(sheetContext, _SaleAction.editClient),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Cobrar pelo WhatsApp'),
              onTap: () => Navigator.pop(sheetContext, _SaleAction.whatsapp),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: const Text('Renegociar vencimento'),
              onTap: hasOpen
                  ? () => Navigator.pop(sheetContext, _SaleAction.dueDate)
                  : null,
            ),
            if (widget.allowDeleteClient)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.bad,
                ),
                title: const Text(
                  'Excluir cliente',
                  style: TextStyle(color: AppColors.bad),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _SaleAction.deleteClient),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SaleAction.viewClient:
        context.pushNamed(
          AppRoutes.clientDetailName,
          pathParameters: {'id': widget.client.id},
        );
        return;
      case _SaleAction.editClient:
        await _editClient();
        return;
      case _SaleAction.whatsapp:
        await _chargeByWhatsApp();
        return;
      case _SaleAction.dueDate:
        await _renegotiate();
        return;
      case _SaleAction.deleteClient:
        await _deleteClient();
        return;
    }
  }

  Future<void> _editClient() async {
    final value = await showClientForm(context, client: widget.client);
    if (value == null || !mounted) return;
    await _run(
      () => ref.read(salesControllerProvider.notifier).updateClient(
            widget.client.copyWith(
              nome: value.name,
              telefone: value.phone,
              bairro: value.neighborhood,
            ),
          ),
      success: 'Cliente atualizado.',
    );
  }

  Future<void> _chargeByWhatsApp() async {
    final openItems = widget.installments
        .where((item) => item.estaAberta)
        .toList()
      ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
    final open = openItems.isEmpty ? null : openItems.first;
    await _run(
      () => openWhatsAppCollection(client: widget.client, installment: open),
    );
  }

  Future<void> _deleteClient() async {
    final hasSales = ref
        .read(salesSnapshotProvider)
        .vendas
        .any((sale) => sale.clienteId == widget.client.id);
    if (hasSales) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não é possível excluir um cliente que possui vendas. '
            'O histórico financeiro precisa ser preservado.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(
          'O cliente ${widget.client.nome} será removido da lista. '
          'Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await _run(
      () => ref
          .read(salesControllerProvider.notifier)
          .deleteClient(widget.client.id),
      success: 'Cliente excluído.',
    );
    if (deleted && mounted) widget.onClientDeleted?.call();
  }

  Future<void> _renegotiate() async {
    final installment = await chooseOpenInstallment(
      context,
      installments: widget.installments,
    );
    if (installment == null || !mounted) return;
    await rescheduleInstallmentFlow(
      context,
      ref,
      installment: installment,
      setBusy: _setBusy,
    );
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  Future<bool> _run(
    Future<void> Function() operation, {
    String? success,
  }) async {
    if (_busy) return false;
    _setBusy(true);
    try {
      return await runSalesAction(context, operation, success: success);
    } finally {
      _setBusy(false);
    }
  }
}

/// Escolhe qual parcela aberta sera remarcada. Com uma unica em aberto,
/// resolve direto sem perguntar.
Future<Parcela?> chooseOpenInstallment(
  BuildContext context, {
  required List<Parcela> installments,
}) {
  final open = installments.where((item) => item.estaAberta).toList()
    ..sort((a, b) => a.vencimento.compareTo(b.vencimento));
  if (open.isEmpty) return Future.value();
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
              'vence ${AppFormatters.numericDate(installment.vencimento)} · '
              '${AppFormatters.brl(installment.restante)}',
            ),
          ),
      ],
    ),
  );
}

/// Altera o vencimento de uma parcela sem registrar um recebimento.
///
/// Depois de salvar a parcela escolhida, oferece editar individualmente cada
/// parcela seguinte em aberto.
Future<void> rescheduleInstallmentFlow(
  BuildContext context,
  WidgetRef ref, {
  required Parcela installment,
  void Function(bool busy)? setBusy,
}) async {
  final newDate = await showRenegotiationDate(
    context,
    installment: installment,
  );
  if (newDate == null || !context.mounted) return;
  if (isSameDay(newDate, installment.vencimento)) return;

  final saved = await _saveInstallmentDueDate(
    context,
    ref,
    installment: installment,
    dueDate: newDate,
    setBusy: setBusy,
    success: 'Vencimento da parcela atualizado.',
  );
  if (!saved || !context.mounted) return;

  final following = ref.read(salesSnapshotProvider).parcelasSeguintes(
        installment,
      );
  if (following.isEmpty) return;
  final confirmed = await confirmShiftFollowingInstallments(
    context,
    following: following.length,
  );
  if (confirmed != true || !context.mounted) return;

  var previousDate = dateOnly(newDate);
  var changed = 0;
  for (final original in following) {
    if (!context.mounted) return;
    var current = original;
    for (final candidate in ref.read(salesSnapshotProvider).parcelas) {
      if (candidate.id == original.id) {
        current = candidate;
        break;
      }
    }
    final selected = await showRenegotiationDate(
      context,
      installment: current,
      suggestedDate: addMonthsClamped(previousDate, 1),
    );
    if (selected == null || !context.mounted) break;
    final saved = await _saveInstallmentDueDate(
      context,
      ref,
      installment: current,
      dueDate: selected,
      setBusy: setBusy,
    );
    if (!saved || !context.mounted) return;
    previousDate = dateOnly(selected);
    changed += 1;
  }

  if (changed > 0 && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed == 1
              ? 'Data da próxima parcela atualizada.'
              : 'Datas de $changed parcelas seguintes atualizadas.',
        ),
      ),
    );
  }
}

Future<bool> _saveInstallmentDueDate(
  BuildContext context,
  WidgetRef ref, {
  required Parcela installment,
  required DateTime dueDate,
  void Function(bool busy)? setBusy,
  String? success,
}) async {
  setBusy?.call(true);
  try {
    return await runSalesAction(
      context,
      () => ref.read(salesControllerProvider.notifier).renegotiateInstallment(
            installmentId: installment.id,
            dueDate: dueDate,
          ),
      success: success,
    );
  } finally {
    setBusy?.call(false);
  }
}
