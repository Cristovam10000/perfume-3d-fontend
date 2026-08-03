import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/image_counter.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/quality_banner.dart';
import '../../../processing/presentation/state/processing_controller.dart';
import '../state/capture_controller.dart';

@visibleForTesting
ImageProvider<Object> capturePreviewImageProvider(
  File file, {
  required int cacheWidth,
}) {
  return ResizeImage(FileImage(file), width: cacheWidth);
}

/// Tela principal de captura guiada (4 vistas + topo opcional + 2 extras).
///
/// Cada slot abre a câmera nativa direcionada à vista correspondente.
/// O botão "Enviar" só ativa quando as 4 cardeais estão preenchidas.
class CaptureViewsPage extends ConsumerStatefulWidget {
  const CaptureViewsPage({super.key, this.productId});

  final int? productId;

  @override
  ConsumerState<CaptureViewsPage> createState() => _CaptureViewsPageState();
}

class _CaptureViewsPageState extends ConsumerState<CaptureViewsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(captureControllerProvider.notifier)
          .setProductId(widget.productId),
    );
  }

  @override
  void didUpdateWidget(covariant CaptureViewsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      Future.microtask(
        () => ref
            .read(captureControllerProvider.notifier)
            .setProductId(widget.productId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final controller = ref.read(captureControllerProvider.notifier);
    final selectingImage = state.selectingImage;

    Future<void> onSubmit() async {
      final jobId = await controller.submit();
      if (!context.mounted) return;
      if (jobId == null) {
        final current = ref.read(captureControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(current.error ?? 'Falha no envio.')),
        );
        return;
      }
      ref
          .read(processingControllerProvider.notifier)
          .start(jobId, productId: widget.productId);
      context.goNamed(AppRoutes.processingName);
    }

    return AppScaffold(
      title: 'Captura guiada',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          ImageCounter(
            cardinalCount: state.cardinalCount,
            extrasCount: state.extras.length,
          ),
          const SizedBox(height: 12),
          if (state.qualityMessages.isNotEmpty)
            QualityBanner(message: state.qualityMessages.first),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: [
              for (final view in AppConstants.cardinalViews)
                _CardinalSlot(
                  view: view,
                  file: state.cardinals[view],
                  disabled: state.uploading || selectingImage,
                  onCapture: () => _captureFor(context, controller, view),
                  onClear: () => controller.removeCardinal(view),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _TopSection(
            file: state.top,
            disabled: state.uploading || selectingImage,
            onCapture: () => _captureFor(
              context,
              controller,
              AppConstants.topView,
            ),
            onClear: controller.removeTop,
          ),
          const SizedBox(height: 20),
          _ExtrasSection(
            extras: state.extras,
            canAdd: state.canAddExtra && !state.uploading && !selectingImage,
            onAdd: () => _addExtra(context, controller),
            onRemove: state.uploading || selectingImage
                ? null
                : controller.removeExtraAt,
          ),
          if (state.uploading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: state.uploadProgress),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      bottomBar: PrimaryButton(
        label: state.allCardinalsFilled
            ? 'Enviar para processamento'
            : 'Capture as 4 vistas (${state.cardinalCount}/4)',
        icon: Icons.cloud_upload_outlined,
        loading: state.uploading,
        onPressed: state.canSubmit ? onSubmit : null,
      ),
    );
  }

  Future<void> _captureFor(
    BuildContext context,
    CaptureController controller,
    String view,
  ) async {
    final source = await _pickSource(context);
    if (source == null) return;
    if (source == ImageSource.camera) {
      await controller.captureForView(view);
    } else {
      await controller.pickFromGalleryForView(view);
    }
  }

  Future<void> _addExtra(
    BuildContext context,
    CaptureController controller,
  ) async {
    final source = await _pickSource(context);
    if (source == null) return;
    await controller.pickExtra(source);
  }

  Future<ImageSource?> _pickSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.file,
    required this.disabled,
    required this.onCapture,
    required this.onClear,
  });

  final File? file;
  final bool disabled;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Topo (opcional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Mantenha a frente do frasco virada para a base do enquadramento. '
          'Posicione a câmera perpendicular à tampa e use luz difusa; sol '
          'direto vira reflexo permanente na textura.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 180,
          child: _CardinalSlot(
            view: AppConstants.topView,
            file: file,
            disabled: disabled,
            onCapture: onCapture,
            onClear: onClear,
          ),
        ),
      ],
    );
  }
}

class _CardinalSlot extends StatelessWidget {
  final String view;
  final File? file;
  final bool disabled;
  final VoidCallback onCapture;
  final VoidCallback onClear;

  const _CardinalSlot({
    required this.view,
    required this.file,
    required this.disabled,
    required this.onCapture,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = AppConstants.viewLabels[view] ?? view;
    final filled = file != null;

    return InkWell(
      onTap: disabled ? null : onCapture,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: filled ? scheme.surface : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: filled ? scheme.primary : scheme.outlineVariant,
            width: filled ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filled)
              Image(
                key: ValueKey('cardinal-preview-$view'),
                image: capturePreviewImageProvider(
                  file!,
                  cacheWidth: AppConstants.cardinalPreviewCacheWidth,
                ),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tocar para tirar',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: Colors.black.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (filled)
                      InkWell(
                        onTap: disabled ? null : onClear,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtrasSection extends StatelessWidget {
  final List<File> extras;
  final bool canAdd;
  final VoidCallback onAdd;
  final void Function(int)? onRemove;

  const _ExtrasSection({
    required this.extras,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extras (${extras.length}/${AppConstants.maxExtras})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Ângulos opcionais. O algoritmo escolhe ou descarta.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < extras.length; i++)
              _ExtraThumb(
                file: extras[i],
                imageKey: ValueKey('extra-preview-$i'),
                onRemove: onRemove == null ? null : () => onRemove!(i),
              ),
            if (canAdd)
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.add,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ExtraThumb extends StatelessWidget {
  final File file;
  final Key imageKey;
  final VoidCallback? onRemove;

  const _ExtraThumb({
    required this.file,
    required this.imageKey,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            key: imageKey,
            image: capturePreviewImageProvider(
              file,
              cacheWidth: AppConstants.extraPreviewCacheWidth,
            ),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
