import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/barcode_scanner.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';
import 'compra_sheet.dart';
import 'gasto_imprevisto_sheet.dart';

/// Inventario — control de almacén (R2, R8, R10).
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  String? _categoryId; // null = Todos
  String _query = '';
  bool _onlyLow = false;

  Future<void> _scan() async {
    final store = StoreScope.read(context);
    final code = await scanBarcode(context, title: 'Buscar insumo');
    if (code == null || !mounted) return;
    final item = store.inventoryItemByBarcode(code);
    if (item != null) {
      showItemSheet(context, item);
      return;
    }
    final create = await confirmDialog(context,
        title: 'Código no registrado', message: 'Ningún insumo tiene el código $code. ¿Dar de alta uno nuevo?',
        confirmLabel: 'Dar de alta');
    if (create && mounted) context.push('${Routes.nuevoInsumo}?barcode=$code');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _query.toLowerCase();
    final items = store.activeInventory
        .where((i) => _categoryId == null || i.categoryId == _categoryId)
        .where((i) => !_onlyLow || i.isLow)
        .where((i) =>
            q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            (store.supplierById(i.supplierId)?.name.toLowerCase().contains(q) ?? false))
        .toList();

    return Scaffold(
      appBar: const PiolinAppBar(title: 'El Piolín', subtitle: 'Inventario', pill: ShiftOpenPill()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-escanear',
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        shape: const StadiumBorder(),
        onPressed: _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text('Escanear', style: PText.button()),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: PColors.beigeOscuro,
              borderRadius: PRadius.cardBr,
              child: InkWell(
                borderRadius: PRadius.cardBr,
                onTap: () => setState(() => _onlyLow = !_onlyLow),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_onlyLow ? 'Mostrando solo stock bajo' : 'Toca para ver solo stock bajo',
                                style: PText.label(color: PColors.gris)),
                            Text('Control de Almacén', style: PText.headlineLg()),
                          ],
                        ),
                      ),
                      StatusPill(
                        '${store.criticalCount} crítico${store.criticalCount == 1 ? '' : 's'}',
                        background: PColors.blanco,
                        dotColor: store.criticalCount > 0 ? PColors.rojo : PColors.verde,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.add_box, size: 18),
                label: const Text('Nuevo insumo'),
                onPressed: () => context.push(Routes.nuevoInsumo),
              ),
              ActionChip(
                avatar: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Compra'),
                onPressed: () => showCompraSheet(context),
              ),
              ActionChip(
                avatar: const Icon(Icons.fact_check, size: 18),
                label: const Text('Conteo físico'),
                onPressed: () => context.push(Routes.conteo),
              ),
              ActionChip(
                avatar: const Icon(Icons.store, size: 18),
                label: const Text('Proveedores'),
                onPressed: () => context.push(Routes.proveedores),
              ),
              ActionChip(
                avatar: const Icon(Icons.receipt, size: 18),
                label: const Text('Gastos'),
                onPressed: () => context.push(Routes.gastos),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar insumo o proveedor...',
                prefixIcon: const Icon(Icons.search, color: PColors.gris),
                fillColor: PColors.blanco,
                enabledBorder: OutlineInputBorder(
                  borderRadius: PRadius.cardBr,
                  borderSide: const BorderSide(color: PColors.borde),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ChipRow(children: [
            CategoryChip(
              label: 'Todos',
              icon: Icons.apps,
              selected: _categoryId == null,
              onTap: () => setState(() => _categoryId = null),
            ),
            for (final c in store.inventoryCategories)
              CategoryChip(
                label: c.name,
                icon: c.icon,
                selected: _categoryId == c.id,
                onTap: () => setState(() => _categoryId = c.id),
              ),
          ]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader('Insumos (${items.length})', color: PColors.gris),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _InventoryCard(item: item, onTap: () => showItemSheet(context, item)),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: store.activeInventory.isEmpty
                  ? EmptyState(
                      icon: Icons.inventory_2,
                      title: 'Sin insumos',
                      message: 'Da de alta refrescos, carnes y pan para controlar su stock.',
                      action: PButton(
                        label: 'Nuevo insumo',
                        expand: false,
                        variant: PButtonVariant.secondary,
                        onPressed: () => context.push(Routes.nuevoInsumo),
                      ),
                    )
                  : Text('Sin resultados', textAlign: TextAlign.center, style: PText.bodyMd(color: PColors.gris)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: PButton(
              label: '+ Registrar gasto imprevisto',
              icon: Icons.add_shopping_cart,
              variant: PButtonVariant.soft,
              height: 60,
              onPressed: () => showGastoImprevistoSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja de un insumo: ajuste rápido, merma, compra, edición e historial.
Future<void> showItemSheet(BuildContext context, InventoryItem item) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (ctx) => _ItemSheet(itemId: item.id, parentContext: context),
  );
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.itemId, required this.parentContext});

  final String itemId;
  final BuildContext parentContext;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late Future<List<InventoryMovement>> _movements = _load();

  Future<List<InventoryMovement>> _load() => StoreScope.read(context).repo.loadMovements(widget.itemId);

  Future<void> _adjust(InventoryItem item, int delta, {MovementType type = MovementType.adjustment, String? note}) async {
    await runGuarded(context, () => StoreScope.read(context).adjustStock(item, delta, type: type, note: note));
    if (mounted) setState(() => _movements = _load());
  }

  Future<void> _waste(InventoryItem item) async {
    final qty = await askText(context,
        title: 'Registrar merma', hint: 'Cantidad en ${item.unit.label}', confirmLabel: 'Siguiente', maxLength: 10);
    if (qty == null || !mounted) return;
    final milli = parseQtyMilli(qty);
    if (milli == null || milli <= 0) return;
    final reason = await askText(context,
        title: 'Motivo de la merma', suggestions: const ['Caducado', 'Se echó a perder', 'Roto / derramado']);
    if (reason == null || !mounted) return;
    await _adjust(item, -milli, type: MovementType.waste, note: reason);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final item = store.inventoryItemById(widget.itemId);
    if (item == null) return const SizedBox(height: 120);
    final step = item.unit == InventoryUnit.pza ? 1000 : 500;
    final supplier = store.supplierById(item.supplierId);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(item.name, style: PText.headlineMd()),
          Text(
            [
              if (supplier != null) 'Proveedor: ${supplier.name}',
              if (item.location.isNotEmpty) item.location,
            ].join(' · '),
            style: PText.bodyMd(color: PColors.gris),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundIconButton(icon: Icons.remove, size: 56, onPressed: () => _adjust(item, -step, note: 'Ajuste manual')),
              SizedBox(
                width: 140,
                child: Column(
                  children: [
                    Text(formatQty(item.stockMilli), style: PText.priceXl(color: item.isLow ? PColors.rojo : PColors.tinta)),
                    Text(item.unit.label, style: PText.label()),
                  ],
                ),
              ),
              RoundIconButton(
                  icon: Icons.add, size: 56, filled: true, onPressed: () => _adjust(item, step, note: 'Ajuste manual')),
            ],
          ),
          const SizedBox(height: 8),
          Center(child: Text('Mínimo: ${formatQty(item.minStockMilli)} ${item.unit.short}', style: PText.label())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: PButton(
                label: 'Compra',
                icon: Icons.local_shipping,
                variant: PButtonVariant.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  showCompraSheet(widget.parentContext, item: item);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PButton(label: 'Merma', icon: Icons.delete_sweep, variant: PButtonVariant.ghost, onPressed: () => _waste(item)),
            ),
          ]),
          const SizedBox(height: 8),
          PButton(
            label: 'Editar insumo',
            icon: Icons.edit,
            variant: PButtonVariant.soft,
            onPressed: () {
              Navigator.pop(context);
              widget.parentContext.push(Routes.insumo(item.id));
            },
          ),
          const SizedBox(height: 16),
          const SectionHeader('Últimos movimientos', color: PColors.gris),
          FutureBuilder<List<InventoryMovement>>(
            future: _movements,
            builder: (context, snap) {
              final list = snap.data ?? const <InventoryMovement>[];
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              if (list.isEmpty) return Text('Sin movimientos', style: PText.bodyMd(color: PColors.gris));
              return Column(children: [
                for (final m in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text('${m.type.label}${m.note == null || m.note!.isEmpty ? '' : ' · ${m.note}'}'),
                    subtitle: Text(formatDateTime(m.createdAt)),
                    trailing: Text('${m.qtyMilli > 0 ? '+' : ''}${formatQty(m.qtyMilli)} ${item.unit.short}',
                        style: PText.bodyLg(
                            weight: FontWeight.w700, color: m.qtyMilli > 0 ? PColors.verde : PColors.rojo)),
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onTap});

  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final low = item.isLow;
    final supplier = store.supplierById(item.supplierId);
    return PCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PText.bodyLg(weight: FontWeight.w700)),
                if (supplier != null) Text('Proveedor: ${supplier.name}', style: PText.bodyMd(color: PColors.gris)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    low
                        ? const StatusPill('Poco stock',
                            icon: Icons.error_outline, background: PColors.errorBg, foreground: PColors.rojo)
                        : const StatusPill('Suficiente',
                            icon: Icons.check_circle_outline,
                            background: Color(0xFFF1EBD6),
                            foreground: PColors.amarilloTexto),
                    if (low)
                      Text('Mín: ${formatQty(item.minStockMilli)}',
                          style: PText.label(color: PColors.rojo, weight: FontWeight.w700))
                    else if (item.location.isNotEmpty)
                      Text(item.location, style: PText.label(weight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatQty(item.stockMilli), style: PText.priceXl(color: low ? PColors.rojo : PColors.tinta)),
              Text(item.unit.label, style: PText.label(color: low ? PColors.rojo : PColors.gris, weight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
