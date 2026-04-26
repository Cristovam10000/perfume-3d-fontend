import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../data/sales_repository.dart';
import '../../domain/sales_models.dart';
import '../widgets/sales_widgets.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(salesSnapshotProvider);
    return SalesScaffold(
      title: 'Notificacoes',
      showBack: true,
      body: ListView.separated(
        itemCount: data.notificacoes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = data.notificacoes[index];
          return _NotificationCard(
            notification: notification,
            cliente: data.clienteById(notification.clienteId),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Notificacao notification;
  final Cliente? cliente;

  const _NotificationCard({
    required this.notification,
    required this.cliente,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _tone(notification.tipo);
    return Container(
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
                          onPressed: () {},
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
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
                          onPressed: () {},
                          child: const Text('Marcar lida'),
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
