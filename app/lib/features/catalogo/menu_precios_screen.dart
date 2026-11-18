import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Menú y precios — catálogo, disponibilidad y accesos a categorías, modificadores y promociones.
class MenuPreciosScreen extends StatefulWidget {
  const MenuPreciosScreen({super.key});

  @override
  State<MenuPreciosScreen> createState() => _MenuPreciosScreenState();
}

class _MenuPreciosScreenState extends State<MenuPreciosScreen> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final categories = store.menuCategories;
    if (categories.isEmpty) {
      return Scaffold(
        appBar: const PiolinAppBar(title: 'Menú y precios', showBack: true, showSync: false),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.category,
            title: 'Sin categorías activas',
            message: 'Crea o activa una categoría para agregar productos.',
            action: PButton(
              label: 'Categorías',
              expand: false,
              variant: PButtonVariant.secondary,
              onPressed: () => context.push(Routes.categorias),
            ),
          ),
        ),
      );
    }
    final category = categories.firstWhere((c) => c.id == _categoryId, orElse: () => categories.first);
    final products = store.productsIn(category.id);
    final available = products.where((p) => p.available).length;

    return Scaffold(
      appBar: const PiolinAppBar(
        title: 'Menú y precios',
        showBack: true,
        showSync: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catálogo y Disponibilidad', style: PText.headlineLg()),
                      Text('Modificación rápida en caliente', style: PText.label(color: PColors.gris)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PButton(
                  label: 'Nuevo producto',
                  icon: Icons.add,
                  expand: false,
                  height: 52,
                  onPressed: () => context.push(Routes.nuevoProducto),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.category, size: 18),
                label: const Text('Categorías'),
                onPressed: () => context.push(Routes.categorias),
              ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: const Text('Modificadores'),
                onPressed: () => context.push(Routes.modificadores),
              ),
              ActionChip(
                avatar: const Icon(Icons.local_offer, size: 18),
                label: Text('Promociones (${store.promotions.where((p) => p.active).length})'),
                onPressed: () => context.push(Routes.promociones),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          ChipRow(children: [
            for (final c in categories)
              CategoryChip(
                label: '${c.name} (${store.productsIn(c.id).length})',
                icon: c.icon,
                selected: c.id == category.id,
                onTap: () => setState(() => _categoryId = c.id),
              ),
          ]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 22,
                        decoration: BoxDecoration(color: PColors.morado, borderRadius: PRadius.pill),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(category.name.toUpperCase(), style: PText.sectionHeader())),
                      StatusPill('$available en pantalla', background: PColors.moradoSuave, foreground: PColors.morado),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (products.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Sin productos', style: PText.bodyMd(color: PColors.gris)),
                    ),
                  for (final p in products) _ProductPriceRow(key: ValueKey(p.id), product: p),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.price_change,
                    iconColor: PColors.morado,
                    title: 'Ajustes hoy',
                    value: '${store.priceChangesToday}',
                    valueColor: PColors.tinta,
                    caption: 'precios cambiados',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.inventory_2,
                    iconColor: PColors.rojo,
                    title: 'Sin stock',
                    value: '${store.unavailableCount}',
                    valueColor: PColors.rojo,
                    caption: store.unavailableCount == 1 ? 'platillo bloqueado' : 'platillos bloqueados',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPriceRow extends StatefulWidget {
  const _ProductPriceRow({super.key, required this.product});

  final Product product;

  @override
  State<_ProductPriceRow> createState() => _ProductPriceRowState();
}

class _ProductPriceRowState extends State<_ProductPriceRow> {
  late final TextEditingController _price = TextEditingController(text: centsToInput(widget.product.priceCents));
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _price.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (!mounted) return;
    final cents = parseMoney(_price.text);
    final store = StoreScope.read(context);
    if (cents == null || cents <= 0) {
      _price.text = centsToInput(widget.product.priceCents);
      return;
    }
    if (cents != widget.product.priceCents) {
      final name = widget.product.name;
      runGuarded(context, () => store.updatePrice(widget.product, cents), success: '$name: nuevo precio ${formatMoney(cents)}');
    }
    _price.text = centsToInput(cents);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = widget.product;
    final off = !p.available;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: off ? PColors.beigeOscuro : PColors.beige,
              borderRadius: PRadius.cardBr,
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push(Routes.producto(p.id)),
                    child: Opacity(
                    opacity: off ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: PText.bodyLg(weight: FontWeight.w700).copyWith(
                                  fontSize: 18,
                                  decoration: off ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (p.favorite && !off) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star_border, size: 20, color: PColors.amarilloTexto),
                            ],
                            if (off) ...[
                              const SizedBox(width: 8),
                              const StatusPill('Agotado', background: PColors.errorBg, foreground: PColors.rojo),
                            ],
                          ],
                        ),
                        if (p.description.isNotEmpty)
                          Text(p.description, style: PText.bodyMd(color: PColors.gris)),
                        Text('Toca para editar', style: PText.label(color: PColors.morado)),
                      ],
                    ),
                  ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 104,
                  child: TextField(
                    controller: _price,
                    focusNode: _focus,
                    enabled: !off,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onSubmitted: (_) => _focus.unfocus(),
                    style: PText.priceSm().copyWith(fontSize: 18),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: PColors.blanco,
                      prefixText: '\$ ',
                      prefixStyle: PText.priceSm().copyWith(fontSize: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: PRadius.cardBr, borderSide: BorderSide.none),
                      disabledBorder: OutlineInputBorder(borderRadius: PRadius.cardBr, borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: p.available,
                  onChanged: (v) => runGuarded(context, () => store.setAvailability(p, v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            off ? 'Agotado hoy (No vendible)' : 'Disponible en terminal',
            style: PText.label(color: off ? PColors.rojo : PColors.morado, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title.toUpperCase(), style: PText.label(color: PColors.tinta, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: PText.priceLg(color: valueColor).copyWith(fontSize: 28)),
              const SizedBox(width: 6),
              Flexible(child: Text(caption, style: PText.bodyMd(color: PColors.gris))),
            ],
          ),
        ],
      ),
    );
  }
}
