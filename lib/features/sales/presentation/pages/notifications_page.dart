import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/commercial_actions.dart';
import '../widgets/sales_widgets.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(salesSnapshotProvider);
    return SalesScaffold(
      title: 'Notificacoes',
      showBack: true,
      body: data.notificacoes.isEmpty
          ? const Center(child: Text('Nenhuma notificação no momento.'))
          : ListView.separated(
              itemCount: data.notificacoes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = data.notificacoes[index];
                final installment = _installment(data, notification.parcelaId);
                return _NotificationCard(
                  notification: notification,
                  cliente: data.clienteById(notification.clienteId),
                  busy: _busy.contains(notification.id),
                  onOpen: installment == null
                      ? null
                      : () {
                          context.pushNamed(
                            AppRoutes.saleDetailName,
                            pathParameters: {'id': installment.vendaId},
                          );
                        },
                  onWhatsApp: () => _whatsApp(notification, data, installment),
                  onRead: () => _markRead(notification),
                );
              },
            ),
    );
  }

  Parcela? _installment(SalesSnapshot data, String id) {
    for (final installment in data.parcelas) {
      if (installment.id == id) return installment;
    }
    return null;
  }

  Future<void> _whatsApp(
    Notificacao notification,
    SalesSnapshot data,
    Parcela? installment,
  ) async {
    final client = data.clienteById(notification.clienteId);
    if (client == null) return;
    await _run(
      notification.id,
      () => openWhatsAppCollection(client: client, installment: installment),
    );
  }

  Future<void> _markRead(Notificacao notification) {
    return _run(
      notification.id,
      () => ref
          .read(salesControllerProvider.notifier)
          .markNotificationRead(notification.id),
    );
  }

  Future<void> _run(String id, Future<void> Function() operation) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          action: SnackBarAction(
            label: 'Tentar novamente',
            onPressed: () => _run(id, operation),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final Notificacao notification;
  final Cliente? cliente;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onWhatsApp;
  final VoidCallback onRead;

  const _NotificationCard({
    required this.notification,
    required this.cliente,
    required this.busy,
    required this.onOpen,
    required this.onWhatsApp,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _tone(notification.tipo);
    return InkWell(
      onTap: busy ? null : onOpen,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgElev,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.soft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(tone.icon, color: tone.color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tone.label,
                          style: TextStyle(
                            color: tone.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Text(
                        AppFormatters.compactDate(notification.data),
                        style: const TextStyle(
                          color: AppColors.ink3,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!notification.lida) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.texto,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  MoneyText(value: notification.valor, size: 13),
                  if (!notification.lida) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: busy ? null : onWhatsApp,
                            icon:
                                const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text('WhatsApp'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentSoft,
                              foregroundColor: AppColors.accentInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy ? null : onRead,
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Marcar lida'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotificationTone _tone(NotificacaoTipo tipo) {
    switch (tipo) {
      case NotificacaoTipo.venceHoje:
        return const _NotificationTone(
          label: 'VENCE HOJE',
          icon: Icons.schedule,
          color: AppColors.warn,
          soft: AppColors.warnSoft,
        );
      case NotificacaoTipo.venceAmanha:
        return const _NotificationTone(
          label: 'VENCE AMANHA',
          icon: Icons.calendar_today_outlined,
          color: AppColors.ink3,
          soft: AppColors.bgSunken,
        );
      case NotificacaoTipo.atraso:
        return const _NotificationTone(
          label: 'EM ATRASO',
          icon: Icons.warning_amber_rounded,
          color: AppColors.bad,
          soft: AppColors.badSoft,
        );
      case NotificacaoTipo.pagamento:
        return const _NotificationTone(
          label: 'PAGAMENTO',
          icon: Icons.check_circle_outline,
          color: AppColors.good,
          soft: AppColors.goodSoft,
        );
    }
  }
}

class _NotificationTone {
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;

  const _NotificationTone({
    required this.label,
    required this.icon,
    required this.color,
    required this.soft,
  });
}
