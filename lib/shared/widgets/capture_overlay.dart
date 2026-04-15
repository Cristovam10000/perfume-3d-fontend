import 'package:flutter/material.dart';

/// Guia visual de enquadramento sobreposto à pré-visualização da câmera.
/// Em um MVP sem stream de câmera, é desenhado sobre o placeholder/preview.
class CaptureOverlay extends StatelessWidget {
  final String? hint;
  const CaptureOverlay({super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          CustomPaint(
            painter: _FramePainter(),
            size: Size.infinite,
          ),
          if (hint != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.55,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);

    // cantos destacados
    const cornerLen = 22.0;
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    void drawCorner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, corner);
      canvas.drawLine(b, c, corner);
    }

    drawCorner(
      Offset(rect.left, rect.top + cornerLen),
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLen, rect.top),
    );
    drawCorner(
      Offset(rect.right - cornerLen, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLen),
    );
    drawCorner(
      Offset(rect.left, rect.bottom - cornerLen),
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLen, rect.bottom),
    );
    drawCorner(
      Offset(rect.right - cornerLen, rect.bottom),
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLen),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
