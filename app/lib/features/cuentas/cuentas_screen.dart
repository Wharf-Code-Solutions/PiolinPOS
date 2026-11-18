import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/piolin_app_bar.dart';

/// Cuentas abiertas y cobradas del turno.
class CuentasScreen extends StatelessWidget {
  const CuentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final open = store.openOrders;
    final paid = store.paidOrders;

    return Scaffold(
      appBar: const PiolinAppBar(title: 'El Piolín', subtitle: 'Cuentas', pill: ShiftOpenPill()),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-nuevo-pedido',
        backgroundColor: PColors.rojo,
        foregroundColor: PColors.blanco,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
        onPressed: () {
          if (!store.hasOpenShift) {
            context.push(Routes.turno);
            return;
          }
          if (store.cartTargetOrderId != null) store.clearCart();
          context.go(Routes.menu);
        },
        icon: const Icon(Icons.add),
        label: Text('Nuevo pedido', style: PText.button()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _ShiftSummary(
            hasShift: store.hasOpenShift,
            openCount: open.length,
            paidCents: store.todayPaidCents,
            paidCount: paid.length,
          ),
          const SizedBox(height: 20),
          SectionHeader(
            'Cuentas abiertas (${open.length})',
            trailing: Text('Toca para ver detalle', style: PText.label()),
          ),
          const SizedBox(height: 12),
          if (open.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long,
              title: 'Sin cuentas abiertas',
              message: 'Crea un pedido con el botón rojo',
            )
          else
            for (final o in open) ...[
              _OpenOrderCard(order: o),
              const SizedBox(height: 12),
            ],
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionHeader('Cobradas en el turno (${paid.length})', color: PColors.gris),
            const SizedBox(height: 12),
            for (final o in paid) ...[
              _PaidOrderTile(order: o),
              const SizedBox(height: 8),
            ],
          ],
          if (store.cancelledOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${store.cancelledOrders.length} cuenta(s) cancelada(s) en el turno',
                style: PText.label(color: PColors.gris)),
          ],
        ],
      ),
    );
  }
}

class _ShiftSummary extends StatelessWidget {
  const _ShiftSummary({required this.hasShift, required this.openCount, required this.paidCents, required this.paidCount});

  final bool hasShift;
  final int openCount;
  final int paidCents;
  final int paidCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PColors.morado,
      borderRadius: PRadius.cardBr,
      child: InkWell(
        borderRadius: PRadius.cardBr,
        onTap: () => context.push(Routes.turno),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasShift ? 'VENDIDO EN EL TURNO' : 'TURNO CERRADO',
                        style: PText.label(color: PColors.moradoSuave)),
                    const SizedBox(height: 4),
                    Text(formatMoney(paidCents), style: PText.priceLg(color: PColors.amarillo)),
                    Text(hasShift ? '$paidCount cuentas cobradas · ver corte' : 'Toca para abrir el turno',
                        style: PText.bodyMd(color: PColors.moradoSuave)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: PColors.moradoProfundo, borderRadius: PRadius.cardBr),
                child: Column(
                  children: [
                    Text('$openCount', style: PText.priceLg(color: PColors.blanco)),
                    Text('abiertas', style: PText.label(color: PColors.moradoSuave)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenOrderCard extends StatelessWidget {
  const _OpenOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final minutes = DateTime.now().difference(order.createdAt).inMinutes;
    final summary = order.lines.map((l) => '${l.qty}× ${l.name}').join(' · ');
    return PCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(Routes.cuenta(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(order.folio, background: PColors.moradoSuave, foreground: PColors.morado),
              const SizedBox(width: 8),
              StatusPill(
                order.destination.pill,
                icon: order.destination.icon,
                background: order.destination == OrderDestination.local ? PColors.amarillo : PColors.beige,
              ),
              if (order.channel == OrderChannel.whatsapp) ...[
                const SizedBox(width: 6),
                const StatusPill('WhatsApp', icon: Icons.chat, background: Color(0xFFDDF5E4), foreground: PColors.verde),
              ],
              const Spacer(),
              Icon(Icons.schedule, size: 16, color: minutes >= 20 ? PColors.naranja : PColors.gris),
              const SizedBox(width: 4),
              Text(minutes < 60 ? 'hace $minutes min' : formatTime(order.createdAt),
                  style: PText.label(color: minutes >= 20 ? PColors.naranja : PColors.gris)),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.customer, style: PText.bodyLg(weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: PText.bodyMd(color: PColors.gris)),
          if (order.rounds.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${order.rounds.length} rondas', style: PText.label(color: PColors.morado)),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Text('${order.itemCount} prod.', style: PText.label()),
              const SizedBox(width: 8),
              Text(formatMoney(order.subtotalCents), style: PText.priceSm(color: PColors.morado)),
              const Spacer(),
              PButton(
                label: 'Agregar',
                icon: Icons.add,
                height: 40,
                expand: false,
                variant: PButtonVariant.soft,
                onPressed: () {
                  store.startAddingTo(order);
                  context.go(Routes.menu);
                },
              ),
              const SizedBox(width: 8),
              PButton(
                label: 'Cobrar',
                icon: Icons.point_of_sale,
                height: 40,
                expand: false,
                onPressed: () => context.push(Routes.cobrar(order.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaidOrderTile extends StatelessWidget {
  const _PaidOrderTile({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return PCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => context.push(Routes.cuenta(order.id)),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: PColors.verde, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${order.folio} · ${order.customer}',
                style: PText.bodyMd(weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          Icon(order.isMixedPayment ? Icons.call_split : (order.paymentMethod?.icon ?? Icons.payments),
              size: 16, color: PColors.gris),
          const SizedBox(width: 8),
          Text(formatMoney(order.totalCents), style: PText.priceSm(color: PColors.verde)),
        ],
      ),
    );
  }
}
