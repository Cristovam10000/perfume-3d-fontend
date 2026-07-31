import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/commercial_actions.dart';
import '../widgets/sale_actions_menu.dart';
import '../widgets/sales_widgets.dart';

class ClientDetailPage extends ConsumerWidget {
  final String id;

  const ClientDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salesSnapshotProvider);
    final cliente = data.clienteById(id);
    if (cliente == null) {
      return const SalesScaffold(
        showBack: true,
        title: 'Cliente',
        body: Center(child: Text('Cliente nao encontrado.')),
      );
    }

    final vendas = data.vendas.where((v) => v.clienteId == cliente.id).toList();
    final parcelas = data.parcelasResumo
        .where((item) => item.venda.clienteId == cliente.id)
        .toList();

    return SalesScaffold(
      showBack: true,
      actions: [
        // Mesmas acoes da visualizacao da venda, sem `Ver cliente` porque a
        // tela ja e a do cliente.
        SaleActionsButton(
          client: cliente,
          installments: parcelas.map((item) => item.parcela).toList(),
          allowViewClient: false,
        ),
      ],
      body: ListView(
        children: [
          Row(
            children: [
              ClienteAvatar(cliente: cliente, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nome,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${cliente.telefone} · ${cliente.bairro}',
                      style: const TextStyle(
                        color: AppColors.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    StatusPill(status: cliente.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ScoreRing(score: cliente.score, status: cliente.status),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SCORE DO CLIENTE',
                          style: TextStyle(
                            color: AppColors.ink3,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Paga em dia. Pode estender prazo.',
                          style: TextStyle(
                            color: AppColors.ink2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Sem GridView de proporcao fixa: a altura acompanha o texto, que
          // pode ocupar duas linhas em telas menores ou com fonte ampliada.
          _StatRow(
            children: [
              _StatCard(
                  label: 'Em aberto',
                  value: AppFormatters.brl(cliente.emAberto),
                  tone: cliente.status),
              _StatCard(
                  label: 'Compras',
                  value: '${cliente.totalCompras}',
                  tone: ClienteStatus.good),
            ],
          ),
          const SizedBox(height: 10),
          _StatRow(
            children: [
              _StatCard(
                  label: 'Atrasos',
                  value: '${cliente.parcelasAtraso}',
                  tone: cliente.parcelasAtraso > 0
                      ? ClienteStatus.bad
                      : ClienteStatus.good),
              _StatCard(
                  label: 'Total comprado',
                  value: AppFormatters.brl(cliente.totalComprado),
                  tone: ClienteStatus.warn),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('client-new-sale'),
                  onPressed: () => context.pushNamed(
                    AppRoutes.saleNewName,
                    queryParameters: {'clientId': cliente.id},
                  ),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text(
                    'Nova venda',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleIconButton(
                icon: Icons.phone_outlined,
                onPressed: () => _runExternalAction(
                  context,
                  () => openPhoneDialer(cliente),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.chat_outlined,
                onPressed: () => _runExternalAction(
                  context,
                  () => openWhatsAppConversation(client: cliente),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Linha do tempo'),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final venda in vendas) ...[
                  _TimelineRow(
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.accent,
                    title: 'Venda #${venda.id}',
                    subtitle: AppFormatters.date(venda.data),
                    value: venda.total,
                    // Abre a visualizacao da venda (nao o fluxo de criacao).
                    onTap: () => _openSale(context, venda.id),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                ],
                for (final item in parcelas.take(3))
                  _TimelineRow(
                    icon: item.parcela.status == ParcelaStatus.paga
                        ? Icons.check_rounded
                        : Icons.warning_amber_rounded,
                    color: item.parcela.status == ParcelaStatus.paga
                        ? AppColors.good
                        : AppColors.warn,
                    title:
                        'Parcela ${item.parcela.numero}/${item.parcela.total}',
                    subtitle: AppFormatters.compactDate(
                      item.parcela.vencimento,
                    ),
                    value: item.parcela.restante,
                    onTap: () => _openSale(context, item.venda.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

void _openSale(BuildContext context, String saleId) {
  context.pushNamed(
    AppRoutes.saleDetailName,
    pathParameters: {'id': saleId},
  );
}

Future<void> _runExternalAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')),
    );
  }
}

/// Par de cards de metrica com a mesma altura, sem proporcao fixa.
class _StatRow extends StatelessWidget {
  final List<Widget> children;

  const _StatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final ClienteStatus tone;

  const _StatCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink3,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: statusColor(tone),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double value;
  final VoidCallback? onTap;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ids locais de venda sao longos: uma linha com reticencias
                  // evita empurrar a linha do tempo para fora da tela.
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MoneyText(value: value, size: 13),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.ink3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
