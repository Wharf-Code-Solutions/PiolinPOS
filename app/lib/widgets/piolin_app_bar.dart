import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/pos_store.dart';
import 'common.dart';

/// Barra superior morada de 64px (DESIGN.md › Top App Bar).
class PiolinAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PiolinAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.pill,
    this.showBack = false,
    this.showLogo = true,
    this.showSync = true,
    this.showAdmin = true,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? pill;
  final bool showBack;
  final bool showLogo;

  /// Muestra el estado del respaldo en Drive (toca para abrir Respaldo).
  final bool showSync;
  final bool showAdmin;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      color: PColors.morado,
      padding: EdgeInsets.only(top: topPadding),
      height: 64 + topPadding,
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Regresar',
              icon: const Icon(Icons.arrow_back, color: PColors.blanco),
              onPressed: onBack ?? () => context.canPop() ? context.pop() : context.go(Routes.cuentas),
            )
          else
            const SizedBox(width: 16),
          if (showLogo) ...[const PiolinLogo(size: 40), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PText.headlineLg(color: PColors.blanco)),
                    ),
                    if (pill != null) ...[const SizedBox(width: 8), pill!],
                  ],
                ),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PText.label(color: PColors.moradoSuave, weight: FontWeight.w400).copyWith(fontSize: 13)),
              ],
            ),
          ),
          ...actions,
          if (showSync) const _BackupStatusButton(),
          if (showAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Material(
                color: PColors.moradoProfundo,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push(Routes.ajustes),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.settings, color: PColors.blanco, size: 22),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _BackupStatusButton extends StatelessWidget {
  const _BackupStatusButton();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final connected = (store.settings['backup_account'] ?? '').isNotEmpty;
    final last = DateTime.tryParse(store.settings['last_backup_at'] ?? '');
    final stale = last == null || DateTime.now().difference(last).inDays >= 7;
    final icon = !connected ? Icons.cloud_off : (stale ? Icons.cloud_queue : Icons.cloud_done);
    return IconButton(
      tooltip: 'Respaldo en Google Drive',
      icon: Icon(icon, color: !connected || stale ? PColors.amarillo : PColors.blanco),
      onPressed: () => context.push(Routes.respaldo),
    );
  }
}

/// Píldora del estado del turno.
class ShiftOpenPill extends StatelessWidget {
  const ShiftOpenPill({super.key});

  @override
  Widget build(BuildContext context) {
    final open = StoreScope.of(context).hasOpenShift;
    return GestureDetector(
      onTap: () => context.push(Routes.turno),
      child: open
          ? const StatusPill('Abierta')
          : const StatusPill('Sin turno', background: PColors.errorBg, foreground: PColors.rojo),
    );
  }
}
