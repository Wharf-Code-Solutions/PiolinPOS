import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';

/// Hoja inferior para registrar un gasto rápido o imprevisto (R15, R18).
Future<void> showGastoImprevistoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _GastoSheet(),
  );
}

class _GastoSheet extends StatefulWidget {
  const _GastoSheet();

  @override
  State<_GastoSheet> createState() => _GastoSheetState();
}

class _GastoSheetState extends State<_GastoSheet> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;
  PaymentMethod _method = PaymentMethod.efectivo;
  bool _fromRegister = true;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoryId != null) return;
    final cats = StoreScope.read(context).activeExpenseCategories;
    final unforeseen = cats.where((c) => c.kind == ExpenseKind.unforeseen);
    _categoryId = unforeseen.isNotEmpty ? unforeseen.first.id : (cats.isEmpty ? null : cats.first.id);
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid =>
      _description.text.trim().isNotEmpty && (parseMoney(_amount.text) ?? 0) > 0 && _categoryId != null && !_saving;

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final cents = parseMoney(_amount.text)!;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      () => store.recordExpense(
        categoryId: _categoryId!,
        amountCents: cents,
        method: _method,
        paidFromRegister: _method == PaymentMethod.efectivo && _fromRegister && store.hasOpenShift,
        description: _description.text,
      ),
      success: 'Gasto de ${formatMoney(cents)} registrado',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final categories = store.activeExpenseCategories;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registrar gasto', style: PText.headlineMd()),
              const SizedBox(height: 16),
              Text('Concepto', style: PText.label(weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: _description,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Ej. Hielo, gas, refacción…'),
              ),
              const SizedBox(height: 12),
              Text('Monto', style: PText.label(weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
                style: PText.priceLg(),
                decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              Text('Categoría', style: PText.label(weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    CategoryChip(label: c.name, selected: c.id == _categoryId, onTap: () => setState(() => _categoryId = c.id)),
                ],
              ),
              const SizedBox(height: 12),
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
                  title: Text('Pagado con dinero de la caja', style: PText.bodyLg(weight: FontWeight.w600)),
                  subtitle: Text(store.hasOpenShift ? 'Se resta del efectivo esperado en el corte' : 'No hay turno abierto',
                      style: PText.bodyMd(color: PColors.gris)),
                ),
              const SizedBox(height: 12),
              PButton(label: 'Guardar gasto', icon: Icons.check, onPressed: _valid ? _save : null),
            ],
          ),
        ),
      ),
    );
  }
}
