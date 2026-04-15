import 'package:flutter/material.dart';

import '../../core/utils/image_quality_analyzer.dart';

class QualityBanner extends StatelessWidget {
  final QualityMessage message;
  const QualityBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    late final IconData icon;

    switch (message.level) {
      case QualityLevel.ok:
        bg = scheme.secondaryContainer;
        fg = scheme.onSecondaryContainer;
        icon = Icons.check_circle_outline;
        break;
      case QualityLevel.warning:
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        icon = Icons.info_outline;
        break;
      case QualityLevel.blocker:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.text,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
