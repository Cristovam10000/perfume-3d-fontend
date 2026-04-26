import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    final produtos = data.produtos.where((produto) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          produto.nome.toLowerCase().contains(query) ||
          produto.categoria.toLowerCase().contains(query);
    }).toList();

    return SalesScaffold(
      title: 'Produtos',
      currentIndex: 2,
      actions: [
        CircleIconButton(icon: Icons.add_rounded, onPressed: () {}),
      ],
      body: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Buscar produto...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: produtos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (context, index) {
                return _ProductCard(produto: produtos[index], index: index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Produto produto;
  final int index;

  const _ProductCard({required this.produto, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFF0C7BB),
      const Color(0xFFD7E3FB),
      const Color(0xFFF3C1D4),
      const Color(0xFFE5D5C4),
    ];
    final bg = colors[index % colors.length];

    return InkWell(
      onTap: produto.tem3D
          ? () => context.pushNamed(
                AppRoutes.product3dName,
                pathParameters: {'id': produto.id},
              )
          : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgElev,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: bg),
                  Center(child: _BottleArt(color: bg)),
                  if (produto.tem3D)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.view_in_ar_outlined,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '3D',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produto.categoria.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink3,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    produto.nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MoneyText(
                    value: produto.precoBase,
                    size: 13,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottleArt extends StatelessWidget {
  final Color color;

  const _BottleArt({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Container(
          width: 72,
          height: 92,
          decoration: BoxDecoration(
            color: Color.lerp(color, AppColors.accent, 0.48),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow14,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 50,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                'EAU\nDE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
