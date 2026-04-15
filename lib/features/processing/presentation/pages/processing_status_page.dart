import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../product_viewer/presentation/state/viewer_controller.dart';
import '../../domain/processing_job.dart';
import '../state/processing_controller.dart';

class ProcessingStatusPage extends ConsumerWidget {
  const ProcessingStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(processingControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Processamento',
      showBack: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(
              _iconFor(job.status),
              size: 64,
              color: job.hasError ? scheme.error : scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              job.status.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (job.jobId != null)
              Text(
                'Job: ${job.jobId}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            if (!job.isCompleted && !job.hasError)
              const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              job.error ?? job.message ?? _defaultMessage(job.status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            if (job.isCompleted && job.modelUrl != null)
              PrimaryButton(
                label: 'Visualizar modelo 3D',
                icon: Icons.view_in_ar_outlined,
                onPressed: () {
                  ref
                      .read(viewerControllerProvider.notifier)
                      .load(job.modelUrl!);
                  context.goNamed(AppRoutes.viewerName);
                },
              ),
            if (job.hasError) ...[
              PrimaryButton(
                label: 'Tentar novamente',
                icon: Icons.refresh,
                onPressed: () =>
                    ref.read(processingControllerProvider.notifier).retry(),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Voltar ao início',
                onPressed: () => context.goNamed(AppRoutes.homeName),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ProcessingStatus s) {
    switch (s) {
      case ProcessingStatus.completed:
        return Icons.check_circle_outline;
      case ProcessingStatus.error:
        return Icons.error_outline;
      case ProcessingStatus.processing:
        return Icons.settings_suggest_outlined;
      case ProcessingStatus.uploaded:
        return Icons.cloud_done_outlined;
      case ProcessingStatus.waiting:
        return Icons.hourglass_empty;
      case ProcessingStatus.idle:
        return Icons.pending_outlined;
    }
  }

  String _defaultMessage(ProcessingStatus s) {
    switch (s) {
      case ProcessingStatus.completed:
        return 'Modelo 3D pronto para visualização.';
      case ProcessingStatus.processing:
        return 'O servidor está gerando o modelo 3D. Isto pode demorar alguns minutos.';
      case ProcessingStatus.uploaded:
        return 'As imagens chegaram ao servidor.';
      case ProcessingStatus.waiting:
        return 'Seu job está na fila.';
      case ProcessingStatus.error:
        return 'Ocorreu um erro no processamento.';
      case ProcessingStatus.idle:
        return 'Nenhum job em andamento.';
    }
  }
}
