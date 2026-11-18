import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Grupos de modificadores (p. ej. Super Torta: "Ingredientes", elige 2).
class ModificadoresScreen extends StatelessWidget {
  const ModificadoresScreen({super.key});

  Future<void> _edit(BuildContext context, [ModifierGroup? group]) async {
    final store = StoreScope.read(context);
    final result = await Navigator.of(context, rootNavigator: true).push<ModifierGroup>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _GroupEditor(group: group)),
    );
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => store.saveModifierGroup(result), success: 'Grupo "${result.name}" guardado');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final groups = store.modifierGroups;
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Modificadores', showBack: true, showSync: false, showLogo: false),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-mod',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Asigna los grupos a cada producto desde su pantalla de edición.',
              style: PText.bodyMd(color: PColors.gris)),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const EmptyState(
              icon: Icons.tune,
              title: 'Sin modificadores',
              message: 'Ejemplo: "Ingredientes" con mínimo 2 y máximo 2 para la Super Torta.',
            ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PCard(
                onTap: () => _edit(context, g),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name,
                              style: PText.bodyLg(weight: FontWeight.w700, color: g.active ? PColors.tinta : PColors.gris)),
                          Text('${g.ruleLabel} · ${g.activeModifiers.map((m) => m.name).join(', ')}',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: PText.bodyMd(color: PColors.gris)),
                          Text(
                            '${store.products.where((p) => p.active && p.modifierGroupIds.contains(g.id)).length} productos',
                            style: PText.label(color: PColors.morado),
                          ),
                        ],
                      ),
                    ),
                    if (!g.active) const StatusPill('Inactivo', background: PColors.beigeOscuro),
                    const Icon(Icons.chevron_right, color: PColors.gris),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModDraft {
  _ModDraft({this.id, String name = '', int deltaCents = 0, this.isDefault = false, this.active = true})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: deltaCents == 0 ? '' : centsToInput(deltaCents));

  final String? id;
  final TextEditingController name;
  final TextEditingController price;
  bool isDefault;
  bool active;
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({this.group});

  final ModifierGroup? group;

  @override
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late int _min = widget.group?.minSelect ?? 0;
  late int _max = widget.group?.maxSelect ?? 1;
  late bool _active = widget.group?.active ?? true;
  late final List<_ModDraft> _mods = [
    for (final m in widget.group?.modifiers ?? const <Modifier>[])
      _ModDraft(id: m.id, name: m.name, deltaCents: m.priceDeltaCents, isDefault: m.isDefault, active: m.active),
  ];

  @override
  void initState() {
    super.initState();
    if (_mods.isEmpty) _mods.add(_ModDraft());
  }

  @override
  void dispose() {
    _name.dispose();
    for (final m in _mods) {
      m.name.dispose();
      m.price.dispose();
    }
    super.dispose();
  }

  void _save() {
    final options = _mods.where((m) => m.name.text.trim().isNotEmpty).toList();
    if (_name.text.trim().isEmpty || options.where((m) => m.active).isEmpty) {
      showInfoSnack(context, 'Captura el nombre del grupo y al menos una opción', icon: Icons.warning_amber);
      return;
    }
    if (_max < 1 || _max < _min) {
      showInfoSnack(context, 'El máximo debe ser al menos 1 y mayor o igual al mínimo', icon: Icons.warning_amber);
      return;
    }
    final group = widget.group ?? ModifierGroup(id: newId(), name: '');
    group
      ..name = _name.text.trim()
      ..minSelect = _min
      ..maxSelect = _max
      ..active = _active;
    final byId = {for (final m in group.modifiers) m.id: m};
    final updated = <Modifier>[];
    for (final d in options) {
      final m = (d.id == null ? null : byId[d.id]) ?? Modifier(id: newId(), groupId: group.id, name: '');
      m
        ..name = d.name.text.trim()
        ..priceDeltaCents = parseMoney(d.price.text) ?? 0
        ..isDefault = d.isDefault
        ..active = d.active;
      updated.add(m);
    }
    group.modifiers
      ..clear()
      ..addAll(updated);
    Navigator.pop(context, group);
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: PText.label()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundIconButton(icon: Icons.remove, onPressed: value > 0 ? () => onChanged(value - 1) : null),
              SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.center, style: PText.priceLg())),
              RoundIconButton(icon: Icons.add, filled: true, onPressed: () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        title: Text(widget.group == null ? 'Nuevo grupo' : 'Editar grupo', style: PText.headlineMd(color: PColors.blanco)),
        actions: [TextButton(onPressed: _save, child: Text('Guardar', style: PText.button()))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: 'Nombre del grupo', controller: _name, hint: 'Ej. Ingredientes', isRequired: true),
          Row(children: [
            _stepper('Mínimo', _min, (v) => setState(() {
                  _min = v;
                  if (_max < _min) _max = _min;
                })),
            _stepper('Máximo', _max, (v) => setState(() => _max = v < 1 ? 1 : v)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Grupo activo'),
          ),
          const Divider(height: 24),
          const SectionHeader('Opciones'),
          const SizedBox(height: 8),
          for (final m in _mods)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: m.name,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(hintText: 'Opción (ej. Milanesa)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: m.price,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: const InputDecoration(hintText: '+ \$0', isDense: true, prefixText: '+\$ '),
                        ),
                      ),
                    ]),
                    Row(children: [
                      Checkbox(value: m.isDefault, onChanged: (v) => setState(() => m.isDefault = v ?? false)),
                      Text('Por defecto', style: PText.bodyMd()),
                      const Spacer(),
                      Text('Activa', style: PText.bodyMd()),
                      Switch(value: m.active, onChanged: (v) => setState(() => m.active = v)),
                    ]),
                  ],
                ),
              ),
            ),
          PButton(
            label: 'Agregar opción',
            icon: Icons.add,
            variant: PButtonVariant.soft,
            onPressed: () => setState(() => _mods.add(_ModDraft())),
          ),
        ],
      ),
    );
  }
}
