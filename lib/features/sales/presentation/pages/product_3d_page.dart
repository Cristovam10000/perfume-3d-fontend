import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/sales_repository.dart';
import '../widgets/product_visuals.dart';
import '../widgets/sales_widgets.dart';

class Product3DPage extends ConsumerWidget {
  final String id;

  const Product3DPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salesSnapshotProvider);
    final produto = data.produtoById(id);
    if (produto == null) {
      return const SalesScaffold(
        title: '3D',
        showBack: true,
        body: Center(child: Text('Produto nao encontrado.')),
      );
    }

    return SalesScaffold(
      title: produto.nome,
      showBack: true,
      padding: EdgeInsets.zero,
      actions: [
        CircleIconButton(
          icon: Icons.ios_share_outlined,
          onPressed: () {},
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.bg, Color(0xFFFFF8FA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goodSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: AppColors.good, size: 10),
                        SizedBox(width: 8),
                        Text(
                          '3D disponivel',
                          style: TextStyle(
                            color: AppColors.good,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: ProductStagePreview(produto: produto),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.control_camera_outlined,
                        color: AppColors.ink3,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Arraste para girar',
                        style: TextStyle(
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            decoration: const BoxDecoration(
              color: AppColors.bgElev,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${produto.categoria.toUpperCase()} · ${produto.volumeMl} ML',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.ink3,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MoneyText(
                            value: produto.precoBase,
                            size: 26,
                            color: AppColors.ink,
                            weight: FontWeight.w900,
                          ),
                        ],
                      ),
                    ),
                    const _ViewerIconButton(icon: Icons.remove_rounded),
                    const SizedBox(width: 10),
                    const _ViewerIconButton(icon: Icons.add_rounded),
                    const SizedBox(width: 10),
                    const _ViewerIconButton(icon: Icons.sync_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: produto.estoque > 0
                      ? () => context.pushNamed(AppRoutes.saleNewName)
                      : null,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Vender este produto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  final IconData icon;

  const _ViewerIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 38,
      child: Icon(icon, color: AppColors.ink, size: 24),
    );
  }
}
