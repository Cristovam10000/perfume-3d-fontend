import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../domain/sales_models.dart';

class SalesScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final bool showBack;
  final int? currentIndex;
  final EdgeInsetsGeometry padding;

  const SalesScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.showBack = false,
    this.currentIndex,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: showBack ? 76 : null,
        leading: showBack
            ? Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: Icons.arrow_back,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.goNamed(AppRoutes.homeName);
                      }
                    },
                  ),
                ),
              )
            : null,
        title: titleWidget ?? (title == null ? null : Text(title!)),
        actions: [
          ...actions,
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: body,
        ),
      ),
      bottomNavigationBar:
          currentIndex == null ? null : _SalesBottomNav(currentIndex!),
    );
  }
}

class _SalesBottomNav extends StatelessWidget {
  final int currentIndex;

  const _SalesBottomNav(this.currentIndex);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 12,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.bgElev,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Inicio',
                        selected: currentIndex == 0,
                        onTap: () => context.goNamed(AppRoutes.homeName),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.people_alt_outlined,
                        selectedIcon: Icons.people_alt_rounded,
                        label: 'Clientes',
                        selected: currentIndex == 1,
                        onTap: () => context.goNamed(AppRoutes.clientsName),
                      ),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2_rounded,
                        label: 'Estoque',
                        selected: currentIndex == 2,
                        onTap: () => context.goNamed(AppRoutes.productsName),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.receipt_long_outlined,
                        selectedIcon: Icons.receipt_long_rounded,
                        label: 'Cobranca',
                        selected: currentIndex == 3,
                        onTap: () => context.goNamed(AppRoutes.billingName),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Material(
                color: AppColors.accent,
                elevation: 8,
                shadowColor: AppColors.shadow14,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.pushNamed(AppRoutes.saleNewName),
                  child: const SizedBox.square(
                    dimension: 56,
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.ink3;
    return InkResponse(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppColors.bgElev,
    this.foregroundColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    final bg = onPressed == null ? AppColors.bgSunken : backgroundColor;
    final fg = onPressed == null ? AppColors.ink4 : foregroundColor;

    return Material(
      color: bg,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(icon, color: fg, size: 22),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.ink3,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentInk,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class MoneyText extends StatelessWidget {
  final num value;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? textAlign;

  const MoneyText({
    super.key,
    required this.value,
    this.size = 16,
    this.weight = FontWeight.w800,
    this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      AppFormatters.brl(value),
      textAlign: textAlign,
      style: TextStyle(
        color: color ?? AppColors.ink,
        fontSize: size,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class ClienteAvatar extends StatelessWidget {
  final Cliente cliente;
  final double size;

  const ClienteAvatar({
    super.key,
    required this.cliente,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(cliente.status);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Text(
            cliente.iniciais,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: size * 0.28,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 1,
          child: Container(
            width: size * 0.22,
            height: size * 0.22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgElev, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  final ClienteStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final bg = statusSoftColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              statusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SyncBadge extends StatelessWidget {
  final SyncStatus status;

  const SyncBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();
    final isFailed = status == SyncStatus.failed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFailed ? AppColors.badSoft : AppColors.warnSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isFailed ? 'Falhou' : 'Local',
        style: TextStyle(
          color: isFailed ? AppColors.bad : AppColors.warn,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class PaymentDueCard extends StatelessWidget {
  final ParcelaResumo item;
  final bool danger;
  final VoidCallback? onTap;

  const PaymentDueCard({
    super.key,
    required this.item,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = danger ? AppColors.bad : AppColors.warn;
    final fg = danger ? AppColors.bad : AppColors.accentInk;
    return Material(
      color: danger ? const Color(0xFFFFF7F5) : AppColors.bgElev,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                children: [
                  ClienteAvatar(cliente: item.cliente, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.cliente.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Parcela ${item.parcela.numero}/${item.parcela.total}',
                          style: const TextStyle(
                            color: AppColors.ink3,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(
                        value: item.parcela.restante,
                        size: 15,
                        color: danger ? AppColors.bad : AppColors.ink,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cobrar ->',
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class ScoreRing extends StatelessWidget {
  final int score;
  final ClienteStatus status;
  final double size;

  const ScoreRing({
    super.key,
    required this.score,
    required this.status,
    this.size = 86,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: score.clamp(0, 100) / 100,
          color: statusColor(status),
        ),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              color: statusColor(status),
              fontSize: size * 0.3,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final bgPaint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -1.57, 6.28, false, bgPaint);
    canvas.drawArc(rect, -1.57, 6.28 * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

Color statusColor(ClienteStatus status) {
  switch (status) {
    case ClienteStatus.good:
      return AppColors.good;
    case ClienteStatus.warn:
      return AppColors.warn;
    case ClienteStatus.bad:
      return AppColors.bad;
  }
}

Color statusSoftColor(ClienteStatus status) {
  switch (status) {
    case ClienteStatus.good:
      return AppColors.goodSoft;
    case ClienteStatus.warn:
      return AppColors.warnSoft;
    case ClienteStatus.bad:
      return AppColors.badSoft;
  }
}

String statusLabel(ClienteStatus status) {
  switch (status) {
    case ClienteStatus.good:
      return 'Bom pagador';
    case ClienteStatus.warn:
      return 'Atencao';
    case ClienteStatus.bad:
      return 'Mau pagador';
  }
}
