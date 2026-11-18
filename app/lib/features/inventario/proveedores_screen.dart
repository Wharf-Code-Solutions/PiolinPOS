import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Catálogo de proveedores (R10).
class ProveedoresScreen extends StatelessWidget {
  const ProveedoresScreen({super.key});

  Future<void> _edit(BuildContext context, [Supplier? supplier]) async {
    final store = StoreScope.read(context);
    final result = await showDialog<Supplier>(context: context, builder: (_) => _SupplierDialog(supplier: supplier));
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => store.saveSupplier(result), success: 'Proveedor guardado');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Proveedores', showBack: true, showSync: false, showLogo: false),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-prov',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo proveedor'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (store.suppliers.isEmpty) const EmptyState(icon: Icons.store, title: 'Sin proveedores'),
          for (final s in store.suppliers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PCard(
                onTap: () => _edit(context, s),
                child: Row(
                  children: [
                    Icon(Icons.store, color: s.active ? PColors.morado : PColors.gris),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: PText.bodyLg(weight: FontWeight.w700, color: s.active ? PColors.tinta : PColors.gris)),
                          if ((s.phone ?? '').isNotEmpty) Text(s.phone!, style: PText.bodyMd(color: PColors.gris)),
                          if ((s.notes ?? '').isNotEmpty) Text(s.notes!, style: PText.label()),
                        ],
                      ),
                    ),
                    if (!s.active) const StatusPill('Inactivo', background: PColors.beigeOscuro),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({this.supplier});

  final Supplier? supplier;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final _name = TextEditingController(text: widget.supplier?.name ?? '');
  late final _phone = TextEditingController(text: widget.supplier?.phone ?? '');
  late final _notes = TextEditingController(text: widget.supplier?.notes ?? '');
  late bool _active = widget.supplier?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? 'Nuevo proveedor' : 'Editar proveedor', style: PText.headlineMd()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notas (qué surte, días de entrega)'),
            ),
            if (widget.supplier != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Activo'),
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
                  final s = widget.supplier ?? Supplier(id: newId(), name: '');
                  s
                    ..name = _name.text.trim()
                    ..phone = _phone.text.trim().isEmpty ? null : _phone.text.trim()
                    ..notes = _notes.text.trim().isEmpty ? null : _notes.text.trim()
                    ..active = _active;
                  Navigator.pop(context, s);
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
