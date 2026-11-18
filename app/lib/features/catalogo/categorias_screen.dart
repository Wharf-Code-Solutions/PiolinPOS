import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Categorías del menú y del inventario.
class CategoriasScreen extends StatelessWidget {
  const CategoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PiolinAppBar(title: 'Categorías', showBack: true, showSync: false, showLogo: false),
        body: Column(
          children: [
            Material(
              color: PColors.blanco,
              child: TabBar(
                labelColor: PColors.morado,
                indicatorColor: PColors.morado,
                tabs: [Tab(text: 'Menú'), Tab(text: 'Inventario')],
              ),
            ),
            Expanded(
              child: TabBarView(children: [
                _CategoryList(kind: CategoryKind.menu),
                _CategoryList(kind: CategoryKind.inventario),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  Future<void> _edit(BuildContext context, [MenuCategory? category]) async {
    final store = StoreScope.read(context);
    final list = kind == CategoryKind.menu ? store.allMenuCategories : store.allInventoryCategories;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _CategoryDialog(category: category),
    );
    if (result == null || !context.mounted) return;
    final (name, icon) = result;
    final c = category ??
        MenuCategory(id: newId(), name: name, iconKey: icon, kind: kind, sortOrder: list.length);
    c
      ..name = name
      ..iconKey = icon;
    await runGuarded(context, () => store.saveCategory(c), success: 'Categoría guardada');
  }

  Future<void> _move(BuildContext context, List<MenuCategory> list, int index, int delta) async {
    final store = StoreScope.read(context);
    final j = index + delta;
    if (j < 0 || j >= list.length) return;
    final reordered = [...list];
    final item = reordered.removeAt(index);
    reordered.insert(j, item);
    for (var k = 0; k < reordered.length; k++) {
      reordered[k].sortOrder = k;
    }
    await runGuarded(context, () async {
      for (final c in reordered) {
        await store.saveCategory(c);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = kind == CategoryKind.menu ? store.allMenuCategories : store.allInventoryCategories;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-cat-${kind.name}',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (list.isEmpty) const EmptyState(icon: Icons.category, title: 'Sin categorías'),
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onTap: () => _edit(context, list[i]),
                child: Row(
                  children: [
                    Icon(list[i].icon, color: list[i].active ? PColors.morado : PColors.gris),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(list[i].name,
                          style: PText.bodyLg(
                              weight: FontWeight.w700, color: list[i].active ? PColors.tinta : PColors.gris)),
                    ),
                    IconButton(
                      tooltip: 'Subir',
                      icon: const Icon(Icons.arrow_upward, size: 20),
                      onPressed: i == 0 ? null : () => _move(context, list, i, -1),
                    ),
                    IconButton(
                      tooltip: 'Bajar',
                      icon: const Icon(Icons.arrow_downward, size: 20),
                      onPressed: i == list.length - 1 ? null : () => _move(context, list, i, 1),
                    ),
                    Switch(
                      value: list[i].active,
                      onChanged: (v) {
                        list[i].active = v;
                        runGuarded(context, () => store.saveCategory(list[i]));
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final MenuCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late String _icon = widget.category?.iconKey ?? categoryIconOptions.keys.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Nueva categoría' : 'Editar categoría', style: PText.headlineMd()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Nombre', counterText: ''),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in categoryIconOptions.entries)
                ChoiceChip(
                  label: Icon(e.value, size: 20, color: _icon == e.key ? PColors.morado : PColors.tinta),
                  selected: _icon == e.key,
                  selectedColor: PColors.moradoSuave,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _icon = e.key),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PColors.morado),
          onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, (_name.text.trim(), _icon)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
