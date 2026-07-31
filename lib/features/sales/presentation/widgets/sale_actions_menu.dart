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

enum _SaleAction { viewClient, editClient, whatsapp, dueDate }

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

  const SaleActionsButton({
    super.key,
    required this.client,
    required this.installments,
    this.allowViewClient = true,
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

  Future<void> _renegotiate() async {
    final installment = await chooseOpenInstallment(
      context,
      installments: widget.installments,
    );
    if (installment == null || !mounted) return;
    final date = await showRenegotiationDate(context, installment: installment);
    if (date == null || !mounted) return;
    final done = await _run(
      () => ref.read(salesControllerProvider.notifier).renegotiateInstallment(
            installmentId: installment.id,
            dueDate: date,
          ),
      success: 'Vencimento renegociado.',
    );
    if (!done || !mounted) return;
    await maybeShiftFollowingInstallments(
      context,
      ref,
      installment: installment,
      newDate: date,
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

/// Pergunta e, se confirmado, recalcula as datas das parcelas seguintes
/// mantendo um mes de intervalo a partir de [newDate].
///
/// Nao faz nada quando a data nao mudou ou quando nao ha parcelas posteriores
/// em aberto. [setBusy] permite que a tela chamadora reflita o carregamento.
Future<void> maybeShiftFollowingInstallments(
  BuildContext context,
  WidgetRef ref, {
  required Parcela installment,
  required DateTime newDate,
  void Function(bool busy)? setBusy,
}) async {
  if (isSameDay(newDate, installment.vencimento)) return;
  final following = ref.read(salesSnapshotProvider).parcelasSeguintes(
        installment,
      );
  if (following.isEmpty) return;
  final confirmed = await confirmShiftFollowingInstallments(
    context,
    following: following.length,
  );
  if (confirmed != true || !context.mounted) return;
  setBusy?.call(true);
  try {
    await runSalesAction(
      context,
      () =>
          ref.read(salesControllerProvider.notifier).shiftFollowingInstallments(
                installmentId: installment.id,
                anchorDate: newDate,
              ),
      success: 'Datas das próximas parcelas atualizadas.',
    );
  } finally {
    setBusy?.call(false);
  }
}
