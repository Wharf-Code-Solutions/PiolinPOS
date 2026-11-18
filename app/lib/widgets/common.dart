import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Tarjeta nivel 1: blanco + borde 1px, radio 12, sin sombra.
class PCard extends StatelessWidget {
  const PCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = PColors.blanco,
    this.borderColor = PColors.borde,
    this.borderWidth = 1,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: PRadius.cardBr,
          side: BorderSide(color: borderColor, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Encabezado de sección: Domine 700, mayúsculas, tracking +0.08em.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.icon, this.trailing, this.color = PColors.tinta});

  final String text;
  final IconData? icon;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: PColors.morado),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(text.toUpperCase(), style: PText.sectionHeader(color: color))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Píldora de estado (radio completo).
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.background = PColors.amarillo,
    this.foreground = PColors.tinta,
    this.icon,
    this.dotColor,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: PRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(text, style: PText.label(color: foreground, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Chip de categoría (36px, píldora). Seleccionado = morado sólido como en los mocks.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? PColors.blanco : PColors.tinta;
    return Material(
      color: selected ? PColors.morado : PColors.blanco,
      shape: StadiumBorder(side: BorderSide(color: selected ? PColors.morado : PColors.borde)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: selected ? PColors.blanco : PColors.gris),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: PText.bodyMd(color: fg, weight: selected ? FontWeight.w700 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila horizontal desplazable de chips.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 16)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

enum PButtonVariant { primary, secondary, ghost, soft }

/// Botones del sistema: primary (rojo), secondary (morado), ghost, soft (morado suave).
class PButton extends StatelessWidget {
  const PButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PButtonVariant.primary,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PButtonVariant variant;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color pressed, BorderSide side) = switch (variant) {
      PButtonVariant.primary => (PColors.rojo, PColors.blanco, PColors.rojoPressed, BorderSide.none),
      PButtonVariant.secondary => (PColors.morado, PColors.blanco, PColors.moradoProfundo, BorderSide.none),
      PButtonVariant.ghost => (Colors.transparent, PColors.tinta, PColors.beige, const BorderSide(color: PColors.borde)),
      PButtonVariant.soft => (PColors.moradoSuave, PColors.morado, const Color(0xFFD6CAF2), BorderSide.none),
    };
    final enabled = onPressed != null;
    final button = FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: PRadius.cardBr, side: side)),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return PColors.beigeOscuro;
          if (s.contains(WidgetState.pressed)) return pressed;
          return bg;
        }),
        foregroundColor: WidgetStatePropertyAll(enabled ? fg : PColors.gris),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
          Flexible(
            child: Text(label,
                textAlign: TextAlign.center,
                style: PText.button(color: enabled ? fg : PColors.gris)),
          ),
          if (trailingIcon != null) ...[const SizedBox(width: 10), Icon(trailingIcon, size: 22)],
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Botón circular (+ / −) usado en los selectores de cantidad.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? PColors.morado : PColors.beigeOscuro,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.55, color: filled ? PColors.blanco : PColors.tinta),
        ),
      ),
    );
  }
}

/// Logo de la app (assets/images/logo.png).
class PiolinLogo extends StatelessWidget {
  const PiolinLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}

/// Estado vacío genérico para listas.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: PColors.gris),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: PText.headlineMd()),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: PText.bodyMd(color: PColors.gris)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

void showInfoSnack(BuildContext context, String message, {IconData icon = Icons.info_outline}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: PColors.amarillo, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}
