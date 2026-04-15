import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class ImageCounter extends StatelessWidget {
  final int count;
  const ImageCounter({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        (count / AppConstants.recommendedImages).clamp(0.0, 1.0).toDouble();
    final reachedMin = count >= AppConstants.minImages;

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
                reachedMin ? Icons.check_circle : Icons.photo_camera,
                color: reachedMin ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$count / ${AppConstants.recommendedImages} imagens',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                reachedMin ? 'mínimo atingido' : 'mínimo: ${AppConstants.minImages}',
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
