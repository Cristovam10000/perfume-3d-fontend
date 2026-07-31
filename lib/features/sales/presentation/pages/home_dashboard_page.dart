import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salesSnapshotProvider);
    return SalesScaffold(
      currentIndex: 0,
      titleWidget: const _HomeTitle(),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(
              icon: Icons.notifications_none_rounded,
              onPressed: () => context.pushNamed(AppRoutes.notificationsName),
            ),
            if (data.notificacoesNaoLidas > 0)
              Positioned(
                right: -2,
                top: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    data.notificacoesNaoLidas > 99
                        ? '99+'
                        : '${data.notificacoesNaoLidas}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      body: ListView(
        children: [
          _HeroBalanceCard(data: data),
          const SizedBox(height: 16),
          _QuickActions(data: data),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Vencem hoje',
            action: 'Ver tudo',
            onAction: () => context.goNamed(AppRoutes.billingName),
          ),
          const SizedBox(height: 8),
          for (final item in data.vencemHoje.take(3)) ...[
            PaymentDueCard(
              item: item,
              onTap: () => context.pushNamed(
                AppRoutes.saleDetailName,
                pathParameters: {'id': item.venda.id},
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (data.emAtraso.isNotEmpty) ...[
            const SizedBox(height: 10),
            const SectionHeader(title: 'Em atraso'),
            const SizedBox(height: 8),
            for (final item in data.emAtraso.take(2)) ...[
              PaymentDueCard(
                item: item,
                danger: true,
                onTap: () => context.pushNamed(
                  AppRoutes.saleDetailName,
                  pathParameters: {'id': item.venda.id},
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 10),
          const SectionHeader(title: 'Top pagadores'),
          const SizedBox(height: 8),
          // Altura vinda do conteudo (IntrinsicHeight) em vez de fixa: com a
          // fonte do sistema ampliada o card cresce sem estourar.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < data.topPagadores.length; i++) ...[
                    if (i != 0) const SizedBox(width: 10),
                    _TopPayerCard(index: i, cliente: data.topPagadores[i]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}

class _HomeTitle extends StatelessWidget {
  const _HomeTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bom dia,',
          style: TextStyle(
            color: AppColors.ink3,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Raimunda',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  final SalesSnapshot data;

  const _HeroBalanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          colors: [AppColors.darkCard, AppColors.darkCard2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A RECEBER ESTE MES',
            style: TextStyle(
              color: Color(0xFFD7CDBB),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          MoneyText(
            value: data.totalMesAReceber,
            size: 30,
            color: Colors.white,
            weight: FontWeight.w900,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroMetric(
                label: 'Hoje',
                value: data.totalHoje,
                color: AppColors.warn,
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white.withValues(alpha: 0.18),
              ),
              _HeroMetric(
                label: 'Em atraso',
                value: data.totalAtraso,
                color: const Color(0xFFFF9A9A),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC8BBA7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          MoneyText(value: value, size: 14, color: color),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final SalesSnapshot data;

  const _QuickActions({required this.data});

  @override
  Widget build(BuildContext context) {
    final productsWith3D =
        data.produtos.where((product) => product.tem3D).toList();
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            label: 'Vender',
            icon: Icons.receipt_long_outlined,
            color: AppColors.accent,
            bg: AppColors.accentSoft,
            onTap: () => context.pushNamed(AppRoutes.saleNewName),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickAction(
            label: 'Cliente',
            icon: Icons.people_alt_outlined,
            color: AppColors.teal,
            bg: AppColors.tealSoft,
            onTap: () => context.goNamed(AppRoutes.clientsName),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickAction(
            label: 'Capturar',
            icon: Icons.camera_alt_outlined,
            color: AppColors.ink,
            bg: AppColors.bgSunken,
            onTap: () => context.pushNamed(AppRoutes.captureCameraName),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _QuickAction(
            label: '3D',
            icon: Icons.view_in_ar_outlined,
            color: AppColors.ink,
            bg: const Color(0xFFE9E0D0),
            onTap: productsWith3D.isEmpty
                ? () => context.goNamed(AppRoutes.productsName)
                : () => context.pushNamed(
                      AppRoutes.product3dName,
                      pathParameters: {'id': productsWith3D.first.id},
                    ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.ink, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPayerCard extends StatelessWidget {
  final int index;
  final Cliente cliente;

  const _TopPayerCard({required this.index, required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#${index + 1}',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            cliente.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Score ${cliente.score}',
            style: const TextStyle(
              color: AppColors.ink3,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
