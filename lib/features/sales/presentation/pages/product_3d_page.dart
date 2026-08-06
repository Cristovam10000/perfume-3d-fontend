import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/app_constants.dart';
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
      actions: const [],
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
                // O selo segue o modelo de verdade. Era fixo em "3D disponivel"
                // e contradizia a tela: sem modelo, o placeholder aparecia
                // embaixo de um selo verde dizendo que havia 3D.
                Positioned(
                  left: 20,
                  top: 18,
                  child: _SeloModelo(temModelo: produto.modelo3DPath != null),
                ),
                Positioned.fill(
                  top: 58,
                  bottom: 38,
                  child: produto.modelo3DPath == null
                      ? Center(child: ProductStagePreview(produto: produto))
                      : ModelViewer(
                          src: AppConstants.resolveBackendUrl(
                            produto.modelo3DPath!,
                          ),
                          alt: 'Modelo 3D de ${produto.nome}',
                          ar: false,
                          autoRotate: true,
                          cameraControls: true,
                          disableZoom: false,
                          backgroundColor: Colors.transparent,
                          relatedJs: AppConstants.dracoRelatedJs,
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.pushNamed(
                    AppRoutes.captureByProductName,
                    pathParameters: {'produtoId': produto.id},
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Gerar novo molde 3D'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeloModelo extends StatelessWidget {
  final bool temModelo;

  const _SeloModelo({required this.temModelo});

  @override
  Widget build(BuildContext context) {
    final cor = temModelo ? AppColors.good : AppColors.warn;
    final fundo = temModelo ? AppColors.goodSoft : AppColors.warnSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: cor, size: 10),
          const SizedBox(width: 8),
          Text(
            temModelo ? '3D disponivel' : 'Sem modelo 3D',
            style: TextStyle(color: cor, fontWeight: FontWeight.w900),
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
