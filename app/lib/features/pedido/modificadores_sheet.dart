import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// Hoja para elegir modificadores de un producto (p. ej. Super Torta: 2 ingredientes).
Future<List<SelectedModifier>?> showModifiersSheet(
  BuildContext context, {
  required Product product,
  required List<ModifierGroup> groups,
}) {
  return showModalBottomSheet<List<SelectedModifier>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _ModifiersSheet(product: product, groups: groups),
  );
}

class _ModifiersSheet extends StatefulWidget {
  const _ModifiersSheet({required this.product, required this.groups});

  final Product product;
  final List<ModifierGroup> groups;

  @override
  State<_ModifiersSheet> createState() => _ModifiersSheetState();
}

class _ModifiersSheetState extends State<_ModifiersSheet> {
  late final Map<String, Set<String>> _selected = {
    for (final g in widget.groups) g.id: {for (final m in g.activeModifiers) if (m.isDefault) m.id},
  };

  bool _groupValid(ModifierGroup g) {
    final n = _selected[g.id]!.length;
    return n >= g.minSelect && n <= g.maxSelect;
  }

  void _toggle(ModifierGroup g, Modifier m) {
    final set = _selected[g.id]!;
    setState(() {
      if (set.contains(m.id)) {
        set.remove(m.id);
      } else if (g.maxSelect == 1) {
        set
          ..clear()
          ..add(m.id);
      } else if (set.length < g.maxSelect) {
        set.add(m.id);
      }
    });
  }

  int get _extraCents {
    var total = 0;
    for (final g in widget.groups) {
      for (final m in g.activeModifiers) {
        if (_selected[g.id]!.contains(m.id)) total += m.priceDeltaCents;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.groups.every(_groupValid);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(widget.product.name, style: PText.headlineMd()),
                Text(formatMoney(widget.product.priceCents), style: PText.priceSm(color: PColors.morado)),
                const SizedBox(height: 12),
                for (final g in widget.groups) ...[
                  Row(children: [
                    Expanded(child: Text(g.name, style: PText.sectionHeader())),
                    Text(g.ruleLabel,
                        style: PText.label(color: _groupValid(g) ? PColors.gris : PColors.rojo, weight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in g.activeModifiers)
                        FilterChip(
                          label: Text(m.priceDeltaCents == 0
                              ? m.name
                              : '${m.name} (${formatMoney(m.priceDeltaCents, showSign: true)})'),
                          selected: _selected[g.id]!.contains(m.id),
                          selectedColor: PColors.moradoSuave,
                          checkmarkColor: PColors.morado,
                          onSelected: (_) => _toggle(g, m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: PButton(
                label: 'Agregar · ${formatMoney(widget.product.priceCents + _extraCents)}',
                icon: Icons.add_shopping_cart,
                variant: PButtonVariant.secondary,
                onPressed: !valid
                    ? null
                    : () => Navigator.pop(context, [
                          for (final g in widget.groups)
                            for (final m in g.activeModifiers)
                              if (_selected[g.id]!.contains(m.id))
                                SelectedModifier(modifierId: m.id, name: m.name, priceDeltaCents: m.priceDeltaCents),
                        ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
