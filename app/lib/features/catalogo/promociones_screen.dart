import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/ids.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../domain/pricing.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Motor de promociones (R4): % por producto, combos a precio fijo y NxM.
class PromocionesScreen extends StatelessWidget {
  const PromocionesScreen({super.key});

  Future<void> _edit(BuildContext context, [Promotion? promo]) async {
    final store = StoreScope.read(context);
    final result = await Navigator.of(context, rootNavigator: true).push<Promotion>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PromoEditor(promo: promo, products: store.activeProducts)),
    );
    if (result == null || !context.mounted) return;
    await runGuarded(context, () => store.savePromotion(result), success: 'Promoción guardada');
  }

  static String describe(Promotion p, PosStore store) {
    final names = p.products.keys.map((id) => store.productById(id)?.name ?? '?').join(', ');
    final rule = switch (p.type) {
      PromotionType.percentOff => '${((p.percentBp ?? 0) / 100).toStringAsFixed(0)}% en $names',
      PromotionType.buyXGetY => 'Compra ${p.buyQty} y lleva ${p.freeQty} gratis · $names',
      PromotionType.fixedBundle =>
        '${p.products.entries.map((e) => '${e.value}× ${store.productById(e.key)?.name ?? '?'}').join(' + ')} '
            'por ${formatMoney(p.bundlePriceCents ?? 0)}',
    };
    final days = p.weekdaysMask == 127
        ? ''
        : ' · ${[for (var i = 0; i < 7; i++) if (p.weekdaysMask & (1 << i) != 0) _weekdayLabels[i]].join('')}';
    final hours = p.startTime == null && p.endTime == null ? '' : ' · ${p.startTime ?? '00:00'}–${p.endTime ?? '23:59'}';
    return '$rule$days$hours';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Promociones', showBack: true, showSync: false, showLogo: false),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-promo',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva promoción'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('Se aplican solas al cobrar cuando la cuenta cumple la regla y están vigentes.',
              style: PText.bodyMd(color: PColors.gris)),
          const SizedBox(height: 12),
          if (store.promotions.isEmpty)
            const EmptyState(icon: Icons.local_offer, title: 'Sin promociones', message: 'Ejemplo: "Martes 2×1 en refrescos".'),
          for (final p in store.promotions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PCard(
                onTap: () => _edit(context, p),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: PText.bodyLg(weight: FontWeight.w700)),
                          Text(describe(p, store), style: PText.bodyMd(color: PColors.gris)),
                        ],
                      ),
                    ),
                    if (!p.active)
                      const StatusPill('Inactiva', background: PColors.beigeOscuro)
                    else if (promotionIsActiveAt(p, now))
                      const StatusPill('Vigente ahora', background: Color(0xFFDDF5E4), foreground: PColors.verde),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PromoEditor extends StatefulWidget {
  const _PromoEditor({required this.promo, required this.products});

  final Promotion? promo;
  final List<Product> products;

  @override
  State<_PromoEditor> createState() => _PromoEditorState();
}

class _PromoEditorState extends State<_PromoEditor> {
  late final _name = TextEditingController(text: widget.promo?.name ?? '');
  late PromotionType _type = widget.promo?.type ?? PromotionType.buyXGetY;
  late final _percent =
      TextEditingController(text: widget.promo?.percentBp == null ? '' : (widget.promo!.percentBp! / 100).toStringAsFixed(0));
  late final _bundle = TextEditingController(
      text: widget.promo?.bundlePriceCents == null ? '' : centsToInput(widget.promo!.bundlePriceCents!));
  late int _buy = widget.promo?.buyQty ?? 1;
  late int _free = widget.promo?.freeQty ?? 1;
  late final Map<String, int> _products = {...?widget.promo?.products};
  late int _mask = widget.promo?.weekdaysMask ?? 127;
  late String? _startsOn = widget.promo?.startsOn;
  late String? _endsOn = widget.promo?.endsOn;
  late String? _startTime = widget.promo?.startTime;
  late String? _endTime = widget.promo?.endTime;
  late bool _active = widget.promo?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    _bundle.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final current = start ? _startsOn : _endsOn;
    final d = await showDatePicker(
      context: context,
      initialDate: current == null ? now : parseBusinessDate(current),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null) return;
    setState(() => start ? _startsOn = businessDate(d) : _endsOn = businessDate(d));
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: start ? const TimeOfDay(hour: 12, minute: 0) : const TimeOfDay(hour: 18, minute: 0));
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _startTime = v : _endTime = v);
  }

  void _save() {
    final name = _name.text.trim();
    final percent = int.tryParse(_percent.text) ?? 0;
    final bundle = parseMoney(_bundle.text);
    String? error;
    if (name.isEmpty) error = 'Captura el nombre';
    if (_products.isEmpty) error ??= 'Elige al menos un producto';
    if (_type == PromotionType.percentOff && (percent <= 0 || percent > 100)) error ??= 'El porcentaje debe ser de 1 a 100';
    if (_type == PromotionType.fixedBundle && (bundle == null || bundle <= 0)) error ??= 'Captura el precio del combo';
    if (_type == PromotionType.buyXGetY && (_buy < 1 || _free < 1)) error ??= 'Compra y regalo deben ser al menos 1';
    if (_mask == 0) error ??= 'Elige al menos un día';
    if (error != null) {
      showInfoSnack(context, error, icon: Icons.warning_amber);
      return;
    }
    final p = widget.promo ?? Promotion(id: newId(), name: name, type: _type);
    p
      ..name = name
      ..type = _type
      ..percentBp = _type == PromotionType.percentOff ? percent * 100 : null
      ..bundlePriceCents = _type == PromotionType.fixedBundle ? bundle : null
      ..buyQty = _type == PromotionType.buyXGetY ? _buy : null
      ..freeQty = _type == PromotionType.buyXGetY ? _free : null
      ..weekdaysMask = _mask
      ..startsOn = _startsOn
      ..endsOn = _endsOn
      ..startTime = _startTime
      ..endTime = _endTime
      ..active = _active;
    p.products
      ..clear()
      ..addAll(_products);
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        title: Text(widget.promo == null ? 'Nueva promoción' : 'Editar promoción', style: PText.headlineMd(color: PColors.blanco)),
        actions: [TextButton(onPressed: _save, child: Text('Guardar', style: PText.button()))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: 'Nombre', controller: _name, hint: 'Ej. Martes 2×1 en refrescos', isRequired: true),
          Text('Tipo', style: PText.label(color: PColors.tinta, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in PromotionType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t,
                selectedColor: PColors.moradoSuave,
                onSelected: (_) => setState(() => _type = t),
              ),
          ]),
          const SizedBox(height: 12),
          if (_type == PromotionType.percentOff)
            LabeledField(
              label: 'Porcentaje de descuento',
              controller: _percent,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixText: '%',
            ),
          if (_type == PromotionType.fixedBundle)
            LabeledField(
              label: 'Precio del combo',
              controller: _bundle,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters,
              prefixText: '\$ ',
            ),
          if (_type == PromotionType.buyXGetY)
            Row(children: [
              Expanded(child: _Counter(label: 'Compra', value: _buy, onChanged: (v) => setState(() => _buy = v))),
              Expanded(child: _Counter(label: 'Lleva gratis', value: _free, onChanged: (v) => setState(() => _free = v))),
            ]),
          const SizedBox(height: 12),
          SectionHeader(_type == PromotionType.fixedBundle ? 'Productos del combo' : 'Productos participantes'),
          const SizedBox(height: 6),
          if (widget.products.isEmpty) Text('Primero da de alta productos en el menú.', style: PText.bodyMd(color: PColors.gris)),
          for (final prod in widget.products)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _products.containsKey(prod.id),
              title: Text(prod.name),
              subtitle: Text(formatMoney(prod.priceCents)),
              secondary: _type == PromotionType.fixedBundle && _products.containsKey(prod.id)
                  ? SizedBox(
                      width: 120,
                      child: _Counter(
                        label: 'Piezas',
                        value: _products[prod.id]!,
                        onChanged: (v) => setState(() => _products[prod.id] = v < 1 ? 1 : v),
                        compact: true,
                      ),
                    )
                  : null,
              onChanged: (v) => setState(() => v == true ? _products[prod.id] = 1 : _products.remove(prod.id)),
            ),
          const Divider(height: 24),
          const SectionHeader('Vigencia'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(_weekdayLabels[i]),
                selected: _mask & (1 << i) != 0,
                selectedColor: PColors.moradoSuave,
                onSelected: (v) => setState(() => _mask = v ? _mask | (1 << i) : _mask & ~(1 << i)),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.event),
                label: Text(_startsOn == null ? 'Desde: siempre' : 'Desde ${formatShortDate(parseBusinessDate(_startsOn!))}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.event),
                label: Text(_endsOn == null ? 'Hasta: siempre' : 'Hasta ${formatShortDate(parseBusinessDate(_endsOn!))}'),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(true),
                icon: const Icon(Icons.schedule),
                label: Text(_startTime == null ? 'Todo el día' : 'Desde $_startTime'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(false),
                icon: const Icon(Icons.schedule),
                label: Text(_endTime == null ? 'Sin hora fin' : 'Hasta $_endTime'),
              ),
            ),
          ]),
          if (_startsOn != null || _endsOn != null || _startTime != null || _endTime != null)
            TextButton(
              onPressed: () => setState(() {
                _startsOn = null;
                _endsOn = null;
                _startTime = null;
                _endTime = null;
              }),
              child: const Text('Quitar fechas y horario'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Promoción activa'),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.onChanged, this.compact = false});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 40.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) Text(label, style: PText.label()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundIconButton(icon: Icons.remove, size: size, onPressed: value > 1 ? () => onChanged(value - 1) : null),
            SizedBox(width: compact ? 28 : 40, child: Text('$value', textAlign: TextAlign.center, style: PText.bodyLg(weight: FontWeight.w700))),
            RoundIconButton(icon: Icons.add, size: size, filled: true, onPressed: () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }
}
