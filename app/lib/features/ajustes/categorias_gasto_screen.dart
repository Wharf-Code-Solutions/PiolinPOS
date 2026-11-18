import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Categorías de gasto (R15) con % de merma estimada para lo no inventariado (R18).
class CategoriasGastoScreen extends StatelessWidget {
  const CategoriasGastoScreen({super.key});

  Future<void> _edit(BuildContext context, [ExpenseCategory? c]) async {
    final store = StoreScope.read(context);
    final result = await showDialog<ExpenseCategory>(context: context, builder: (_) => _Dialog(category: c));
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => store.saveExpenseCategory(result), success: 'Categoría guardada');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Categorías de gasto', showBack: true, showSync: false, showLogo: false),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-expcat',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Las de tipo "Insumos" entran en la comparativa de insumos contra ventas.',
              style: PText.bodyMd(color: PColors.gris)),
          const SizedBox(height: 12),
          for (final kind in ExpenseKind.values) ...[
            SectionHeader(kind.label, color: PColors.gris),
            const SizedBox(height: 6),
            for (final c in store.expenseCategories.where((c) => c.kind == kind))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.name, style: PText.bodyLg(weight: FontWeight.w600, color: c.active ? PColors.tinta : PColors.gris)),
                subtitle: c.wasteBp > 0 ? Text('Merma estimada ${(c.wasteBp / 100).toStringAsFixed(0)}%') : null,
                trailing: c.active ? const Icon(Icons.chevron_right) : const StatusPill('Inactiva', background: PColors.beigeOscuro),
                onTap: () => _edit(context, c),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Dialog extends StatefulWidget {
  const _Dialog({this.category});

  final ExpenseCategory? category;

  @override
  State<_Dialog> createState() => _DialogState();
}

class _DialogState extends State<_Dialog> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _waste =
      TextEditingController(text: widget.category == null ? '0' : (widget.category!.wasteBp / 100).toStringAsFixed(0));
  late ExpenseKind _kind = widget.category?.kind ?? ExpenseKind.supplies;
  late bool _active = widget.category?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _waste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría', style: PText.headlineMd()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final k in ExpenseKind.values)
                ChoiceChip(label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _waste,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '% de merma estimada', suffixText: '%'),
            ),
            if (widget.category != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Activa'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PColors.morado),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  final waste = int.tryParse(_waste.text) ?? 0;
                  final c = widget.category ?? ExpenseCategory(id: newId(), name: '', kind: _kind);
                  c
                    ..name = _name.text.trim()
                    ..kind = _kind
                    ..wasteBp = (waste > 100 ? 100 : waste) * 100
                    ..active = _active;
                  Navigator.pop(context, c);
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
