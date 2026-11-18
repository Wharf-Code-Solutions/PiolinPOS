import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Conteo físico (R18): captura lo contado y ajusta las diferencias.
class ConteoScreen extends StatefulWidget {
  const ConteoScreen({super.key});

  @override
  State<ConteoScreen> createState() => _ConteoScreenState();
}

class _ConteoScreenState extends State<ConteoScreen> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  TextEditingController _ctrl(String id) => _ctrls.putIfAbsent(id, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply(List<InventoryItem> items) async {
    final counted = <InventoryItem, int>{};
    for (final i in items) {
      final text = _ctrls[i.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final milli = parseQtyMilli(text);
      if (milli == null || milli < 0) continue;
      counted[i] = milli;
    }
    if (counted.isEmpty) {
      showInfoSnack(context, 'Captura al menos una cantidad contada', icon: Icons.warning_amber);
      return;
    }
    final outside = counted.entries.where((e) {
      final diff = (e.value - e.key.stockMilli).abs();
      final tol = (e.key.stockMilli.abs() * e.key.toleranceBp / 10000).round();
      return diff > tol;
    }).length;
    final ok = await confirmDialog(
      context,
      title: 'Aplicar conteo',
      message: 'Se ajustarán ${counted.length} insumo(s).'
          '${outside > 0 ? '\n$outside fuera de la tolerancia permitida.' : ''}',
      confirmLabel: 'Aplicar',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final store = StoreScope.read(context);
    final done = await runGuarded(context, () => store.applyStockCount(counted, notes: 'Conteo físico'),
        success: 'Conteo aplicado');
    if (!mounted) return;
    setState(() => _saving = false);
    if (done) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.activeInventory;
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Conteo físico', showBack: true, showSync: false, showLogo: false),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Captura solo lo que contaste; lo demás no se modifica.', style: PText.bodyMd(color: PColors.gris)),
                const SizedBox(height: 12),
                if (items.isEmpty) const EmptyState(icon: Icons.inventory_2, title: 'Sin insumos'),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.name, style: PText.bodyLg(weight: FontWeight.w700)),
                                Text('Sistema: ${formatQty(i.stockMilli)} ${i.unit.short}'
                                    '${i.toleranceBp > 0 ? ' · tolerancia ${(i.toleranceBp / 100).toStringAsFixed(0)}%' : ''}',
                                    style: PText.bodyMd(color: PColors.gris)),
                                _DiffLabel(item: i, controller: _ctrl(i.id)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: _ctrl(i.id),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: moneyInputFormatters,
                              textAlign: TextAlign.right,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(hintText: 'Contado', suffixText: i.unit.short, isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PButton(
                label: _saving ? 'Aplicando…' : 'Aplicar conteo',
                icon: Icons.fact_check,
                variant: PButtonVariant.secondary,
                onPressed: _saving || items.isEmpty ? null : () => _apply(items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffLabel extends StatelessWidget {
  const _DiffLabel({required this.item, required this.controller});

  final InventoryItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final milli = parseQtyMilli(controller.text);
    if (controller.text.trim().isEmpty || milli == null) return const SizedBox.shrink();
    final diff = milli - item.stockMilli;
    final tol = (item.stockMilli.abs() * item.toleranceBp / 10000).round();
    final ok = diff.abs() <= tol;
    return Text(
      diff == 0 ? 'Sin diferencia' : 'Diferencia: ${diff > 0 ? '+' : ''}${formatQty(diff)} ${item.unit.short}${ok ? ' (dentro de tolerancia)' : ''}',
      style: PText.label(color: ok ? PColors.verde : PColors.rojo, weight: FontWeight.w700),
    );
  }
}
