import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  String _query = '';
  ClienteStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    final clientes = data.clientes.where(_matches).toList();

    return SalesScaffold(
      title: 'Clientes',
      currentIndex: 1,
      actions: [
        CircleIconButton(icon: Icons.add_rounded, onPressed: () {}),
      ],
      body: ListView(
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Buscar nome ou telefone...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos · ${data.clientes.length}',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  label: 'Bons',
                  selected: _filter == ClienteStatus.good,
                  dot: AppColors.good,
                  onTap: () => setState(() => _filter = ClienteStatus.good),
                ),
                _FilterChip(
                  label: 'Atencao',
                  selected: _filter == ClienteStatus.warn,
                  dot: AppColors.warn,
                  onTap: () => setState(() => _filter = ClienteStatus.warn),
                ),
                _FilterChip(
                  label: 'Atraso',
                  selected: _filter == ClienteStatus.bad,
                  dot: AppColors.bad,
                  onTap: () => setState(() => _filter = ClienteStatus.bad),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < clientes.length; i++) ...[
                  _ClientRow(cliente: clientes[i]),
                  if (i != clientes.length - 1)
                    const Divider(height: 1, color: AppColors.line),
                ],
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  bool _matches(Cliente cliente) {
    final query = _query.trim().toLowerCase();
    final matchesQuery = query.isEmpty ||
        cliente.nome.toLowerCase().contains(query) ||
        cliente.telefone.toLowerCase().contains(query);
    final matchesFilter = _filter == null || cliente.status == _filter;
    return matchesQuery && matchesFilter;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? dot;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.bgElev,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.accentInk : AppColors.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  final Cliente cliente;

  const _ClientRow({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        AppRoutes.clientDetailName,
        pathParameters: {'id': cliente.id},
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClienteAvatar(cliente: cliente),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cliente.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      SyncBadge(status: cliente.syncStatus),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${cliente.bairro} · ${cliente.totalCompras} compras',
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
            cliente.emAberto == 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.goodSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text(
                      'Quite',
                      style: TextStyle(
                        color: AppColors.good,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.brl(cliente.emAberto),
                        style: TextStyle(
                          color: cliente.status == ClienteStatus.bad
                              ? AppColors.bad
                              : AppColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'em aberto',
                        style: TextStyle(
                          color: AppColors.ink3,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.ink3),
          ],
        ),
      ),
    );
  }
}
