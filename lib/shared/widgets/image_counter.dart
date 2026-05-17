import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Mostra progresso de captura cardeal (X / 4 vistas + Y extras).
class ImageCounter extends StatelessWidget {
  final int cardinalCount;
  final int extrasCount;
  const ImageCounter({
    super.key,
    required this.cardinalCount,
    this.extrasCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (cardinalCount / AppConstants.requiredImages)
        .clamp(0.0, 1.0)
        .toDouble();
    final allCardinals = cardinalCount >= AppConstants.requiredImages;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allCardinals ? Icons.check_circle : Icons.photo_camera,
                color: allCardinals ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$cardinalCount / ${AppConstants.requiredImages} vistas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                extrasCount > 0
                    ? '+ $extrasCount extra${extrasCount > 1 ? 's' : ''}'
                    : 'até ${AppConstants.maxExtras} extras',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
