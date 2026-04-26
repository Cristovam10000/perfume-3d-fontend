import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    _clienteId ??= data.clientes.first.id;
    if (_items.isEmpty) _items[data.produtos.first.id] = 1;
    final total = _items.entries.fold<double>(0, (sum, entry) {
      final produto = data.produtoById(entry.key)!;
      return sum + produto.precoBase * entry.value;
    });
    final restante = (total - _entrada).clamp(0, total).toDouble();

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
                  onChanged: () => setState(() {}),
                ),
                _PaymentStep(
                  total: total,
                  entrada: _entrada,
                  parcelas: _parcelas,
                  onEntradaChanged: (value) => setState(() => _entrada = value),
                  onParcelasChanged: (value) =>
                      setState(() => _parcelas = value),
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
                  onPressed:
                      _step == 0 ? null : () => setState(() => _step -= 1),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
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
                  },
                  child: Text(_step == 3 ? 'Confirmar venda' : 'Continuar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
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
                  Text(
                    '${cliente.bairro} · score ${cliente.score}',
                    style: const TextStyle(
                      color: AppColors.ink3,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

class _ItemsStep extends StatelessWidget {
  final SalesSnapshot data;
  final Map<String, int> items;
  final VoidCallback onChanged;

  const _ItemsStep({
    required this.data,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.entries.fold<double>(0, (sum, entry) {
      final produto = data.produtoById(entry.key)!;
      return sum + produto.precoBase * entry.value;
    });
    return ListView(
      children: [
        for (final entry in items.entries) ...[
          _ItemRow(
            produto: data.produtoById(entry.key)!,
            quantity: entry.value,
            onMinus: () {
              if (entry.value <= 1) {
                items.remove(entry.key);
              } else {
                items[entry.key] = entry.value - 1;
              }
              onChanged();
            },
            onPlus: () {
              items[entry.key] = entry.value + 1;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
        ],
        _DashedButton(
          icon: Icons.add_box_outlined,
          label: 'Adicionar produto',
          onTap: () {
            final next = data.produtos.firstWhere(
              (produto) => !items.containsKey(produto.id),
              orElse: () => data.produtos.first,
            );
            items.update(next.id, (q) => q + 1, ifAbsent: () => 1);
            onChanged();
          },
        ),
        const SizedBox(height: 18),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto.nome,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                MoneyText(
                    value: produto.precoBase,
                    size: 13,
                    color: AppColors.accent),
              ],
            ),
          ),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove)),
          Text('$quantity',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  final double total;
  final double entrada;
  final int parcelas;
  final ValueChanged<double> onEntradaChanged;
  final ValueChanged<int> onParcelasChanged;

  const _PaymentStep({
    required this.total,
    required this.entrada,
    required this.parcelas,
    required this.onEntradaChanged,
    required this.onParcelasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final restante = (total - entrada).clamp(0, total).toDouble();
    return ListView(
      children: [
        _WizardCard(
          title: 'Entrada',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyText(value: entrada, size: 28, color: AppColors.accent),
              Slider(
                value: total == 0 ? 0 : entrada / total,
                onChanged: (value) => onEntradaChanged(total * value),
                activeColor: AppColors.accent,
              ),
              Wrap(
                spacing: 8,
                children: [
                  _PresetChip(
                      label: 'Sem entrada', onTap: () => onEntradaChanged(0)),
                  _PresetChip(
                      label: '20%', onTap: () => onEntradaChanged(total * 0.2)),
                  _PresetChip(
                      label: '50%', onTap: () => onEntradaChanged(total * 0.5)),
                  _PresetChip(
                      label: 'A vista', onTap: () => onEntradaChanged(total)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WizardCard(
          title: 'Parcelas',
          child: Row(
            children: [
              IconButton(
                onPressed: parcelas <= 1
                    ? null
                    : () => onParcelasChanged(parcelas - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${parcelas}x',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      AppFormatters.brl(
                          parcelas == 0 ? 0 : restante / parcelas),
                      style: const TextStyle(
                          color: AppColors.ink3, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onParcelasChanged(parcelas + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Observacoes da venda...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
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

  const _DashedButton({required this.icon, required this.label, this.onTap});

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

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.bgTint,
      side: const BorderSide(color: AppColors.line),
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
