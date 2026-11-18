import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/barcode_scanner.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Alta y edición de insumos inventariados (refrescos, carnes, pan…).
class InsumoFormScreen extends StatefulWidget {
  const InsumoFormScreen({super.key, this.itemId, this.barcode});

  final String? itemId;
  final String? barcode;

  @override
  State<InsumoFormScreen> createState() => _InsumoFormScreenState();
}

class _InsumoFormScreenState extends State<InsumoFormScreen> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _min = TextEditingController();
  final _tolerance = TextEditingController(text: '0');
  final _location = TextEditingController();
  final _initial = TextEditingController();

  InventoryItem? _editing;
  String? _categoryId;
  String? _supplierId;
  InventoryUnit _unit = InventoryUnit.pza;
  bool _active = true;
  bool _submitted = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = StoreScope.read(context);
    final item = store.inventoryItemById(widget.itemId);
    _editing = item;
    if (item != null) {
      _name.text = item.name;
      _barcode.text = item.barcode ?? '';
      _min.text = formatQty(item.minStockMilli);
      _tolerance.text = (item.toleranceBp / 100).toStringAsFixed(0);
      _location.text = item.location;
      _categoryId = item.categoryId;
      _supplierId = item.supplierId;
      _unit = item.unit;
      _active = item.active;
    } else {
      _barcode.text = widget.barcode ?? '';
      final cats = store.inventoryCategories;
      _categoryId = cats.isEmpty ? null : cats.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _min, _tolerance, _location, _initial]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_name.text.trim().isEmpty || _categoryId == null) {
      showInfoSnack(context, 'Captura nombre y categoría', icon: Icons.warning_amber);
      return;
    }
    final store = StoreScope.read(context);
    final item = _editing ??
        InventoryItem(id: newId(), name: '', categoryId: _categoryId!, unit: _unit);
    item
      ..name = _name.text.trim()
      ..categoryId = _categoryId!
      ..unit = _unit
      ..barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim()
      ..minStockMilli = parseQtyMilli(_min.text) ?? 0
      ..toleranceBp = ((int.tryParse(_tolerance.text) ?? 0) * 100).clamp(0, 10000).toInt()
      ..supplierId = _supplierId
      ..location = _location.text.trim()
      ..active = _active;
    final initial = _editing == null ? (parseQtyMilli(_initial.text) ?? 0) : 0;
    final ok = await runGuarded(context, () => store.saveInventoryItem(item, initialStockMilli: initial),
        success: _editing == null ? '${item.name} dado de alta' : 'Cambios guardados');
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: PiolinAppBar(
        title: _editing == null ? 'Nuevo insumo' : 'Editar insumo',
        showBack: true,
        showSync: false,
        showLogo: false,
        showAdmin: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: 'Nombre',
                  controller: _name,
                  hint: 'Ej. Coca-Cola 600 ml',
                  isRequired: true,
                  errorText: _submitted && _name.text.trim().isEmpty ? 'Requerido' : null,
                ),
                Text('Categoría', style: PText.label(color: PColors.tinta, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in store.inventoryCategories)
                    CategoryChip(
                        label: c.name, icon: c.icon, selected: _categoryId == c.id, onTap: () => setState(() => _categoryId = c.id)),
                ]),
                const SizedBox(height: 12),
                Text('Unidad', style: PText.label(color: PColors.tinta, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                SegmentedButton<InventoryUnit>(
                  segments: [
                    for (final u in InventoryUnit.values) ButtonSegment(value: u, label: Text(u.label)),
                  ],
                  selected: {_unit},
                  onSelectionChanged: _editing == null ? (s) => setState(() => _unit = s.first) : null,
                ),
                if (_editing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('La unidad no se puede cambiar después del alta.', style: PText.label()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              children: [
                if (_editing == null)
                  LabeledField(
                    label: 'Existencia inicial',
                    controller: _initial,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters,
                    suffixText: _unit.short,
                  ),
                LabeledField(
                  label: 'Aviso de stock bajo (mínimo)',
                  controller: _min,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: moneyInputFormatters,
                  suffixText: _unit.short,
                ),
                LabeledField(
                  label: 'Tolerancia en conteo físico',
                  controller: _tolerance,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  suffixText: '%',
                ),
                LabeledField(label: 'Ubicación', controller: _location, hint: 'Ej. Refrigerador'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Proveedor habitual'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sin proveedor')),
                    for (final s in store.activeSuppliers) DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                TextButton(onPressed: () => context.push(Routes.proveedores), child: const Text('Administrar proveedores')),
                const SizedBox(height: 8),
                LabeledField(
                  label: 'Código de barras',
                  controller: _barcode,
                  hint: 'Opcional',
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  trailing: IconButton.filledTonal(
                    tooltip: 'Escanear',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final code = await scanBarcode(context, title: 'Código del insumo');
                      if (code != null) setState(() => _barcode.text = code);
                    },
                  ),
                ),
                if (_editing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    title: const Text('Insumo activo'),
                    subtitle: const Text('Desactívalo si ya no se maneja'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PButton(label: 'Guardar', icon: Icons.check, variant: PButtonVariant.secondary, onPressed: _save),
        ],
      ),
    );
  }
}
