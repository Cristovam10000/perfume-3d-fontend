import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/sales_models.dart';

class ProductBottlePreview extends StatelessWidget {
  final Produto produto;
  final double width;
  final double height;
  final bool show3DBadge;
  final bool showLabel;

  const ProductBottlePreview({
    super.key,
    required this.produto,
    this.width = 72,
    this.height = 92,
    this.show3DBadge = true,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(produto.frascoColorValue);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.17),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(color, Colors.white, 0.02)!,
                    color,
                    Color.lerp(color, Colors.white, 0.24)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow08,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          if (showLabel)
            Center(
              child: Container(
                width: width * 0.62,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _labelText(produto),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.08,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          if (show3DBadge && produto.tem3D)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  '3D',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _labelText(Produto produto) {
    final words = produto.nome.trim().split(RegExp(r'\s+'));
    final name = words.length <= 2 ? produto.nome : words.take(2).join(' ');
    return 'EAU DE\n${name.toUpperCase()}\n${produto.volumeMl} ml';
  }
}

class ProductStagePreview extends StatelessWidget {
  final Produto produto;

  const ProductStagePreview({super.key, required this.produto});

  @override
  Widget build(BuildContext context) {
    final color = Color(produto.frascoColorValue);
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 32,
            child: Container(
              width: 184,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow08,
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 30,
            child: Container(
              width: 96,
              height: 68,
              decoration: BoxDecoration(
                color: Color.lerp(color, AppColors.ink, 0.72),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(color, AppColors.ink, 0.82)!,
                    Color.lerp(color, Colors.white, 0.05)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            child: Container(
              width: 48,
              height: 48,
              color: Color.lerp(color, Colors.white, 0.18),
            ),
          ),
          Positioned(
            top: 132,
            child: ProductBottlePreview(
              produto: produto,
              width: 188,
              height: 230,
              show3DBadge: false,
              showLabel: true,
            ),
          ),
        ],
      ),
    );
  }
}
