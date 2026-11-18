import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../data/pos_store.dart';

/// Contenedor de las 4 pestañas: Cuentas, Menú, Inventario, Reportes.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.receipt_long, 'Cuentas'),
    (Icons.restaurant_menu, 'Menú'),
    (Icons.inventory_2, 'Inventario'),
    (Icons.bar_chart, 'Reportes'),
  ];

  @override
  Widget build(BuildContext context) {
    final hasShift = StoreScope.of(context).hasOpenShift;
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          if (!hasShift) const _NoShiftBanner(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
      ),
    );
  }
}

class _NoShiftBanner extends StatelessWidget {
  const _NoShiftBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PColors.offlineBg,
      child: InkWell(
        onTap: () => context.push(Routes.turno),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: PColors.amarillo))),
          child: Row(
            children: [
              const Icon(Icons.lock_clock, size: 20, color: PColors.amarilloTexto),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Turno cerrado · abre el turno para tomar pedidos y cobrar',
                    style: PText.bodyMd(weight: FontWeight.w600).copyWith(fontSize: 13)),
              ),
              Text('Abrir', style: PText.label(color: PColors.morado, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PColors.blanco,
        border: Border(top: BorderSide(color: PColors.borde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < ShellScaffold._tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: ShellScaffold._tabs[i].$1,
                    label: ShellScaffold._tabs[i].$2,
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? PColors.morado : PColors.gris;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: active ? PColors.morado : Colors.transparent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ),
          const Spacer(),
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: PText.label(color: color, weight: active ? FontWeight.w700 : FontWeight.w500)),
          const Spacer(),
        ],
      ),
    );
  }
}
