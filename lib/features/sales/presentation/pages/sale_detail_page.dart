import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class SaleDetailPage extends ConsumerWidget {
  final String id;

  const SaleDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salesSnapshotProvider);
    final venda = data.vendaById(id);
    if (venda == null) {
      return const SalesScaffold(
        title: 'Venda',
        showBack: true,
        body: Center(child: Text('Venda nao encontrada.')),
      );
    }
    final cliente = data.clienteById(venda.clienteId)!;
    final parcelas =
        data.parcelas.where((parcela) => parcela.vendaId == venda.id).toList();
    final pago = parcelas.fold<double>(0, (sum, p) => sum + p.valorPago);
    final restante = (venda.total - pago).clamp(0, venda.total).toDouble();

    return SalesScaffold(
      title: 'Venda #${venda.id}',
      showBack: true,
      actions: [CircleIconButton(icon: Icons.more_horiz, onPressed: () {})],
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
          SectionHeader(
            title: 'Parcelas',
            action: '${parcelas.length}x',
          ),
          const SizedBox(height: 8),
          for (final parcela in parcelas) ...[
            _InstallmentButton(parcela: parcela),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _InstallmentButton extends StatelessWidget {
  final Parcela parcela;

  const _InstallmentButton({required this.parcela});

  @override
  Widget build(BuildContext context) {
    final tone = _tone(parcela.status);
    return InkWell(
      onTap: parcela.estaAberta ? () {} : null,
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
                borderRadius: BorderRadius.circular(AppRadius.md),
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
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${tone.label} em ${AppFormatters.compactDate(parcela.vencimento)}',
                    style: TextStyle(
                      color: tone.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            MoneyText(value: parcela.restante, size: 13),
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
          icon: Icons.payments_outlined,
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
          label: 'Vence',
          icon: Icons.schedule,
          color: AppColors.ink3,
          soft: AppColors.bgSunken,
        );
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
