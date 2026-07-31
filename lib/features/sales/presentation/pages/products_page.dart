import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/product_visuals.dart';
import '../widgets/sales_widgets.dart';

enum _StockFilter { all, low, zero }

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _query = '';
  _StockFilter _filter = _StockFilter.all;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    final produtos = data.produtos.where(_matches).toList();

    return SalesScaffold(
      titleWidget: const _StockTitle(),
      currentIndex: 2,
      actions: [
        CircleIconButton(
          icon: Icons.add_rounded,
          onPressed: () => _showProductFormSheet(context, ref),
        ),
      ],
      body: ListView(
        children: [
          _StockHero(data: data),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StockAlertCard(
                  count: data.produtosSemEstoque.length,
                  title: 'Sem estoque',
                  subtitle: 'Repor urgente',
                  color: AppColors.bad,
                  soft: AppColors.badSoft,
                  selected: _filter == _StockFilter.zero,
                  onTap: () => setState(() => _filter = _StockFilter.zero),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StockAlertCard(
                  count: data.produtosEstoqueBaixo.length,
                  title: 'Estoque baixo',
                  subtitle: 'Pensar em repor',
                  color: AppColors.warn,
                  soft: AppColors.warnSoft,
                  selected: _filter == _StockFilter.low,
                  onTap: () => setState(() => _filter = _StockFilter.low),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Buscar produto...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos (${data.produtos.length})',
                  selected: _filter == _StockFilter.all,
                  onTap: () => setState(() => _filter = _StockFilter.all),
                ),
                _FilterChip(
                  label: 'Baixo (${data.produtosEstoqueBaixo.length})',
                  selected: _filter == _StockFilter.low,
                  onTap: () => setState(() => _filter = _StockFilter.low),
                ),
                _FilterChip(
                  label: 'Zerado (${data.produtosSemEstoque.length})',
                  selected: _filter == _StockFilter.zero,
                  onTap: () => setState(() => _filter = _StockFilter.zero),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final produto in produtos) ...[
            _ProductStockCard(
              produto: produto,
              onTap: () => _showProductActionsSheet(context, ref, produto),
            ),
            const SizedBox(height: 12),
          ],
          if (produtos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Nenhum produto neste filtro.')),
            ),
          _DashedAddButton(onTap: () => _showProductFormSheet(context, ref)),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  bool _matches(Produto produto) {
    final query = _query.trim().toLowerCase();
    final matchesQuery = query.isEmpty ||
        produto.nome.toLowerCase().contains(query) ||
        produto.categoria.toLowerCase().contains(query);
    final matchesFilter = switch (_filter) {
      _StockFilter.all => true,
      _StockFilter.low => _isLowStock(produto),
      _StockFilter.zero => produto.estoque <= 0,
    };
    return matchesQuery && matchesFilter;
  }
}

class _StockTitle extends StatelessWidget {
  const _StockTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ola, controle dos seus produtos',
          style: TextStyle(
            color: AppColors.ink3,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Estoque',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StockHero extends StatelessWidget {
  final SalesSnapshot data;

  const _StockHero({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFF422833), Color(0xFF84214E)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VALOR EM ESTOQUE (CUSTO)',
            style: TextStyle(
              color: Color(0xFFCAB7C0),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          MoneyText(
            value: data.valorEstoqueCusto,
            size: 34,
            color: Colors.white,
            weight: FontWeight.w900,
          ),
          if (data.produtosSemCusto > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${data.produtosSemCusto} produto(s) sem custo cadastrado. '
              'Edite-os para completar este valor.',
              style: const TextStyle(
                color: Color(0xFFFFD7E8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroInfo(
                label: 'Unidades',
                value: '${data.unidadesEmEstoque}',
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                color: Colors.white.withValues(alpha: 0.22),
              ),
              _HeroInfo(
                label: 'Se vender tudo',
                value: AppFormatters.brl(data.valorVendaPotencial),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  final String label;
  final String value;

  const _HeroInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCAB7C0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockAlertCard extends StatelessWidget {
  final int count;
  final String title;
  final String subtitle;
  final Color color;
  final Color soft;
  final bool selected;
  final VoidCallback onTap;

  const _StockAlertCard({
    required this.count,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.soft,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: soft,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? color : Colors.transparent),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.bgElev,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.ink2,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductStockCard extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTap;

  const _ProductStockCard({
    required this.produto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _stockTone(produto);
    return Material(
      color: AppColors.bgElev,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProductBottlePreview(produto: produto, width: 72, height: 90),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${produto.categoria.toUpperCase()} · ${produto.volumeMl}ML',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink3,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      produto.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MoneyText(
                          value: produto.precoBase,
                          size: 15,
                          color: AppColors.accent,
                        ),
                        _StatusBadge(tone: tone),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${produto.estoque}',
                    style: TextStyle(
                      color: tone.color,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'EM ESTOQUE',
                    style: TextStyle(
                      color: AppColors.ink3,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StockTone tone;

  const _StatusBadge({required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        tone.label,
        style: TextStyle(
          color: tone.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DashedAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        // Altura minima e rotulo flexivel: com fonte ampliada o botao cresce
        // em vez de estourar a largura.
        constraints: const BoxConstraints(minHeight: 68),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgElev.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.lineStrong),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.ink),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Cadastrar novo produto',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showProductActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Produto produto,
) async {
  var mode = _SheetMode.actions;
  var restockAmount = 1;
  var adjustedQuantity = produto.estoque;
  var saving = false;

  _ProductSheetAction? nextAction;
  nextAction = await showModalBottomSheet<_ProductSheetAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (modalContext, setSheetState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 20 + MediaQuery.viewInsetsOf(modalContext).bottom,
                top: 18,
              ),
              // Rola quando o conteudo (ou a fonte do sistema) passa da altura
              // disponivel, em vez de estourar o limite da folha.
              child: SingleChildScrollView(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: switch (mode) {
                    _SheetMode.actions => _ProductActionsContent(
                        produto: produto,
                        onClose: () => Navigator.of(sheetContext).pop(),
                        onRestock: () => setSheetState(
                          () => mode = _SheetMode.restock,
                        ),
                        onAdjust: () => setSheetState(
                          () => mode = _SheetMode.adjust,
                        ),
                        onEdit: () => Navigator.of(sheetContext)
                            .pop(_ProductSheetAction.edit),
                        onGenerate3D: () => Navigator.of(sheetContext)
                            .pop(_ProductSheetAction.generate3D),
                        on3D: produto.tem3D
                            ? () => Navigator.of(sheetContext)
                                .pop(_ProductSheetAction.view3D)
                            : null,
                      ),
                    _SheetMode.restock => _RestockContent(
                        produto: produto,
                        amount: restockAmount,
                        onAmountChanged: (value) => setSheetState(
                          () => restockAmount = value.clamp(1, 9999).toInt(),
                        ),
                        onBack: () => setSheetState(
                          () => mode = _SheetMode.actions,
                        ),
                        onSave: () async {
                          if (saving) return;
                          setSheetState(() => saving = true);
                          try {
                            await ref
                                .read(salesControllerProvider.notifier)
                                .restockProduct(produto.id, restockAmount);
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            setSheetState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$error')),
                              );
                            }
                          }
                        },
                      ),
                    _SheetMode.adjust => _AdjustContent(
                        produto: produto,
                        quantity: adjustedQuantity,
                        onQuantityChanged: (value) => setSheetState(
                          () =>
                              adjustedQuantity = value.clamp(0, 999999).toInt(),
                        ),
                        onBack: () => setSheetState(
                          () => mode = _SheetMode.actions,
                        ),
                        onSave: () async {
                          if (saving) return;
                          setSheetState(() => saving = true);
                          try {
                            await ref
                                .read(salesControllerProvider.notifier)
                                .adjustProductStock(
                                  produto.id,
                                  adjustedQuantity,
                                );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            setSheetState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$error')),
                              );
                            }
                          }
                        },
                      ),
                  },
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (!context.mounted) return;
  switch (nextAction) {
    case _ProductSheetAction.edit:
      await _showProductFormSheet(context, ref, product: produto);
      return;
    case _ProductSheetAction.generate3D:
      context.pushNamed(
        AppRoutes.captureByProductName,
        pathParameters: {'produtoId': produto.id},
      );
      return;
    case _ProductSheetAction.view3D:
      context.pushNamed(
        AppRoutes.product3dName,
        pathParameters: {'id': produto.id},
      );
      return;
    case null:
      return;
  }
}

enum _SheetMode { actions, restock, adjust }

enum _ProductSheetAction { edit, generate3D, view3D }

class _ProductActionsContent extends StatelessWidget {
  final Produto produto;
  final VoidCallback onClose;
  final VoidCallback onRestock;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onGenerate3D;
  final VoidCallback? on3D;

  const _ProductActionsContent({
    required this.produto,
    required this.onClose,
    required this.onRestock,
    required this.onAdjust,
    required this.onEdit,
    required this.onGenerate3D,
    required this.on3D,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(title: produto.nome, onClose: onClose),
        const SizedBox(height: 18),
        Row(
          children: [
            ProductBottlePreview(
              produto: produto,
              width: 104,
              height: 132,
              show3DBadge: false,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${produto.categoria.toUpperCase()} · ${produto.volumeMl}ML',
                    style: const TextStyle(
                      color: AppColors.ink3,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    produto.nome,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MoneyText(
                    value: produto.precoBase,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ProductMetric(
                  label: 'Em estoque',
                  value: '${produto.estoque}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProductMetric(
                  label: 'Minimo',
                  value: '${produto.estoqueMinimo}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProductMetric(
                  label: 'Custo',
                  value: AppFormatters.brl(produto.custo),
                  compact: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SheetActionButton(
          label: 'Repor estoque',
          icon: Icons.add_rounded,
          filled: true,
          onTap: onRestock,
        ),
        const SizedBox(height: 12),
        _SheetActionButton(
          label: 'Ajustar quantidade',
          icon: Icons.sync_rounded,
          onTap: onAdjust,
        ),
        const SizedBox(height: 12),
        _SheetActionButton(
          label: 'Editar produto',
          icon: Icons.edit_outlined,
          onTap: onEdit,
        ),
        if (on3D != null) ...[
          const SizedBox(height: 12),
          _SheetActionButton(
            label: 'Ver em 3D',
            icon: Icons.view_in_ar_outlined,
            onTap: on3D!,
          ),
        ],
        const SizedBox(height: 12),
        _SheetActionButton(
          label: produto.tem3D ? 'Gerar novo molde 3D' : 'Gerar molde 3D',
          icon: Icons.add_a_photo_outlined,
          onTap: onGenerate3D,
        ),
      ],
    );
  }
}

class _RestockContent extends StatelessWidget {
  final Produto produto;
  final int amount;
  final ValueChanged<int> onAmountChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _RestockContent({
    required this.produto,
    required this.amount,
    required this.onAmountChanged,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final total = produto.estoque + amount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
            title: produto.nome, onClose: onBack, closeIcon: Icons.close),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Quantidade para repor'),
        const SizedBox(height: 10),
        _BigCounter(
          value: amount,
          onMinus: amount <= 1 ? null : () => onAmountChanged(amount - 1),
          onPlus: () => onAmountChanged(amount + 1),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [1, 5, 10, 20, 50])
              _QuickAmountChip(
                label: '+$value',
                selected: amount == value,
                onTap: () => onAmountChanged(value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _PreviewTotal(label: 'Total final em estoque', value: '$total'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: onBack, child: const Text('Voltar')),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Salvar reposicao'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdjustContent extends StatefulWidget {
  final Produto produto;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _AdjustContent({
    required this.produto,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<_AdjustContent> createState() => _AdjustContentState();
}

class _AdjustContentState extends State<_AdjustContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetHeader(
          title: widget.produto.nome,
          onClose: widget.onBack,
          closeIcon: Icons.close,
        ),
        const SizedBox(height: 22),
        const Text(
          'QUANTIDADE REAL EM ESTOQUE',
          style: TextStyle(
            color: AppColors.ink3,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use isso para corrigir diferencas (ex: contagem manual)',
          style: TextStyle(
            color: AppColors.ink3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          onChanged: (value) => widget.onQuantityChanged(_parseInt(value)),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
          decoration: const InputDecoration(
            fillColor: AppColors.bgElev,
            filled: true,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Voltar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: widget.quantity >= 0 ? widget.onSave : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Salvar ajuste'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final IconData closeIcon;

  const _SheetHeader({
    required this.title,
    required this.onClose,
    this.closeIcon = Icons.close_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(onPressed: onClose, icon: Icon(closeIcon)),
      ],
    );
  }
}

class _ProductMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _ProductMetric({
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Altura minima em vez de fixa: com fonte ampliada o card cresce junto do
    // conteudo em vez de estourar.
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgTint,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink3,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: compact ? 2 : 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: compact ? 15 : 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return filled
        ? FilledButton(onPressed: onTap, child: child)
        : OutlinedButton(onPressed: onTap, child: child);
  }
}

class _BigCounter extends StatelessWidget {
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  const _BigCounter({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _CounterButton(icon: Icons.remove_rounded, onTap: onMinus),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _CounterButton(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(icon: icon, onPressed: onTap);
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.accentSoft : AppColors.bgElev,
      labelStyle: TextStyle(
        color: selected ? AppColors.accentInk : AppColors.ink2,
        fontWeight: FontWeight.w900,
      ),
      side: const BorderSide(color: AppColors.line),
    );
  }
}

class _PreviewTotal extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewTotal({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goodSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.good,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.good,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showProductFormSheet(
  BuildContext pageContext,
  WidgetRef ref, {
  Produto? product,
}) async {
  final saved = await showModalBottomSheet<Produto>(
    context: pageContext,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ProductFormSheet(ref: ref, product: product),
  );

  if (saved == null || product != null || !pageContext.mounted) return;

  if (saved.syncStatus != SyncStatus.synced) {
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(
        content: Text(
          'Produto salvo no aparelho. O molde 3D ficará disponível após a sincronização com o backend.',
        ),
      ),
    );
    return;
  }

  final generate = await showDialog<bool>(
    context: pageContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Produto salvo'),
      content: const Text('Deseja gerar o molde 3D agora?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Gerar molde 3D'),
        ),
      ],
    ),
  );
  if (generate == true && pageContext.mounted) {
    pageContext.pushNamed(
      AppRoutes.captureByProductName,
      pathParameters: {'produtoId': saved.id},
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final WidgetRef ref;
  final Produto? product;

  const _ProductFormSheet({required this.ref, required this.product});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minController;
  late final TextEditingController _volumeController;
  late String _category;
  late int _colorValue;
  var _saving = false;
  String? _errorText;

  Produto? get _product => widget.product;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.nome ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.precoBase.toStringAsFixed(2),
    );
    _costController = TextEditingController(
      text: product == null || product.custo <= 0
          ? ''
          : product.custo.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(
      text: product == null ? '' : '${product.estoque}',
    );
    _minController =
        TextEditingController(text: '${product?.estoqueMinimo ?? 1}');
    _volumeController =
        TextEditingController(text: '${product?.volumeMl ?? 100}');
    _category = product?.categoria ?? 'Perfume';
    _colorValue = product?.frascoColorValue ?? 0xFFCB3E7B;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _minController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final price = _parseDouble(_priceController.text);
    final cost = _parseDouble(_costController.text);
    final quantityText = _quantityController.text.trim();
    final quantity = _parseInt(quantityText);
    final minStock = _parseInt(_minController.text).clamp(1, 9999).toInt();
    final volume = _parseInt(_volumeController.text).clamp(1, 9999).toInt();
    final name = _nameController.text.trim();
    final canSave = name.isNotEmpty &&
        price > 0 &&
        cost > 0 &&
        (product != null || quantityText.isNotEmpty);
    final preview = Produto(
      id: product?.id ?? 'preview',
      nome: name.isEmpty ? 'Novo produto' : name,
      categoria: _category,
      precoBase: price,
      custo: cost,
      estoque: quantity,
      estoqueMinimo: minStock,
      volumeMl: volume,
      frascoColorValue: _colorValue,
      tem3D: product?.tem3D ?? false,
      modelo3DPath: product?.modelo3DPath,
      previewImg: product?.previewImg,
      syncStatus: product?.syncStatus ?? SyncStatus.pending,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(
                title: product == null ? 'Novo produto' : 'Editar produto',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Center(
                child: ProductBottlePreview(
                  produto: preview,
                  width: 118,
                  height: 148,
                  show3DBadge: false,
                  showLabel: true,
                ),
              ),
              const SizedBox(height: 18),
              _LabeledField(
                label: 'Nome*',
                controller: _nameController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Categoria'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [
                    'Perfume',
                    'Feminino',
                    'Masculino',
                    'Unissex',
                    'Body splash',
                    'Hidratante',
                  ])
                    ChoiceChip(
                      label: Text(option),
                      selected: _category == option,
                      onSelected: (_) => setState(() => _category = option),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Preco*',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LabeledField(
                      label: 'Custo*',
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Qtd*',
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      enabled: product == null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LabeledField(
                      label: 'Estoque minimo',
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Ml',
                controller: _volumeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Cor do frasco'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in const [
                    0xFFCB3E7B,
                    0xFF4863A8,
                    0xFFB13B72,
                    0xFF94683E,
                    0xFF336D88,
                    0xFF2A1A23,
                  ])
                    _ColorSwatch(
                      colorValue: color,
                      selected: _colorValue == color,
                      onTap: () => setState(() => _colorValue = color),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.bad,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed:
                    canSave && !_saving ? () => _handleSave(preview) : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  product == null ? 'Salvar produto' : 'Salvar alterações',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(Produto preview) async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final controller = widget.ref.read(salesControllerProvider.notifier);
      final saved = widget.product == null
          ? await controller.createProduct(preview)
          : await controller.updateProduct(preview);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = '$error';
      });
    }
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _StockTone {
  final String label;
  final Color color;
  final Color soft;

  const _StockTone({
    required this.label,
    required this.color,
    required this.soft,
  });
}

_StockTone _stockTone(Produto produto) {
  if (produto.estoque <= 0) {
    return const _StockTone(
      label: 'SEM ESTOQUE',
      color: AppColors.bad,
      soft: AppColors.badSoft,
    );
  }
  if (_isLowStock(produto)) {
    return const _StockTone(
      label: 'BAIXO',
      color: AppColors.warn,
      soft: AppColors.warnSoft,
    );
  }
  return const _StockTone(
    label: 'EM ESTOQUE',
    color: AppColors.good,
    soft: AppColors.goodSoft,
  );
}

bool _isLowStock(Produto produto) =>
    produto.estoque > 0 && produto.estoque <= produto.estoqueMinimo + 1;

double _parseDouble(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[^0-9,\.]'), '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

int _parseInt(String value) {
  final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(normalized) ?? 0;
}
