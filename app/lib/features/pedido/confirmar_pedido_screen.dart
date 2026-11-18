import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Confirmar pedido — datos, canal y destino (paso 2 de 2).
class ConfirmarPedidoScreen extends StatefulWidget {
  const ConfirmarPedidoScreen({super.key});

  @override
  State<ConfirmarPedidoScreen> createState() => _ConfirmarPedidoScreenState();
}

class _ConfirmarPedidoScreenState extends State<ConfirmarPedidoScreen> {
  OrderDestination _destination = OrderDestination.local;
  OrderChannel _channel = OrderChannel.local;
  bool _sending = false;

  Future<void> _editCustomer() async {
    final store = StoreScope.read(context);
    final controller = TextEditingController(text: store.customerName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cliente', style: PText.headlineMd()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre del cliente'),
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
    if (result != null) store.setCustomerName(result);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final store = StoreScope.read(context);
    final adding = store.cartTargetOrder != null;
    Order? order;
    final ok = await runGuarded(context, () async {
      // La ronda se guarda antes de imprimir; la impresora está en espera.
      order = await store.submitOrder(destination: _destination, channel: _channel);
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok || order == null) return;
    showInfoSnack(
      context,
      adding ? 'Ronda agregada a ${order!.folio} · impresión pendiente' : 'Cuenta ${order!.folio} creada · impresión pendiente',
      icon: Icons.check_circle,
    );
    context.go(Routes.cuentas);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lines = store.cartLines;
    final customer = store.customerName.trim().isEmpty ? 'Mostrador' : store.customerName.trim();
    final target = store.cartTargetOrder;

    return Scaffold(
      appBar: const PiolinAppBar(title: 'El Piolín', subtitle: 'Menú', pill: ShiftOpenPill()),
      body: lines.isEmpty && !_sending
          ? _EmptyCart(onBack: () => context.go(Routes.menu))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: PColors.beige,
                      foregroundColor: PColors.morado,
                      shape: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
                    ),
                    onPressed: () => context.go(Routes.menu),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text('Volver a productos', style: PText.label(color: PColors.morado, weight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(target == null ? 'Confirmar Pedido' : 'Agregar a ${target.folio}', style: PText.displayMobile()),
                Text(target == null ? 'Paso 2: Datos y destino' : 'Se agregará como ronda nueva a la cuenta abierta',
                    style: PText.bodyLg(color: PColors.gris, weight: FontWeight.w400)),
                const SizedBox(height: 16),
                if (target == null) ...[
                PCard(
                  child: Column(
                    children: [
                      SectionHeader(
                        'Destino del pedido',
                        icon: Icons.place,
                        trailing: StatusPill(_destination.pill,
                            background: PColors.moradoSuave, foreground: PColors.morado),
                      ),
                      const SizedBox(height: 12),
                      _DestinationToggle(
                        value: _destination,
                        onChanged: (d) => setState(() => _destination = d),
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: Text('Canal', style: PText.label())),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<OrderChannel>(
                          segments: [
                            for (final c in OrderChannel.values)
                              ButtonSegment(value: c, label: Text(c.label), icon: Icon(c.icon)),
                          ],
                          selected: {_channel},
                          onSelectionChanged: (sel) => setState(() => _channel = sel.first),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ],
                PCard(
                  child: Column(
                    children: [
                      SectionHeader(
                        'Datos del cliente',
                        icon: Icons.person_outline,
                        trailing: TextButton.icon(
                          onPressed: _editCustomer,
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text('Modificar', style: PText.label(color: PColors.morado, weight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: PColors.beige, borderRadius: PRadius.cardBr),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: PColors.moradoSuave, shape: BoxShape.circle),
                              child: const Icon(Icons.badge, color: PColors.morado),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CLIENTE ASIGNADO', style: PText.label()),
                                  Text(customer, style: PText.bodyLg(weight: FontWeight.w700).copyWith(fontSize: 18)),
                                ],
                              ),
                            ),
                            const Icon(Icons.check, color: PColors.morado),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PCard(
                  child: Column(
                    children: [
                      SectionHeader(
                        'Resumen de comanda',
                        icon: Icons.receipt,
                        trailing: StatusPill('${store.cartCount} productos', background: PColors.beigeOscuro),
                      ),
                      const SizedBox(height: 12),
                      for (final l in lines) ...[
                        _SummaryLine(line: l),
                        const SizedBox(height: 10),
                      ],
                      const Divider(height: 16),
                      Row(
                        children: [
                          Text('Subtotal', style: PText.bodyLg()),
                          const Spacer(),
                          Text(formatMoney(store.cartSubtotalCents), style: PText.priceSm().copyWith(fontSize: 17)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: PColors.morado, borderRadius: PRadius.cardBr),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL DEL PEDIDO', style: PText.label(color: PColors.moradoSuave)),
                            Text('Monto a cobrar', style: PText.headlineLg(color: PColors.blanco)),
                          ],
                        ),
                      ),
                      Text(formatMoney(store.cartSubtotalCents), style: PText.priceXl(color: PColors.amarillo)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PButton(
                  label: _sending ? 'Guardando…' : (target == null ? 'Mandar a cocina' : 'Agregar ronda a ${target.folio}'),
                  icon: Icons.receipt_long,
                  height: 64,
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
    );
  }
}

class _DestinationToggle extends StatelessWidget {
  const _DestinationToggle({required this.value, required this.onChanged});

  final OrderDestination value;
  final ValueChanged<OrderDestination> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: PColors.beige, borderRadius: PRadius.cardBr),
      child: Row(
        children: [
          for (final d in OrderDestination.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  decoration: BoxDecoration(
                    color: d == value ? PColors.morado : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(d.icon, color: d == value ? PColors.blanco : PColors.tinta),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(d.label,
                            overflow: TextOverflow.ellipsis,
                            style: PText.bodyLg(
                                color: d == value ? PColors.blanco : PColors.tinta, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PColors.beige, borderRadius: PRadius.cardBr),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${line.qty}×', style: PText.bodyLg(color: PColors.morado, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(line.product.name,
                    overflow: TextOverflow.ellipsis, style: PText.bodyLg(weight: FontWeight.w600)),
              ),
              Text(formatMoney(line.subtotalCents), style: PText.priceSm().copyWith(fontSize: 17)),
            ],
          ),
          if (line.modifiers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(line.modifiersLabel, style: PText.bodyMd(color: PColors.morado)),
            ),
          if (line.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: PColors.blanco,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: PColors.morado, width: 3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2, size: 16, color: PColors.gris),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Nota: ', style: PText.bodyMd(weight: FontWeight.w700)),
                        TextSpan(text: '"${line.note}"'),
                      ]),
                      style: PText.bodyMd(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket, size: 48, color: PColors.gris),
            const SizedBox(height: 8),
            Text('El pedido está vacío', style: PText.headlineMd()),
            const SizedBox(height: 16),
            PButton(label: 'Agregar productos', variant: PButtonVariant.secondary, expand: false, onPressed: onBack),
          ],
        ),
      ),
    );
  }
}
