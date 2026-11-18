import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';

/// Compra a proveedor: entra al inventario y cuenta como gasto (R10, R15).
Future<void> showCompraSheet(BuildContext context, {InventoryItem? item}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _CompraSheet(initialItem: item),
  );
}

class _Line {
  _Line({this.itemId});

  String? itemId;
  final description = TextEditingController();
  final qty = TextEditingController();
  final total = TextEditingController();

  void dispose() {
    description.dispose();
    qty.dispose();
    total.dispose();
  }
}

class _CompraSheet extends StatefulWidget {
  const _CompraSheet({this.initialItem});

  final InventoryItem? initialItem;

  @override
  State<_CompraSheet> createState() => _CompraSheetState();
}

class _CompraSheetState extends State<_CompraSheet> {
  final List<_Line> _lines = [];
  String? _supplierId;
  String? _categoryId;
  PaymentMethod _method = PaymentMethod.efectivo;
  bool _fromRegister = false;
  bool _saving = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = StoreScope.read(context);
    final item = widget.initialItem;
    _lines.add(_Line(itemId: item?.id));
    _supplierId = item?.supplierId;
    final supplies = store.activeExpenseCategories.where((c) => c.kind == ExpenseKind.supplies).toList();
    _categoryId = supplies.isNotEmpty ? supplies.first.id : null;
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int get _total => _lines.fold(0, (a, l) => a + (parseMoney(l.total.text) ?? 0));

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final lines = <PurchaseLine>[];
    for (final l in _lines) {
      final qty = parseQtyMilli(l.qty.text) ?? 0;
      final total = parseMoney(l.total.text) ?? 0;
      final item = store.inventoryItemById(l.itemId);
      final desc = l.description.text.trim().isNotEmpty ? l.description.text.trim() : (item?.name ?? '');
      if (qty <= 0 && total <= 0 && desc.isEmpty) continue;
      if (qty <= 0 || total <= 0 || desc.isEmpty) {
        showInfoSnack(context, 'Cada línea necesita producto, cantidad y costo', icon: Icons.warning_amber);
        return;
      }
      lines.add(PurchaseLine(description: desc, qtyMilli: qty, totalCents: total, inventoryItemId: item?.id));
    }
    if (lines.isEmpty || _categoryId == null) {
      showInfoSnack(context, 'Agrega al menos una línea y la categoría', icon: Icons.warning_amber);
      return;
    }
    final supplier = store.supplierById(_supplierId);
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      () => store.recordExpense(
        categoryId: _categoryId!,
        amountCents: lines.fold(0, (a, l) => a + l.totalCents),
        method: _method,
        paidFromRegister: _method == PaymentMethod.efectivo && _fromRegister && store.hasOpenShift,
        supplierId: _supplierId,
        description: 'Compra${supplier == null ? '' : ' a ${supplier.name}'}',
        lines: lines,
      ),
      success: 'Compra de ${formatMoney(_total)} registrada',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.activeInventory;
    final supplies = store.activeExpenseCategories.where((c) => c.kind == ExpenseKind.supplies).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Registrar compra', style: PText.headlineMd()),
            Text('Suma al inventario y cuenta como gasto de insumos.', style: PText.bodyMd(color: PColors.gris)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _supplierId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Sin proveedor')),
                for (final s in store.activeSuppliers) DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in supplies)
                CategoryChip(label: c.name, selected: c.id == _categoryId, onTap: () => setState(() => _categoryId = c.id)),
            ]),
            const SizedBox(height: 12),
            for (var i = 0; i < _lines.length; i++)
              Padding(
                key: ObjectKey(_lines[i]),
                padding: const EdgeInsets.only(bottom: 10),
                child: PCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _lines[i].itemId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Insumo', isDense: true),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('No inventariado (texto libre)')),
                              for (final it in items)
                                DropdownMenuItem<String?>(value: it.id, child: Text('${it.name} (${it.unit.short})')),
                            ],
                            onChanged: (v) => setState(() => _lines[i].itemId = v),
                          ),
                        ),
                        if (_lines.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              final removed = _lines.removeAt(i);
                              setState(() {});
                              WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                            },
                          ),
                      ]),
                      if (_lines[i].itemId == null) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lines[i].description,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Descripción (ej. 5 kg de cebolla)', isDense: true),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _lines[i].qty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: moneyInputFormatters,
                            decoration: InputDecoration(
                              hintText: 'Cantidad',
                              isDense: true,
                              suffixText: store.inventoryItemById(_lines[i].itemId)?.unit.short,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _lines[i].total,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: moneyInputFormatters,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(hintText: 'Costo total', prefixText: '\$ ', isDense: true),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_Line())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar línea'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PaymentMethod>(
              segments: [
                for (final m in PaymentMethod.values) ButtonSegment(value: m, label: Text(m.label), icon: Icon(m.icon)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            if (_method == PaymentMethod.efectivo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fromRegister && store.hasOpenShift,
                onChanged: store.hasOpenShift ? (v) => setState(() => _fromRegister = v) : null,
                title: const Text('Pagado con dinero de la caja'),
              ),
            const SizedBox(height: 12),
            PButton(
              label: _saving ? 'Guardando…' : 'Guardar compra · ${formatMoney(_total)}',
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
