import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Detalle de una cuenta: rondas, quitar productos, juntar, cancelar y cobrar.
class CuentaDetalleScreen extends StatelessWidget {
  const CuentaDetalleScreen({super.key, required this.orderId});

  final String orderId;

  static const _cancelReasons = ['Cliente se retiró', 'Pedido duplicado', 'Error de captura'];
  static const _voidReasons = ['Ya no lo quiso', 'Error de captura', 'Se acabó'];

  Future<void> _editCustomer(BuildContext context, Order order) async {
    final name = await askText(context, title: 'Nombre del cliente', initial: order.customer, hint: 'Nombre');
    if (name == null || !context.mounted) return;
    await runGuarded(context, () => StoreScope.read(context).updateOrderHeader(order, customer: name));
  }

  Future<void> _merge(BuildContext context, Order order) async {
    final store = StoreScope.read(context);
    final others = store.openOrders.where((o) => o.id != order.id).toList();
    if (others.isEmpty) {
      showInfoSnack(context, 'No hay otra cuenta abierta para juntar');
      return;
    }
    final source = await showModalBottomSheet<Order>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Juntar con ${order.folio}', style: PText.headlineMd()),
            Text('Los productos de la cuenta elegida pasan a ${order.folio}.', style: PText.bodyMd(color: PColors.gris)),
            const SizedBox(height: 12),
            for (final o in others)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: StatusPill(o.folio, background: PColors.moradoSuave, foreground: PColors.morado),
                title: Text(o.customer, style: PText.bodyLg(weight: FontWeight.w700)),
                subtitle: Text('${o.itemCount} productos · ${formatMoney(o.subtotalCents)}'),
                onTap: () => Navigator.pop(ctx, o),
              ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    await runGuarded(context, () => store.mergeOrders(target: order, source: source),
        success: '${source.folio} se juntó con ${order.folio}');
  }

  Future<void> _cancel(BuildContext context, Order order) async {
    final reason = await askText(context,
        title: 'Cancelar ${order.folio}',
        hint: 'Motivo de la cancelación',
        confirmLabel: 'Cancelar cuenta',
        suggestions: _cancelReasons);
    if (reason == null || !context.mounted) return;
    final ok = await runGuarded(context, () => StoreScope.read(context).cancelOrder(order, reason),
        success: 'Cuenta ${order.folio} cancelada');
    if (ok && context.mounted) context.go(Routes.cuentas);
  }

  Future<void> _void(BuildContext context, Order order, OrderLine line) async {
    final reason = await askText(context,
        title: 'Quitar ${line.qty}× ${line.name}',
        hint: 'Motivo',
        confirmLabel: 'Quitar',
        suggestions: _voidReasons);
    if (reason == null || !context.mounted) return;
    await runGuarded(context, () => StoreScope.read(context).voidLine(order, line, reason),
        success: '${line.name} quitado de la cuenta');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final order = store.orderById(orderId);
    if (order == null) {
      return Scaffold(
        appBar: const PiolinAppBar(title: 'Cuenta', showBack: true, showSync: false),
        body: Center(child: Text('La cuenta ya no está disponible', style: PText.bodyLg())),
      );
    }
    final open = order.isOpen;
    final q = open ? store.quote(order) : null;

    return Scaffold(
      appBar: PiolinAppBar(
        title: 'Cuenta ${order.folio}',
        subtitle: '${order.customer} · ${formatTime(order.createdAt)}',
        showBack: true,
        showSync: false,
        showLogo: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusPill(_statusLabel(order.status),
                      background: open ? PColors.amarillo : PColors.beigeOscuro, foreground: PColors.tinta),
                  const Spacer(),
                  if (open)
                    TextButton.icon(
                      onPressed: () => _editCustomer(context, order),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Cliente'),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(order.customer, style: PText.headlineMd()),
                const SizedBox(height: 12),
                Text('Destino', style: PText.label()),
                const SizedBox(height: 4),
                SegmentedButton<OrderDestination>(
                  segments: [
                    for (final d in OrderDestination.values)
                      ButtonSegment(value: d, label: Text(d.pill), icon: Icon(d.icon)),
                  ],
                  selected: {order.destination},
                  onSelectionChanged: open
                      ? (s) => runGuarded(context, () => store.updateOrderHeader(order, destination: s.first))
                      : null,
                ),
                const SizedBox(height: 12),
                Text('Canal', style: PText.label()),
                const SizedBox(height: 4),
                SegmentedButton<OrderChannel>(
                  segments: [
                    for (final c in OrderChannel.values)
                      ButtonSegment(value: c, label: Text(c.label), icon: Icon(c.icon)),
                  ],
                  selected: {order.channel},
                  onSelectionChanged: open
                      ? (s) => runGuarded(context, () => store.updateOrderHeader(order, channel: s.first))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final round in order.rounds) ...[
            _RoundCard(
              round: round,
              lines: order.lines.where((l) => l.roundId == round.id).toList(),
              onVoid: open ? (l) => _void(context, order, l) : null,
            ),
            const SizedBox(height: 12),
          ],
          if (order.lines.isEmpty)
            const EmptyState(icon: Icons.remove_shopping_cart, title: 'Sin productos'),
          const SizedBox(height: 4),
          PCard(
            child: Column(
              children: [
                _Amount('Subtotal', order.subtotalCents),
                if (open && q != null) ...[
                  for (final a in q.appliedPromotions)
                    _Amount('Promo: ${a.name}', -a.discountCents, color: PColors.verde),
                  const Divider(height: 20),
                  _Amount('Total estimado', q.totalCents, bold: true),
                ] else ...[
                  for (final a in order.appliedPromotions)
                    _Amount('Promo: ${a.name}', -a.discountCents, color: PColors.verde),
                  if (order.discountCents > 0)
                    _Amount('Descuento ${(order.discountBp / 100).toStringAsFixed(0)}% · ${order.discountReason ?? ''}',
                        -order.discountCents,
                        color: PColors.verde),
                  const Divider(height: 20),
                  _Amount('Total cobrado', order.totalCents, bold: true),
                  for (final p in order.payments)
                    _Amount(
                        '${p.method.label}${p.reference != null ? ' · ${p.reference}' : ''}'
                        '${p.changeCents != null && p.changeCents! > 0 ? ' (cambio ${formatMoney(p.changeCents!)})' : ''}',
                        p.amountCents,
                        color: PColors.gris),
                ],
              ],
            ),
          ),
          if (order.status == OrderStatus.cancelada)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Cancelada: ${order.cancelReason ?? ''}', style: PText.bodyMd(color: PColors.rojo)),
            ),
          if (open) ...[
            const SizedBox(height: 20),
            PButton(
              label: 'Cobrar',
              icon: Icons.point_of_sale,
              height: 60,
              onPressed: order.lines.isEmpty ? null : () => context.push(Routes.cobrar(order.id)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: PButton(
                  label: 'Agregar productos',
                  icon: Icons.add,
                  variant: PButtonVariant.soft,
                  onPressed: () {
                    store.startAddingTo(order);
                    context.go(Routes.menu);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PButton(
                  label: 'Juntar cuenta',
                  icon: Icons.merge_type,
                  variant: PButtonVariant.ghost,
                  onPressed: () => _merge(context, order),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _cancel(context, order),
              icon: const Icon(Icons.cancel_outlined, color: PColors.rojo),
              label: Text('Cancelar cuenta', style: PText.bodyMd(color: PColors.rojo, weight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.abierta => 'Abierta',
        OrderStatus.cobrada => 'Cobrada',
        OrderStatus.cancelada => 'Cancelada',
        OrderStatus.fusionada => 'Juntada con otra cuenta',
      };
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.round, required this.lines, this.onVoid});

  final OrderRound round;
  final List<OrderLine> lines;
  final ValueChanged<OrderLine>? onVoid;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ronda ${round.roundNo}', style: PText.sectionHeader()),
              const SizedBox(width: 8),
              Text(formatTime(round.createdAt), style: PText.label()),
              const Spacer(),
              if (round.printStatus != PrintStatus.impresa)
                const StatusPill('Impresión pendiente', icon: Icons.print_disabled, background: PColors.beige),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty) Text('Sin productos activos', style: PText.bodyMd(color: PColors.gris)),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('${l.qty}×', style: PText.bodyLg(color: PColors.morado, weight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: PText.bodyLg(weight: FontWeight.w600)),
                        if (l.modifiers.isNotEmpty) Text(l.modifiersLabel, style: PText.bodyMd(color: PColors.morado)),
                        if (l.note.isNotEmpty) Text('Nota: ${l.note}', style: PText.bodyMd(color: PColors.gris)),
                      ],
                    ),
                  ),
                  Text(formatMoney(l.subtotalCents), style: PText.priceSm()),
                  if (onVoid != null)
                    IconButton(
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, color: PColors.rojo),
                      onPressed: () => onVoid!(l),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.cents, {this.color = PColors.tinta, this.bold = false});

  final String label;
  final int cents;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: bold ? PText.bodyLg(color: color, weight: FontWeight.w700) : PText.bodyMd(color: color)),
          ),
          Text(formatMoney(cents), style: bold ? PText.priceLg(color: color) : PText.priceSm(color: color)),
        ],
      ),
    );
  }
}
