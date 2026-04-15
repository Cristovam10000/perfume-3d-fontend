import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../processing/presentation/state/processing_controller.dart';
import '../state/viewer_controller.dart';

class Product3DViewerPage extends ConsumerWidget {
  const Product3DViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(viewerControllerProvider);

    Widget body;
    if (state.loading) {
      body = const LoadingView(message: 'Carregando modelo 3D...');
    } else if (state.error != null) {
      body = ErrorView(
        message: state.error!,
        onRetry: () {
          final url = state.model?.modelUrl;
          if (url != null) {
            ref.read(viewerControllerProvider.notifier).load(url);
          }
        },
      );
    } else if (state.model == null) {
      body = const ErrorView(message: 'Nenhum modelo carregado.');
    } else {
      final m = state.model!;
      body = Column(
        children: [
          Expanded(
            child: ModelViewer(
              src: m.modelUrl,
              alt: 'Modelo 3D do perfume',
              ar: false,
              autoRotate: true,
              cameraControls: true,
              disableZoom: false,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name ?? 'Perfume',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (m.brand != null)
                  Text(
                    m.brand!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return AppScaffold(
      title: 'Modelo 3D',
      body: body,
      bottomBar: PrimaryButton(
        label: 'Concluir',
        icon: Icons.check,
        onPressed: () {
          ref.read(processingControllerProvider.notifier).reset();
          ref.read(viewerControllerProvider.notifier).reset();
          context.goNamed(AppRoutes.homeName);
        },
      ),
    );
  }
}
