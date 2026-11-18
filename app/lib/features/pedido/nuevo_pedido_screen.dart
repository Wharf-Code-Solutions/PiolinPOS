import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/barcode_scanner.dart';
import '../../widgets/common.dart';
import '../../widgets/piolin_app_bar.dart';
import 'modificadores_sheet.dart';

/// Nuevo pedido — selección de platillos, modificadores y notas (paso 1 de 2).
class NuevoPedidoScreen extends StatefulWidget {
  const NuevoPedidoScreen({super.key});

  @override
  State<NuevoPedidoScreen> createState() => _NuevoPedidoScreenState();
}

class _NuevoPedidoScreenState extends State<NuevoPedidoScreen> {
  String? _categoryId;
  final TextEditingController _customer = TextEditingController();
  final FocusNode _customerFocus = FocusNode();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mantener el campo alineado con el carrito (p. ej. vacío tras enviar el pedido).
    final name = StoreScope.of(context).customerName;
    if (name != _customer.text && !_customerFocus.hasFocus) {
      _customer.text = name;
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _customerFocus.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final store = StoreScope.read(context);
    final code = await scanBarcode(context, title: 'Vender por código');
    if (code == null || !mounted) return;
    final product = store.productByBarcode(code);
    if (product == null) {
      showInfoSnack(context, 'Ningún producto tiene el código $code', icon: Icons.qr_code);
      return;
    }
    if (!product.available) {
      showInfoSnack(context, '${product.name} está agotado', icon: Icons.block);
      return;
    }
    await addProduct(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final categories = store.menuCategories;
    final categoryId = categories.any((c) => c.id == _categoryId)
        ? _categoryId!
        : (categories.isEmpty ? '' : categories.first.id);
    final products = store.productsIn(categoryId);
    final target = store.cartTargetOrder;

    return Scaffold(
      appBar: PiolinAppBar(
        title: target == null ? 'Nuevo Pedido' : 'Agregar a ${target.folio}',
        subtitle: target == null ? 'Selección de platillos y notas' : 'Ronda nueva para ${target.customer}',
        pill: const StatusPill('PASO 1 DE 2'),
        showSync: false,
        actions: [
          IconButton(
            tooltip: 'Vender por código de barras',
            icon: const Icon(Icons.qr_code_scanner, color: PColors.blanco),
            onPressed: _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (target != null)
            Material(
              color: PColors.amarillo,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.playlist_add, color: PColors.tinta),
                title: Text('Agregando productos a ${target.folio} · ${target.customer}',
                    style: PText.bodyMd(weight: FontWeight.w700)),
                trailing: TextButton(
                  onPressed: () {
                    store.stopAddingTo();
                    store.clearCart();
                  },
                  child: const Text('Cuenta nueva'),
                ),
              ),
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  sliver: SliverList.list(children: [
                    _CustomerCard(controller: _customer, focusNode: _customerFocus, onChanged: store.setCustomerName),
                  ]),
                ),
                SliverToBoxAdapter(
                  child: ChipRow(children: [
                    for (final c in categories)
                      CategoryChip(
                        label: c.name,
                        icon: c.id == categoryId ? c.icon : null,
                        selected: c.id == categoryId,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: products.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                store.activeProducts.isEmpty
                                    ? 'Aún no hay productos. Agrégalos en Ajustes › Menú y precios.'
                                    : 'No hay productos en esta categoría',
                                textAlign: TextAlign.center,
                                style: PText.bodyMd(color: PColors.gris)),
                          ),
                        )
                      : SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 204,
                          ),
                          itemCount: products.length,
                          itemBuilder: (_, i) => _ProductOrderCard(product: products[i]),
                        ),
                ),
              ],
            ),
          ),
          _CartSummaryBar(
            count: store.cartCount,
            customer: store.customerName,
            subtotalCents: store.cartSubtotalCents,
            onContinue: store.cartIsEmpty
                ? null
                : () {
                    if (!store.hasOpenShift) {
                      showInfoSnack(context, 'Abre el turno para mandar pedidos', icon: Icons.lock_clock);
                      return;
                    }
                    context.go(Routes.confirmar);
                  },
          ),
        ],
      ),
    );
  }
}

/// Agrega un producto al carrito, pidiendo modificadores si los tiene.
Future<void> addProduct(BuildContext context, Product product) async {
  final store = StoreScope.read(context);
  final groups = store.groupsFor(product);
  if (groups.isEmpty) {
    store.addToCart(product);
    return;
  }
  final mods = await showModifiersSheet(context, product: product, groups: groups);
  if (mods != null) store.addToCart(product, modifiers: mods);
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.controller, required this.focusNode, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.person_outline, size: 20, color: PColors.morado),
            const SizedBox(width: 8),
            Text('NOMBRE DEL CLIENTE', style: PText.label(color: PColors.morado, weight: FontWeight.w700)
                .copyWith(fontSize: 13, letterSpacing: 0.6)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.words,
            style: PText.bodyLg(),
            decoration: const InputDecoration(
              hintText: 'Nombre (opcional)',
              suffixIcon: Icon(Icons.edit, color: PColors.tinta),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductOrderCard extends StatelessWidget {
  const _ProductOrderCard({required this.product});

  final Product product;

  Future<void> _editNote(BuildContext context, CartLine? line) async {
    final store = StoreScope.read(context);
    if (line == null) {
      showInfoSnack(context, 'Agrega el producto antes de escribir la nota', icon: Icons.edit_note);
      return;
    }
    final controller = TextEditingController(text: line.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nota · ${product.name}', style: PText.headlineMd()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: product.notePlaceholder == 'Sabor' ? 'Ej. Coca, Sprite…' : 'Ej. Sin cebolla'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PColors.morado),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) store.setCartNote(line.key, result);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lines = store.cartLinesFor(product.id);
    final qty = store.cartQtyFor(product.id);
    final selected = qty > 0;
    final lastLine = lines.isEmpty ? null : lines.last;
    final note = lastLine?.note ?? '';
    final disabled = !product.available;
    final hasModifiers = product.modifierGroupIds.isNotEmpty;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: PRadius.cardBr,
          border: Border.all(color: selected ? PColors.morado : PColors.borde, width: selected ? 2 : 1),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF3EFFC), PColors.blanco],
                )
              : null,
          color: selected ? null : PColors.blanco,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: PRadius.cardBr,
            onTap: disabled ? null : () => addProduct(context, product),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PText.bodyLg(weight: FontWeight.w700)),
                      ),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: PColors.rojo, borderRadius: BorderRadius.circular(6)),
                          child: Text('$qty×', style: PText.label(color: PColors.blanco, weight: FontWeight.w800)),
                        ),
                      if (disabled) const StatusPill('Agotado', background: PColors.errorBg, foreground: PColors.rojo),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(formatMoney(product.priceCents),
                        style: PText.priceSm(color: selected ? PColors.morado : PColors.tinta).copyWith(fontSize: 17)),
                    if (hasModifiers) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.tune, size: 16, color: PColors.morado),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  _NoteButton(
                    note: lines.length > 1 ? '${lines.length} variantes' : (lastLine?.modifiersLabel.isNotEmpty ?? false)
                        ? '${lastLine!.modifiersLabel}${note.isEmpty ? '' : ' · $note'}'
                        : note,
                    placeholder: product.notePlaceholder,
                    onTap: disabled ? null : () => _editNote(context, lastLine),
                  ),
                  const Spacer(),
                  const Divider(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: selected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RoundIconButton(icon: Icons.remove, onPressed: () => store.removeFromCart(product)),
                              SizedBox(
                                width: 32,
                                child: Text('$qty',
                                    textAlign: TextAlign.center, style: PText.bodyLg(weight: FontWeight.w700)),
                              ),
                              RoundIconButton(
                                  icon: Icons.add, filled: true, onPressed: () => addProduct(context, product)),
                            ],
                          )
                        : RoundIconButton(icon: Icons.add, onPressed: disabled ? null : () => addProduct(context, product)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.note, required this.placeholder, required this.onTap});

  final String note;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasNote = note.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: hasNote ? PColors.beige : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasNote ? PColors.borde : const Color(0xFFD8CFB8)),
        ),
        child: Row(
          children: [
            Icon(hasNote ? Icons.comment : Icons.add_comment,
                size: 16, color: hasNote ? PColors.rojo : PColors.gris),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasNote ? note : '+ $placeholder',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PText.label(color: hasNote ? PColors.tinta : PColors.gris, weight: FontWeight.w500)
                    .copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  const _CartSummaryBar({
    required this.count,
    required this.customer,
    required this.subtotalCents,
    required this.onContinue,
  });

  final int count;
  final String customer;
  final int subtotalCents;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: PColors.blanco,
        border: Border(top: BorderSide(color: PColors.borde)),
        boxShadow: [BoxShadow(color: Color(0x1F1E1530), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: count > 0 ? PColors.rojo : PColors.gris, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('$count productos', style: PText.bodyMd(weight: FontWeight.w700)),
              Expanded(
                child: customer.trim().isEmpty
                    ? const SizedBox.shrink()
                    : Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '  ·  Cliente: '),
                          TextSpan(
                            text: customer.trim(),
                            style: PText.label(color: PColors.morado, weight: FontWeight.w700),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PText.label(),
                      ),
              ),
              const SizedBox(width: 8),
              Text('Subtotal: ', style: PText.bodyMd(color: PColors.gris)),
              Text(formatMoney(subtotalCents), style: PText.priceSm(color: PColors.morado).copyWith(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 10),
          PButton(
            label: 'Continuar a confirmar pedido',
            trailingIcon: Icons.arrow_forward,
            variant: PButtonVariant.secondary,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}
