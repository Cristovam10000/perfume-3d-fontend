import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class SaleWizardPage extends ConsumerStatefulWidget {
  const SaleWizardPage({super.key});

  @override
  ConsumerState<SaleWizardPage> createState() => _SaleWizardPageState();
}

class _SaleWizardPageState extends ConsumerState<SaleWizardPage> {
  int _step = 0;
  String? _clienteId;
  final Map<String, int> _items = {};
  double _entrada = 0;
  int _parcelas = 3;
  bool _catalogExpanded = false;
  late final TextEditingController _entradaController;

  @override
  void initState() {
    super.initState();
    _entradaController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _entradaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    _clienteId ??= data.clientes.first.id;
    final total = _items.entries.fold<double>(0, (sum, entry) {
      final produto = data.produtoById(entry.key)!;
      return sum + produto.precoBase * entry.value;
    });
    if (_entrada > total) {
      _entrada = total;
      _entradaController.text = _entradaInputText(_entrada);
    }
    final restante = (total - _entrada).clamp(0, total).toDouble();
    final canContinue = _step != 1 || _items.isNotEmpty;

    return SalesScaffold(
      title: 'Nova venda',
      showBack: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.bgElev,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                '${_step + 1}/4',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.accent : AppColors.line,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                if (i != 3) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _ClientStep(
                  data: data,
                  selectedId: _clienteId!,
                  onSelected: (id) => setState(() => _clienteId = id),
                ),
                _ItemsStep(
                  data: data,
                  items: _items,
                  catalogExpanded: _catalogExpanded,
                  onToggleCatalog: () => setState(
                    () => _catalogExpanded = !_catalogExpanded,
                  ),
                  onProductSelected: _addProduct,
                  onQuantityChanged: _setItemQuantity,
                ),
                _PaymentStep(
                  total: total,
                  entrada: _entrada,
                  parcelas: _parcelas,
                  entradaController: _entradaController,
                  onEntradaTextChanged: (value) =>
                      _updateEntradaFromText(value, total),
                  onEntradaPreset: (value) => _setEntrada(value, total),
                  onParcelasChanged: (value) =>
                      setState(() => _parcelas = value.clamp(1, 24).toInt()),
                ),
                _ReviewStep(
                  data: data,
                  clienteId: _clienteId!,
                  items: _items,
                  total: total,
                  entrada: _entrada,
                  restante: restante,
                  parcelas: _parcelas,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBack,
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: canContinue
                      ? () {
                          if (_step < 3) {
                            setState(() => _step += 1);
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Venda salva localmente. Sincronizacao vem depois.',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: _step == 3
                      ? const Text('Confirmar venda')
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Continuar'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.homeName);
    }
  }

  void _addProduct(Produto produto) {
    setState(() {
      _items.update(produto.id, (quantity) => quantity + 1, ifAbsent: () => 1);
      _catalogExpanded = false;
    });
  }

  void _setItemQuantity(String produtoId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _items.remove(produtoId);
      } else {
        _items[produtoId] = quantity;
      }
    });
  }

  void _updateEntradaFromText(String value, double total) {
    final parsed = _parseEntrada(value);
    setState(() => _entrada = _clampEntrada(parsed, total));
  }

  void _setEntrada(double value, double total) {
    final clamped = _clampEntrada(value, total);
    setState(() => _entrada = clamped);
    _entradaController.text = _entradaInputText(clamped);
    _entradaController.selection = TextSelection.collapsed(
      offset: _entradaController.text.length,
    );
  }

  double _parseEntrada(String value) {
    final onlyMoney = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final normalized = onlyMoney.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double _clampEntrada(double value, double total) {
    return value.clamp(0, total).toDouble();
  }

  String _entradaInputText(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _ClientStep extends StatelessWidget {
  final SalesSnapshot data;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _ClientStep({
    required this.data,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StepTitle('1. QUEM COMPROU?'),
        const SizedBox(height: 12),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Buscar cliente...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        const _DashedButton(
            icon: Icons.person_add_alt, label: 'Cadastrar novo cliente'),
        const SizedBox(height: 12),
        for (final cliente in data.clientes) ...[
          _SelectableClient(
            cliente: cliente,
            selected: cliente.id == selectedId,
            onTap: () => onSelected(cliente.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SelectableClient extends StatelessWidget {
  final Cliente cliente;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableClient({
    required this.cliente,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.bgElev,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            ClienteAvatar(cliente: cliente),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cliente.nome,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  _ClientPaymentStatus(cliente: cliente),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _ClientPaymentStatus extends StatelessWidget {
  final Cliente cliente;

  const _ClientPaymentStatus({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(cliente.status);
    final label = switch (cliente.status) {
      ClienteStatus.good => 'Bom pagador',
      ClienteStatus.warn =>
        'Atencao - ${AppFormatters.brl(cliente.emAberto)} aberto',
      ClienteStatus.bad => 'Em atraso - ${AppFormatters.brl(cliente.emAberto)}',
    };

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemsStep extends StatelessWidget {
  final SalesSnapshot data;
  final Map<String, int> items;
  final bool catalogExpanded;
  final VoidCallback onToggleCatalog;
  final ValueChanged<Produto> onProductSelected;
  final void Function(String produtoId, int quantity) onQuantityChanged;

  const _ItemsStep({
    required this.data,
    required this.items,
    required this.catalogExpanded,
    required this.onToggleCatalog,
    required this.onProductSelected,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.entries.fold<double>(0, (sum, entry) {
      final produto = data.produtoById(entry.key)!;
      return sum + produto.precoBase * entry.value;
    });
    return ListView(
      children: [
        const _StepTitle('2. O QUE VENDEU?'),
        const SizedBox(height: 12),
        _DashedButton(
          key: const ValueKey('toggle-product-catalog'),
          icon: catalogExpanded ? Icons.close_rounded : Icons.add_rounded,
          label: 'Adicionar produto',
          onTap: onToggleCatalog,
        ),
        if (catalogExpanded) ...[
          const SizedBox(height: 12),
          _ProductCatalog(
            produtos: data.produtos,
            selectedIds: items.keys.toSet(),
            onSelected: onProductSelected,
          ),
        ],
        if (items.isNotEmpty) const SizedBox(height: 12),
        for (final entry in items.entries) ...[
          _ItemRow(
            key: ValueKey('selected-product-${entry.key}'),
            produto: data.produtoById(entry.key)!,
            quantity: entry.value,
            onMinus: () => onQuantityChanged(entry.key, entry.value - 1),
            onPlus: () => onQuantityChanged(entry.key, entry.value + 1),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        if (items.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                MoneyText(value: total, color: Colors.white, size: 24),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Produto produto;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _ItemRow({
    super.key,
    required this.produto,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _ProductSwatch(produto: produto, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${AppFormatters.brl(produto.precoBase)} cada',
                  style: const TextStyle(
                    color: AppColors.ink3,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _QuantityStepper(
            produtoId: produto.id,
            quantity: quantity,
            onMinus: onMinus,
            onPlus: onPlus,
          ),
        ],
      ),
    );
  }
}

class _ProductCatalog extends StatelessWidget {
  final List<Produto> produtos;
  final Set<String> selectedIds;
  final ValueChanged<Produto> onSelected;

  const _ProductCatalog({
    required this.produtos,
    required this.selectedIds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < produtos.length; i++) ...[
            _ProductOptionRow(
              key: ValueKey('catalog-product-${produtos[i].id}'),
              produto: produtos[i],
              selected: selectedIds.contains(produtos[i].id),
              onTap: () => onSelected(produtos[i]),
            ),
            if (i != produtos.length - 1)
              const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _ProductOptionRow extends StatelessWidget {
  final Produto produto;
  final bool selected;
  final VoidCallback onTap;

  const _ProductOptionRow({
    super.key,
    required this.produto,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _ProductSwatch(produto: produto, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produto.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${produto.categoria}${produto.tem3D ? ' - 3D' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            MoneyText(value: produto.precoBase, size: 13),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductSwatch extends StatelessWidget {
  final Produto produto;
  final double size;

  const _ProductSwatch({required this.produto, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _productColor(produto),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final String produtoId;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantityStepper({
    required this.produtoId,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            key: ValueKey('quantity-minus-$produtoId'),
            icon: Icons.remove_rounded,
            foreground: AppColors.ink,
            background: Colors.white,
            onTap: onMinus,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$quantity',
              key: ValueKey('quantity-value-$produtoId'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StepperButton(
            key: ValueKey('quantity-plus-$produtoId'),
            icon: Icons.add_rounded,
            foreground: Colors.white,
            background: AppColors.accent,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  const _StepperButton({
    super.key,
    required this.icon,
    required this.foreground,
    required this.background,
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: foreground, size: 20),
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  final double total;
  final double entrada;
  final int parcelas;
  final TextEditingController entradaController;
  final ValueChanged<String> onEntradaTextChanged;
  final ValueChanged<double> onEntradaPreset;
  final ValueChanged<int> onParcelasChanged;

  const _PaymentStep({
    required this.total,
    required this.entrada,
    required this.parcelas,
    required this.entradaController,
    required this.onEntradaTextChanged,
    required this.onEntradaPreset,
    required this.onParcelasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final restante = (total - entrada).clamp(0, total).toDouble();
    return ListView(
      children: [
        const _StepTitle('3. COMO VAI PAGAR?'),
        const SizedBox(height: 12),
        _PaymentPanel(
          title: 'ENTRADA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    r'R$',
                    style: TextStyle(
                      color: AppColors.ink3,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: entradaController,
                      onChanged: onEntradaTextChanged,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bgElev,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PresetChip(
                    label: 'Sem entrada',
                    selected: entrada == 0,
                    onTap: () => onEntradaPreset(0),
                  ),
                  _PresetChip(
                    label: '20%',
                    selected: total > 0 && entrada == total * 0.2,
                    onTap: () => onEntradaPreset(total * 0.2),
                  ),
                  _PresetChip(
                    label: '50%',
                    selected: total > 0 && entrada == total * 0.5,
                    onTap: () => onEntradaPreset(total * 0.5),
                  ),
                  _PresetChip(
                    label: 'A vista',
                    selected: total > 0 && entrada == total,
                    onTap: () => onEntradaPreset(total),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PaymentPanel(
          title: 'PARCELAS RESTANTES',
          child: Column(
            children: [
              Row(
                children: [
                  _RoundPaymentButton(
                    icon: Icons.remove_rounded,
                    foreground: AppColors.ink,
                    background: AppColors.accentSoft,
                    onTap: parcelas <= 1
                        ? null
                        : () => onParcelasChanged(parcelas - 1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${parcelas}x',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          AppFormatters.brl(
                            parcelas == 0 ? 0 : restante / parcelas,
                          ),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RoundPaymentButton(
                    icon: Icons.add_rounded,
                    foreground: Colors.white,
                    background: AppColors.accent,
                    onTap: () => onParcelasChanged(parcelas + 1),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in const [2, 3, 4, 6, 10])
                    _PresetChip(
                      label: '${option}x',
                      selected: parcelas == option,
                      onTap: () => onParcelasChanged(option),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PaymentPanel(
          title: 'OBSERVACOES',
          child: TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: pagamento toda 5a feira...',
              filled: true,
              fillColor: AppColors.bgElev,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _PaymentPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink3,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RoundPaymentButton extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  const _RoundPaymentButton({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.bgSunken : background,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.ink4 : foreground,
          size: 24,
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String text;

  const _StepTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.ink3,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      ),
    );
  }
}

Color _productColor(Produto produto) {
  final digits = RegExp(r'\d+').firstMatch(produto.id)?.group(0);
  final index = ((int.tryParse(digits ?? '1') ?? 1) - 1).clamp(0, 999).toInt();
  const colors = [
    Color(0xFFCB3E7B),
    Color(0xFF4863A8),
    Color(0xFFB13B72),
    Color(0xFF94683E),
    Color(0xFFC83D7B),
    Color(0xFF336D88),
  ];
  return colors[index % colors.length];
}

class _ReviewStep extends StatelessWidget {
  final SalesSnapshot data;
  final String clienteId;
  final Map<String, int> items;
  final double total;
  final double entrada;
  final double restante;
  final int parcelas;

  const _ReviewStep({
    required this.data,
    required this.clienteId,
    required this.items,
    required this.total,
    required this.entrada,
    required this.restante,
    required this.parcelas,
  });

  @override
  Widget build(BuildContext context) {
    final cliente = data.clienteById(clienteId)!;
    return ListView(
      children: [
        _WizardCard(
          title: 'Cliente',
          child: Row(
            children: [
              ClienteAvatar(cliente: cliente),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(cliente.nome,
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              StatusPill(status: cliente.status),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WizardCard(
          title: 'Resumo',
          child: Column(
            children: [
              _BreakdownLine(label: 'Total', value: total),
              _BreakdownLine(label: 'Entrada', value: entrada),
              _BreakdownLine(label: 'Restante', value: restante),
              _BreakdownLine(
                  label: 'Parcelas',
                  value: parcelas == 0 ? 0 : restante / parcelas,
                  suffix: ' x $parcelas'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.goodSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Text(
            'Cliente com bom historico para venda parcelada.',
            style:
                TextStyle(color: AppColors.good, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _WizardCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _WizardCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DashedButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bgTint,
          border: Border.all(color: AppColors.lineStrong),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.accentInk, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _PresetChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(
        color: selected ? AppColors.accentInk : AppColors.ink2,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: selected ? AppColors.accentSoft : AppColors.bgElev,
      side: BorderSide(
        color: selected ? AppColors.lineStrong : AppColors.line,
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;

  const _BreakdownLine({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.ink3, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            '${AppFormatters.brl(value)}$suffix',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
