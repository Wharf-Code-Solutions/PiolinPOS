import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../domain/shift_cash.dart';
import '../../services/backup_service.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Turno del negocio: apertura con fondo, entradas/retiros y corte de caja.
class TurnoScreen extends StatelessWidget {
  const TurnoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final shift = store.openShift;
    return Scaffold(
      appBar: PiolinAppBar(
        title: 'Turno y caja',
        subtitle: shift == null ? 'Sin turno abierto' : 'Abierto ${formatDateTime(shift.openedAt)}',
        showBack: true,
        showSync: false,
        showLogo: false,
      ),
      body: shift == null ? const _OpenShiftView() : _OpenShiftSummary(shift: shift, summary: store.shiftSummary!),
    );
  }
}

class _OpenShiftView extends StatefulWidget {
  const _OpenShiftView();

  @override
  State<_OpenShiftView> createState() => _OpenShiftViewState();
}

class _OpenShiftViewState extends State<_OpenShiftView> {
  final _cash = TextEditingController();
  late final Future<List<Shift>> _recent = StoreScope.read(context).recentShifts();

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final cents = parseMoney(_cash.text) ?? 0;
    final store = StoreScope.read(context);
    await runGuarded(context, () => store.openNewShift(cents), success: 'Turno abierto con ${formatMoney(cents)} de fondo');
    if (mounted && store.hasOpenShift) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Abrir turno', style: PText.headlineLg()),
              const SizedBox(height: 4),
              Text('Cuenta el efectivo con el que inicia la caja (fondo para cambio).',
                  style: PText.bodyMd(color: PColors.gris)),
              const SizedBox(height: 16),
              TextField(
                controller: _cash,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: PText.priceLg(),
                decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00', labelText: 'Fondo inicial'),
              ),
              const SizedBox(height: 16),
              PButton(label: 'Abrir turno', icon: Icons.lock_open, onPressed: _open),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Turnos anteriores', color: PColors.gris),
        const SizedBox(height: 8),
        FutureBuilder<List<Shift>>(
          future: _recent,
          builder: (context, snap) {
            final list = snap.data ?? const <Shift>[];
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            if (list.isEmpty) {
              return Text('Aún no hay turnos cerrados', style: PText.bodyMd(color: PColors.gris));
            }
            return Column(
              children: [
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatShortDate(parseBusinessDate(s.businessDate)),
                                    style: PText.bodyLg(weight: FontWeight.w700)),
                                Text(
                                  '${formatTime(s.openedAt)} – ${s.closedAt == null ? '…' : formatTime(s.closedAt!)}'
                                  ' · esperado ${formatMoney(s.expectedCashCents ?? 0)}',
                                  style: PText.bodyMd(color: PColors.gris),
                                ),
                              ],
                            ),
                          ),
                          _DifferencePill(cents: s.differenceCents ?? 0),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OpenShiftSummary extends StatelessWidget {
  const _OpenShiftSummary({required this.shift, required this.summary});

  final Shift shift;
  final ShiftCashSummary summary;

  Future<void> _movement(BuildContext context, CashMovementType type) async {
    final store = StoreScope.read(context);
    final cents = await askMoney(context,
        title: type == CashMovementType.entrada ? 'Entrada de efectivo' : 'Retiro de efectivo',
        message: type == CashMovementType.entrada
            ? 'Dinero que se agrega a la caja (p. ej. más cambio).'
            : 'Dinero que sale de la caja y no es un gasto (p. ej. depósito al banco).');
    if (cents == null || !context.mounted) return;
    final reason = await askText(context,
        title: 'Motivo',
        hint: 'Motivo del movimiento',
        suggestions: type == CashMovementType.entrada
            ? const ['Más cambio', 'Préstamo']
            : const ['Depósito al banco', 'Retiro de la dueña']);
    if (reason == null || !context.mounted) return;
    await runGuarded(context, () => store.addCashMovement(type, cents, reason), success: 'Movimiento registrado');
  }

  Future<void> _close(BuildContext context) async {
    final store = StoreScope.read(context);
    final counted = await askMoney(context,
        title: 'Corte de caja', message: 'Cuenta el efectivo en la caja. Esperado: ${formatMoney(summary.expectedCashCents)}');
    if (counted == null || !context.mounted) return;
    final diff = counted - summary.expectedCashCents;
    final open = store.openOrders.length;
    final ok = await confirmDialog(
      context,
      title: 'Cerrar turno',
      message: 'Contado: ${formatMoney(counted)}\nEsperado: ${formatMoney(summary.expectedCashCents)}\n'
          'Diferencia: ${formatMoney(diff, showSign: true)}'
          '${open > 0 ? '\n\n$open cuenta(s) abierta(s) pasarán al siguiente turno.' : ''}',
      confirmLabel: 'Cerrar turno',
    );
    if (!ok || !context.mounted) return;
    String? notes;
    if (diff != 0) {
      notes = await askText(context,
          title: 'Nota del corte', hint: 'Explica la diferencia (opcional)', required: false, confirmLabel: 'Guardar');
      if (!context.mounted) return;
    }
    final closed = await runGuarded(context, () => store.closeCurrentShift(countedCashCents: counted, notes: notes),
        success: 'Turno cerrado · diferencia ${formatMoney(diff, showSign: true)}');
    if (closed) {
      // Respaldo tras el corte si hay cuenta de Google conectada.
      BackupService.instance.maybeAutoBackup(store, force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final movements = store.shiftMovements;
    final cashExpenses = store.shiftExpenses.where((e) => e.paidFromRegister && e.method == PaymentMethod.efectivo).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PColors.morado, borderRadius: PRadius.cardBr),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EFECTIVO ESPERADO EN CAJA', style: PText.label(color: PColors.moradoSuave)),
              Text(formatMoney(summary.expectedCashCents), style: PText.priceXl(color: PColors.amarillo)),
              const SizedBox(height: 4),
              Text('Ventas del turno: ${formatMoney(summary.totalSalesCents)} · ${summary.ordersCount} cuentas',
                  style: PText.bodyMd(color: PColors.moradoSuave)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            children: [
              _Line('Fondo inicial', summary.openingCashCents),
              _Line('Ventas en efectivo', summary.cashSalesCents),
              _Line('Gastos pagados de la caja', -summary.cashExpensesCents),
              _Line('Entradas de efectivo', summary.cashInCents),
              _Line('Retiros de efectivo', -summary.cashOutCents),
              const Divider(height: 20),
              _Line('Esperado en caja', summary.expectedCashCents, bold: true),
              const SizedBox(height: 8),
              _Line('Ventas por transferencia (no entran a caja)', summary.transferSalesCents, muted: true),
              if (summary.cancelledCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${summary.cancelledCount} cuenta(s) cancelada(s)', style: PText.label(color: PColors.rojo)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: PButton(
              label: 'Entrada',
              icon: Icons.add_circle_outline,
              variant: PButtonVariant.soft,
              onPressed: () => _movement(context, CashMovementType.entrada),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PButton(
              label: 'Retiro',
              icon: Icons.remove_circle_outline,
              variant: PButtonVariant.ghost,
              onPressed: () => _movement(context, CashMovementType.salida),
            ),
          ),
        ]),
        if (movements.isNotEmpty || cashExpenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Movimientos de caja', color: PColors.gris),
          const SizedBox(height: 8),
          for (final m in movements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(m.type == CashMovementType.entrada ? Icons.south_west : Icons.north_east,
                  color: m.type == CashMovementType.entrada ? PColors.verde : PColors.rojo),
              title: Text(m.reason),
              subtitle: Text(formatTime(m.createdAt)),
              trailing: Text(formatMoney(m.signedCents, showSign: true), style: PText.priceSm()),
            ),
          for (final e in cashExpenses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.receipt, color: PColors.naranja),
              title: Text(e.description.isEmpty ? (store.expenseCategoryById(e.categoryId)?.name ?? 'Gasto') : e.description),
              subtitle: Text('Gasto · ${formatTime(e.createdAt)}'),
              trailing: Text(formatMoney(-e.amountCents), style: PText.priceSm()),
            ),
        ],
        const SizedBox(height: 24),
        PButton(label: 'Hacer corte y cerrar turno', icon: Icons.lock, height: 60, onPressed: () => _close(context)),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.cents, {this.bold = false, this.muted = false});

  final String label;
  final int cents;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? PColors.gris : PColors.tinta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: bold ? PText.bodyLg(weight: FontWeight.w700) : PText.bodyMd(color: color)),
          ),
          Text(formatMoney(cents), style: bold ? PText.priceLg() : PText.priceSm(color: color)),
        ],
      ),
    );
  }
}

class _DifferencePill extends StatelessWidget {
  const _DifferencePill({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    if (cents == 0) return const StatusPill('Cuadró', background: Color(0xFFDDF5E4), foreground: PColors.verde);
    return StatusPill(
      formatMoney(cents, showSign: true),
      background: cents < 0 ? PColors.errorBg : PColors.offlineBg,
      foreground: cents < 0 ? PColors.rojo : PColors.amarilloTexto,
    );
  }
}
