import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

enum _PayMode { efectivo, transferencia, mixto }

/// Cobro y liquidación: promociones, descuento con motivo (R3) y pago mixto (R5).
class CobrarScreen extends StatefulWidget {
  const CobrarScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends State<CobrarScreen> {
  static const _quickDiscounts = [0, 5, 10];
  static const _reasons = ['Cliente frecuente', 'Cliente especial', 'Cortesía', 'Compensación'];

  int _discountPct = 0;
  _PayMode _mode = _PayMode.efectivo;
  final _received = TextEditingController();
  final _transfer = TextEditingController();
  final _reference = TextEditingController();
  final _reason = TextEditingController();
  bool _paying = false;

  @override
  void dispose() {
    for (final c in [_received, _transfer, _reference, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setReceived(int cents) {
    _received.text = (cents ~/ 100).toString();
    setState(() {});
  }

  List<(String, int)> _suggestions(int total) {
    if (total <= 0) return [('Exacto', 0)];
    int roundUp(int value, int step) => ((value + step - 1) ~/ step) * step;
    var a = roundUp(total + 1, 10000); // siguiente múltiplo de $100
    var b = roundUp(total + 1, 50000); // siguiente múltiplo de $500
    if (b <= a) b = a + 50000;
    if (a == total) a += 10000;
    return [('Exacto', total), (formatMoneyShort(a), a), (formatMoneyShort(b), b)];
  }

  Future<void> _customDiscount() async {
    final ctrl = TextEditingController(text: _discountPct > 0 && !_quickDiscounts.contains(_discountPct) ? '$_discountPct' : '');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Descuento personalizado', style: PText.headlineMd()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: '%', hintText: 'Ej. 15'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? 0;
              Navigator.pop(ctx, v > 100 ? 100 : v);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value != null) setState(() => _discountPct = value);
  }

  Future<void> _pay(Order order, int total) async {
    final transferCents = switch (_mode) {
      _PayMode.efectivo => 0,
      _PayMode.transferencia => total,
      _PayMode.mixto => parseMoney(_transfer.text) ?? 0,
    };
    final cashCents = total - transferCents;
    final received = parseMoney(_received.text) ?? cashCents;
    final now = DateTime.now();
    final reference = _reference.text.trim().isEmpty ? null : _reference.text.trim();
    final payments = <Payment>[
      if (cashCents > 0)
        Payment(
          id: newId(),
          method: PaymentMethod.efectivo,
          amountCents: cashCents,
          receivedCents: received,
          changeCents: received - cashCents,
          createdAt: now,
        ),
      if (transferCents > 0)
        Payment(
          id: newId(),
          method: PaymentMethod.transferencia,
          amountCents: transferCents,
          reference: reference,
          createdAt: now,
        ),
    ];
    setState(() => _paying = true);
    final store = StoreScope.read(context);
    final ok = await runGuarded(
      context,
      () => store.payOrder(order, payments: payments, discountBp: _discountPct * 100, discountReason: _reason.text),
    );
    if (!mounted) return;
    setState(() => _paying = false);
    if (!ok) return;
    showInfoSnack(context, 'Pago de ${formatMoney(total)} registrado · ${order.folio}', icon: Icons.done_all);
    context.go(Routes.cuentas);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final order = store.orderById(widget.orderId);

    if (order == null || !order.isOpen) {
      return Scaffold(
        appBar: const PiolinAppBar(title: 'Cobro', showBack: true, showSync: false),
        body: Center(child: Text('La cuenta ya no está disponible', style: PText.bodyLg())),
      );
    }

    final q = store.quote(order, discountBp: _discountPct * 100);
    final total = q.totalCents;
    final transferCents = _mode == _PayMode.mixto ? (parseMoney(_transfer.text) ?? 0) : 0;
    final cashDue = switch (_mode) {
      _PayMode.efectivo => total,
      _PayMode.transferencia => 0,
      _PayMode.mixto => total - transferCents,
    };
    final receivedCents = parseMoney(_received.text) ?? 0;
    final change = receivedCents - cashDue;
    final reasonOk = _discountPct == 0 || _reason.text.trim().isNotEmpty;
    final mixOk = _mode != _PayMode.mixto || (transferCents > 0 && transferCents < total);
    final cashOk = cashDue == 0 || receivedCents >= cashDue;
    final canPay = !_paying && reasonOk && mixOk && cashOk && total >= 0;

    return Scaffold(
      appBar: const PiolinAppBar(
        title: 'Cobro y Liquidación',
        showBack: true,
        showSync: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PCard(
            child: Column(
              children: [
                Row(children: [
                  StatusPill(order.folio, background: PColors.moradoSuave, foreground: PColors.morado),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${order.customer} · ${order.destination.pill}',
                        overflow: TextOverflow.ellipsis, style: PText.bodyMd(color: PColors.gris)),
                  ),
                ]),
                const SizedBox(height: 12),
                _AmountRow(label: 'Subtotal (${order.itemCount} productos)', cents: q.subtotalCents),
                for (final a in q.appliedPromotions)
                  _AmountRow(label: a.name, cents: -a.discountCents, icon: Icons.local_offer, color: PColors.verde),
                if (q.discountCents > 0)
                  _AmountRow(
                      label: 'Descuento ($_discountPct%)', cents: -q.discountCents, icon: Icons.loyalty, color: PColors.verde),
                const Divider(height: 24),
                Row(
                  children: [
                    Text('TOTAL A COBRAR', style: PText.sectionHeader(color: PColors.gris).copyWith(fontSize: 15)),
                    const Spacer(),
                    Text(formatMoney(total), style: PText.priceXl(color: PColors.moradoTinta)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Descuento'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: PColors.beige, borderRadius: PRadius.cardBr),
            child: Row(
              children: [
                for (final pct in _quickDiscounts)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _SelectBox(
                        selected: _discountPct == pct,
                        onTap: () => setState(() => _discountPct = pct),
                        child: Text(pct == 0 ? 'Sin desc.' : '$pct%',
                            textAlign: TextAlign.center,
                            style: PText.bodyMd(
                                color: _discountPct == pct ? PColors.morado : PColors.tinta,
                                weight: _discountPct == pct ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _SelectBox(
                      selected: !_quickDiscounts.contains(_discountPct),
                      onTap: _customDiscount,
                      child: Text(!_quickDiscounts.contains(_discountPct) ? '$_discountPct%' : 'Otro',
                          style: PText.bodyMd(weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_discountPct > 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Motivo del descuento (obligatorio)',
                errorText: reasonOk ? null : 'Indica el motivo',
              ),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in _reasons)
                ActionChip(label: Text(r), onPressed: () => setState(() => _reason.text = r)),
            ]),
          ],
          const SizedBox(height: 20),
          const SectionHeader('Forma de pago'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_PayMode>(
              segments: const [
                ButtonSegment(value: _PayMode.efectivo, label: Text('Efectivo'), icon: Icon(Icons.payments)),
                ButtonSegment(value: _PayMode.transferencia, label: Text('Transfer.'), icon: Icon(Icons.account_balance)),
                ButtonSegment(value: _PayMode.mixto, label: Text('Mixto'), icon: Icon(Icons.call_split)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_mode != _PayMode.efectivo)
            PCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.account_balance, color: PColors.azul),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mode == _PayMode.mixto
                            ? 'Monto que se paga por transferencia'
                            : 'Confirma la transferencia en la app del banco antes de registrar el pago.',
                        style: PText.bodyMd(),
                      ),
                    ),
                  ]),
                  if (_mode == _PayMode.mixto) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transfer,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                      style: PText.priceLg(),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0.00',
                        errorText: mixOk || _transfer.text.isEmpty ? null : 'Debe ser mayor a 0 y menor al total',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reference,
                    decoration: const InputDecoration(hintText: 'Referencia o últimos dígitos (opcional)'),
                  ),
                ],
              ),
            ),
          if (_mode != _PayMode.efectivo && cashDue > 0) const SizedBox(height: 12),
          if (cashDue > 0)
            PCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_mode == _PayMode.mixto ? 'EFECTIVO RECIBIDO · resta ${formatMoney(cashDue)}' : 'MONTO RECIBIDO',
                        style: PText.label(weight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _received,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                    style: PText.priceLg().copyWith(fontSize: 28),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text('\$', style: PText.priceLg(color: PColors.morado).copyWith(fontSize: 28)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      enabledBorder: OutlineInputBorder(borderRadius: PRadius.cardBr, borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Sugerencias rápidas', style: PText.bodyMd(color: PColors.gris)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (i, (label, cents)) in _suggestions(cashDue).indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _SelectBox(
                            height: 56,
                            filled: true,
                            selected: receivedCents == cents,
                            onTap: () => _setReceived(cents),
                            child: Text(label,
                                style: PText.priceSm(color: receivedCents == cents ? PColors.morado : PColors.tinta)
                                    .copyWith(fontSize: 20)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ChangeBox(changeCents: change, hasInput: _received.text.isNotEmpty),
                ],
              ),
            ),
          const SizedBox(height: 24),
          PButton(
            label: _paying ? 'Registrando…' : 'COBRAR Y REGISTRAR PAGO',
            icon: Icons.point_of_sale,
            height: 64,
            onPressed: canPay ? () => _pay(order, total) : null,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.cents, this.icon, this.color = PColors.tinta});

  final String label;
  final int cents;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
          Expanded(child: Text(label, style: PText.bodyLg(color: color, weight: FontWeight.w400))),
          Text(formatMoney(cents), style: PText.priceSm(color: color).copyWith(fontSize: 20)),
        ],
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.selected,
    required this.onTap,
    required this.child,
    this.height = 50,
    this.filled = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double height;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? PColors.moradoSuave : (filled ? PColors.beige : PColors.blanco);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: PRadius.cardBr,
        side: BorderSide(color: selected ? PColors.morado : Colors.transparent),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
        onTap: onTap,
        child: SizedBox(height: height, child: Center(child: child)),
      ),
    );
  }
}

class _ChangeBox extends StatelessWidget {
  const _ChangeBox({required this.changeCents, required this.hasInput});

  final int changeCents;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    final short = hasInput && changeCents < 0;
    final color = short ? PColors.rojo : PColors.verde;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PColors.beige,
        borderRadius: PRadius.cardBr,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(short ? 'FALTA POR RECIBIR' : 'CAMBIO A ENTREGAR', style: PText.label(color: PColors.tinta, weight: FontWeight.w700).copyWith(fontSize: 13)),
                Text(short ? 'Monto insuficiente' : 'Entregar en efectivo', style: PText.bodyMd()),
              ],
            ),
          ),
          Text(formatMoney(hasInput ? changeCents.abs() : 0), style: PText.priceLg(color: color).copyWith(fontSize: 28)),
        ],
      ),
    );
  }
}
