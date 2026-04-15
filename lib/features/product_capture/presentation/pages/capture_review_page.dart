import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/image_counter.dart';
import '../../../../shared/widgets/image_grid.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/quality_banner.dart';
import '../../../processing/presentation/state/processing_controller.dart';
import '../state/capture_controller.dart';

class CaptureReviewPage extends ConsumerWidget {
  const CaptureReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);

    Future<void> onSubmit() async {
      final jobId = await controller.submit();
      if (!context.mounted) return;
      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? 'Falha no envio.')),
        );
        return;
      }
      ref.read(processingControllerProvider.notifier).start(jobId);
      context.goNamed(AppRoutes.processingName);
    }

    return AppScaffold(
      title: 'Revisão das imagens',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ImageCounter(count: state.count),
          ),
          if (state.qualityMessages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QualityBanner(message: state.qualityMessages.first),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: CapturedImageGrid(
              images: state.images,
              onRemove: state.uploading ? null : controller.removeAt,
            ),
          ),
          if (state.uploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LinearProgressIndicator(value: state.uploadProgress),
            ),
        ],
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SecondaryButton(
            label: 'Capturar mais',
            icon: Icons.add_a_photo_outlined,
            onPressed: state.uploading
                ? null
                : () => context.goNamed(AppRoutes.captureCameraName),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Enviar para processamento',
            icon: Icons.cloud_upload_outlined,
            loading: state.uploading,
            onPressed: state.canReview ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
