import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    final groups = [
      _BillingGroup('Hoje', data.vencemHoje, AppColors.warn),
      _BillingGroup('Amanha', data.vencemAmanha, AppColors.accent),
      _BillingGroup('Atraso', data.emAtraso, AppColors.bad),
    ];
    final current = groups[_tab];

    return SalesScaffold(
      title: 'Cobranca',
      currentIndex: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                Expanded(
                  child: _BillingTab(
                    label: groups[i].label,
                    count: groups[i].items.length,
                    color: groups[i].color,
                    selected: i == _tab,
                    onTap: () => setState(() => _tab = i),
                  ),
                ),
                if (i != groups.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: current.items.isEmpty
                ? const Center(child: Text('Nenhuma cobranca por aqui.'))
                : ListView.separated(
                    itemCount: current.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = current.items[index];
                      return PaymentDueCard(
                        item: item,
                        danger: _tab == 2,
                        onTap: () => context.pushNamed(
                          AppRoutes.saleDetailName,
                          pathParameters: {'id': item.venda.id},
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BillingGroup {
  final String label;
  final List<ParcelaResumo> items;
  final Color color;

  const _BillingGroup(this.label, this.items, this.color);
}

class _BillingTab extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _BillingTab({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bgElev,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '$label $count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.ink2,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
