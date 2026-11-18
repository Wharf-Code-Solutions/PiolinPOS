import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/barcode_scanner.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Alta y edición de productos del menú (R14).
class ProductoFormScreen extends StatefulWidget {
  const ProductoFormScreen({super.key, this.productId});

  /// null = producto nuevo.
  final String? productId;

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _barcode = TextEditingController();
  final _consume = TextEditingController(text: '1');

  Product? _editing;
  String? _categoryId;
  ProductIcon _icon = ProductIcon.taco;
  bool _flavorNote = false;
  bool _favorite = false;
  String? _inventoryItemId;
  final Set<String> _groupIds = {};
  bool _submitted = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    final p = widget.productId == null ? null : store.productById(widget.productId!);
    _editing = p;
    if (p != null) {
      _name.text = p.name;
      _description.text = p.description;
      _price.text = centsToInput(p.priceCents);
      _barcode.text = p.barcode ?? '';
      _categoryId = p.categoryId;
      _icon = p.icon;
      _flavorNote = p.notePlaceholder == 'Sabor';
      _favorite = p.favorite;
      _inventoryItemId = p.inventoryItemId;
      _consume.text = formatQty(p.consumeQtyMilli);
      _groupIds.addAll(p.modifierGroupIds);
    } else {
      final cats = store.menuCategories;
      _categoryId = cats.isEmpty ? null : cats.first.id;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _barcode, _consume]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _priceCents => parseMoney(_price.text) ?? 0;

  void _bumpPrice(int cents) {
    _price.text = centsToInput(_priceCents + cents);
    setState(() {});
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context, title: 'Código del producto');
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_name.text.trim().isEmpty || _priceCents <= 0 || _categoryId == null) {
      showInfoSnack(context, 'Captura nombre, categoría y precio de venta', icon: Icons.warning_amber);
      return;
    }
    final consume = parseQtyMilli(_consume.text) ?? 1000;
    if (_inventoryItemId != null && consume <= 0) {
      showInfoSnack(context, 'La cantidad a descontar debe ser mayor a cero', icon: Icons.warning_amber);
      return;
    }
    final store = StoreScope.read(context);
    final existing = _editing;
    final previousPrice = existing?.priceCents;
    final product = existing ?? Product(id: newId(), name: '', priceCents: 0, categoryId: _categoryId!);
    product
      ..name = _name.text.trim()
      ..description = _description.text.trim()
      ..categoryId = _categoryId!
      ..icon = _icon
      ..notePlaceholder = _flavorNote ? 'Sabor' : 'Nota'
      ..favorite = _favorite
      ..barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim()
      ..inventoryItemId = _inventoryItemId
      ..consumeQtyMilli = consume
      ..modifierGroupIds = _groupIds.toList();
    setState(() => _saving = true);
    final ok = await runGuarded(context, () async {
      if (existing != null && previousPrice != _priceCents) {
        await store.updatePrice(product, _priceCents);
      } else {
        product.priceCents = _priceCents;
      }
      await store.saveProduct(product);
    }, success: existing == null ? '${product.name} agregado al menú' : 'Cambios guardados');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  Future<void> _deactivate() async {
    final p = _editing;
    if (p == null) return;
    final ok = await confirmDialog(context,
        title: 'Dar de baja',
        message: '${p.name} dejará de aparecer en el menú. Su historial de ventas se conserva.',
        confirmLabel: 'Dar de baja',
        destructive: true);
    if (!ok || !mounted) return;
    final done = await runGuarded(context, () => StoreScope.read(context).deactivateProduct(p),
        success: '${p.name} dado de baja');
    if (done && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final nameError = _submitted && _name.text.trim().isEmpty;
    final priceError = _submitted && _priceCents <= 0;
    final categories = store.menuCategories;
    final items = store.activeInventory;
    final linkedItem = store.inventoryItemById(_inventoryItemId);

    return Scaffold(
      appBar: PiolinAppBar(
        title: _editing == null ? 'Nuevo Producto' : 'Editar Producto',
        subtitle: 'Menú y precios',
        showBack: true,
        showLogo: false,
        showSync: false,
        showAdmin: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _FormSection(
            icon: Icons.edit_note,
            iconBg: PColors.moradoSuave,
            iconColor: PColors.morado,
            title: 'Información básica',
            children: [
              const _FieldLabel('Nombre del producto', isRequired: true, hint: 'Máx. 40 caract.'),
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: PText.bodyLg(),
                decoration: InputDecoration(
                  hintText: 'Ej. Taco de pastor',
                  counterText: '',
                  errorText: nameError ? 'Requerido' : null,
                ),
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Descripción', hint: 'Opcional'),
              TextField(
                controller: _description,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                style: PText.bodyLg(),
                decoration: const InputDecoration(hintText: 'Ej. Maíz doble con piña', counterText: ''),
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Categoría', isRequired: true),
              if (categories.isEmpty)
                TextButton(onPressed: () => context.push(Routes.categorias), child: const Text('Crear una categoría')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    CategoryChip(
                      label: c.name,
                      icon: c.icon,
                      selected: _categoryId == c.id,
                      onTap: () => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _favorite,
                onChanged: (v) => setState(() => _favorite = v),
                title: Text('Favorito', style: PText.bodyLg(weight: FontWeight.w600)),
                subtitle: Text('Se marca con estrella en el catálogo', style: PText.bodyMd(color: PColors.gris)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _flavorNote,
                onChanged: (v) => setState(() => _flavorNote = v),
                title: Text('Pedir sabor en lugar de nota', style: PText.bodyLg(weight: FontWeight.w600)),
                subtitle: Text('Útil para refrescos y aguas', style: PText.bodyMd(color: PColors.gris)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: Icons.payments,
            iconBg: PColors.amarillo,
            iconColor: PColors.tinta,
            title: 'Precio de venta',
            trailing: const StatusPill('MXN', background: PColors.beigeOscuro),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: PColors.beige,
                  borderRadius: PRadius.cardBr,
                  border: priceError ? Border.all(color: PColors.rojo, width: 2) : null,
                ),
                child: TextField(
                  controller: _price,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                  style: PText.priceXl().copyWith(fontSize: 36),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: '\$ ',
                    prefixStyle: PText.priceXl(color: PColors.morado).copyWith(fontSize: 36),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final c in [500, 1000, 2500])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _QuickButton(label: '+${formatMoneyShort(c)}', onTap: () => _bumpPrice(c)),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: _QuickButton(label: 'Borrar', dark: true, onTap: () => setState(() => _price.clear())),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: Icons.palette,
            iconBg: PColors.errorBg,
            iconColor: PColors.rojo,
            title: 'Botón en pantalla',
            children: [
              Row(
                children: [
                  for (final i in ProductIcon.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _OptionTile(
                          height: 72,
                          selected: _icon == i,
                          onTap: () => setState(() => _icon = i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(i.icon, color: _icon == i ? PColors.morado : PColors.tinta),
                              const SizedBox(height: 4),
                              Text(i.label,
                                  style: PText.label(
                                      color: _icon == i ? PColors.morado : PColors.gris,
                                      weight: _icon == i ? FontWeight.w700 : FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: Icons.tune,
            iconBg: PColors.moradoSuave,
            iconColor: PColors.morado,
            title: 'Modificadores',
            titleSuffix: ' (opcional)',
            children: [
              if (store.modifierGroups.where((g) => g.active).isEmpty)
                Text('No hay grupos de modificadores. Créalos en Menú y precios › Modificadores.',
                    style: PText.bodyMd(color: PColors.gris)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in store.modifierGroups.where((g) => g.active))
                    FilterChip(
                      label: Text('${g.name} · ${g.ruleLabel}'),
                      selected: _groupIds.contains(g.id),
                      selectedColor: PColors.moradoSuave,
                      onSelected: (v) => setState(() => v ? _groupIds.add(g.id) : _groupIds.remove(g.id)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: Icons.inventory,
            iconBg: PColors.beigeOscuro,
            iconColor: PColors.tinta,
            title: 'Inventario',
            titleSuffix: ' (empaquetados)',
            children: [
              Text('Al cobrar se descuenta del insumo elegido (p. ej. Refresco 600 ml → 1 pieza).',
                  style: PText.bodyMd(color: PColors.gris)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _inventoryItemId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Insumo que descuenta'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('No descontar inventario')),
                  for (final i in items) DropdownMenuItem<String?>(value: i.id, child: Text('${i.name} (${i.unit.short})')),
                ],
                onChanged: (v) => setState(() => _inventoryItemId = v),
              ),
              if (linkedItem != null) ...[
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Cantidad por pieza vendida',
                  controller: _consume,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: moneyInputFormatters,
                  suffixText: linkedItem.unit.short,
                ),
              ],
              if (items.isEmpty)
                TextButton(
                  onPressed: () => context.push(Routes.nuevoInsumo),
                  child: const Text('Dar de alta un insumo'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            icon: Icons.qr_code_scanner,
            iconBg: PColors.beigeOscuro,
            iconColor: PColors.tinta,
            title: 'Código de barras',
            titleSuffix: ' (opcional)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: PText.bodyLg(),
                      decoration: const InputDecoration(hintText: 'Número del código'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PButton(
                    label: 'Escanear',
                    icon: Icons.qr_code_scanner,
                    variant: PButtonVariant.ghost,
                    expand: false,
                    height: 52,
                    onPressed: _scan,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          PButton(
            label: _saving ? 'Guardando…' : (_editing == null ? 'Guardar y agregar al menú' : 'Guardar cambios'),
            icon: Icons.check_circle_outline,
            variant: PButtonVariant.secondary,
            height: 60,
            onPressed: _saving ? null : _save,
          ),
          if (_editing != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _deactivate,
              icon: const Icon(Icons.delete_outline, color: PColors.rojo),
              label: Text('Dar de baja del menú', style: PText.bodyMd(color: PColors.rojo, weight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.children,
    this.trailing,
    this.titleSuffix,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? titleSuffix;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIcon(icon: icon, bg: iconBg, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: title),
                    if (titleSuffix != null)
                      TextSpan(text: titleSuffix, style: PText.bodyMd(color: PColors.gris)),
                  ]),
                  style: PText.headlineMd(),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, required this.bg, required this.color});

  final IconData icon;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.isRequired = false, this.hint});

  final String text;
  final bool isRequired;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: PText.label(color: PColors.tinta, weight: FontWeight.w700).copyWith(fontSize: 13)),
          if (isRequired) Text(' *', style: PText.label(color: PColors.rojo, weight: FontWeight.w700)),
          const Spacer(),
          if (hint != null) Text(hint!, style: PText.label(weight: FontWeight.w400)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.selected, required this.onTap, required this.child, this.height});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PColors.moradoSuave : PColors.beige,
      shape: RoundedRectangleBorder(
        borderRadius: PRadius.cardBr,
        side: BorderSide(color: selected ? PColors.morado : Colors.transparent),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap, this.dark = false});

  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? const Color(0xFFE2DAC6) : PColors.beigeOscuro,
      borderRadius: PRadius.cardBr,
      child: InkWell(
        borderRadius: PRadius.cardBr,
        onTap: onTap,
        child: Container(
          height: 48,
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(label, style: PText.bodyMd(weight: FontWeight.w700)),
        ),
      ),
    );
  }
}
