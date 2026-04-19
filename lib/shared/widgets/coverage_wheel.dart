import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Widget circular mostrando quais ângulos ao redor do objeto já foram
/// capturados. Fatias verdes = cobertas; fatia destacada = orientação atual.
class CoverageWheel extends StatelessWidget {
  final List<bool> coverage;
  final double currentAngleDegrees;
  final double size;

  const CoverageWheel({
    super.key,
    required this.coverage,
    required this.currentAngleDegrees,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WheelPainter(
          coverage: coverage,
          currentAngleDegrees: currentAngleDegrees,
          covered: scheme.primary,
          empty: scheme.surfaceContainerHighest,
          current: scheme.tertiary,
          border: scheme.outlineVariant,
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<bool> coverage;
  final double currentAngleDegrees;
  final Color covered;
  final Color empty;
  final Color current;
  final Color border;

  _WheelPainter({
    required this.coverage,
    required this.currentAngleDegrees,
    required this.covered,
    required this.empty,
    required this.current,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (coverage.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / coverage.length;
    final currentBin =
        ((currentAngleDegrees / 360) * coverage.length).floor() %
            coverage.length;

    for (int i = 0; i < coverage.length; i++) {
      final start = -math.pi / 2 + i * sweep;
      Color fill;
      if (i == currentBin) {
        fill = current;
      } else if (coverage[i]) {
        fill = covered;
      } else {
        fill = empty;
      }
      final paint = Paint()..color = fill;
      canvas.drawArc(rect, start, sweep * 0.95, true, paint);
    }

    // furo no centro para estética
    final hole = Paint()..color = Colors.white.withValues(alpha: 0.0);
    canvas.drawCircle(center, radius * 0.45, hole);

    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) {
    return old.coverage != coverage ||
        old.currentAngleDegrees != currentAngleDegrees;
  }
}
