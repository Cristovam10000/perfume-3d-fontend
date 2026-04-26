import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/sales_repository.dart';
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
    final modelUrl = produto.modelo3DPath;
    return SalesScaffold(
      title: produto.nome,
      showBack: true,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Colors.white, AppColors.bgSunken],
                      center: Alignment.topCenter,
                      radius: 1.1,
                    ),
                  ),
                ),
                if (modelUrl != null)
                  ModelViewer(
                    src: modelUrl,
                    autoRotate: false,
                    cameraControls: true,
                    disableZoom: false,
                    backgroundColor: AppColors.bg,
                  )
                else
                  const Center(child: Text('Produto ainda nao tem modelo 3D.')),
                Positioned(
                  left: 20,
                  top: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.goodSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      '● 3D disponivel',
                      style: TextStyle(
                        color: AppColors.good,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Text(
                    'Arraste para girar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: const BoxDecoration(
              color: AppColors.bgElev,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.categoria.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.ink3,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      MoneyText(
                        value: produto.precoBase,
                        size: 22,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.pushNamed(AppRoutes.saleNewName),
                  child: const Text('Vender'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
