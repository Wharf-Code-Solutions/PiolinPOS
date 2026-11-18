import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../services/report_export.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Reportes — ventas, balance, productos, stock bajo y cierres mensuales (R8, R11, R15).
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  int _loadedRevision = -1;

  void _reloadIfNeeded(PosStore store) {
    // Solo recargar cuando la pestaña está visible.
    if (!TickerMode.valuesOf(context).enabled) return;
    if (store.loadingReports || store.revision == _loadedRevision) return;
    _loadedRevision = store.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await store.loadReports();
      // loadReports notifica dos veces; marcar la revisión resultante como cargada.
      _loadedRevision = store.revision;
    });
  }

  Future<void> _export(MonthlyClosure c) async {
    final store = StoreScope.read(context);
    await runGuarded(context, () async {
      final pdf = await ReportExport.closurePdf(c, businessName: store.businessName);
      final csv = await ReportExport.periodCsv(store, c.period);
      await ReportExport.shareFiles([pdf, csv], subject: 'Cierre ${periodLabel(c.period)} · ${store.businessName}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    _reloadIfNeeded(store);
    final r = store.reports;
    final now = DateTime.now();

    return Scaffold(
      appBar: const PiolinAppBar(title: 'El Piolín', subtitle: 'Reportes', pill: ShiftOpenPill()),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: store.loadReports,
              child: _ReportBody(report: r, now: now, onExport: _export, lowStock: store.lowStockItems),
            ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.now, required this.onExport, required this.lowStock});

  final ReportData report;
  final DateTime now;
  final ValueChanged<MonthlyClosure> onExport;
  final List<InventoryItem> lowStock;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final todayIndex = now.weekday - 1; // 0 = lunes
    final weekTotal = r.weekSales.take(todayIndex + 1).fold(0, (a, b) => a + b);
    final weekChange = r.weekChangePct;
    final sales = r.monthSalesCents;
    final expenses = r.monthExpensesCents;
    final profit = sales - expenses;
    final margin = sales == 0 ? 0 : (profit * 100 / sales).round();
    final supplies = r.monthSuppliesCents;
    final suppliesPct = sales == 0 ? 0 : (supplies * 100 / sales).round();
    final dishes = r.dishes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('CIERRE Y BALANCES', style: PText.sectionHeader(color: PColors.gris)),
        Text('${monthNames[now.month - 1]} ${now.year}', style: PText.displayMobile()),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                'Ventas de la semana',
                color: PColors.gris,
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: PColors.beige, shape: BoxShape.circle),
                  child: const Icon(Icons.payments, size: 20, color: PColors.morado),
                ),
              ),
              Row(
                children: [
                  Text(formatMoneyShort(weekTotal), style: PText.priceXl()),
                  if (weekChange != null) ...[
                    const SizedBox(width: 10),
                    StatusPill('${weekChange >= 0 ? '+' : ''}$weekChange%',
                        icon: weekChange >= 0 ? Icons.trending_up : Icons.trending_down,
                        background: weekChange >= 0 ? const Color(0xFFFFF3C4) : PColors.errorBg,
                        foreground: weekChange >= 0 ? PColors.amarilloTexto : PColors.rojo),
                  ],
                ],
              ),
              if (weekChange != null)
                Text('contra la semana pasada al mismo día', style: PText.label()),
              const SizedBox(height: 16),
              SizedBox(height: 220, child: _WeekBarChart(values: r.weekSales, todayIndex: todayIndex)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('Balance del mes', color: PColors.gris, trailing: Text('Margen: $margin%', style: PText.label())),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: PRadius.pill,
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      Expanded(flex: math.max(1, profit), child: Container(color: PColors.morado)),
                      Container(width: 2, color: PColors.blanco),
                      Expanded(flex: math.max(1, expenses), child: Container(color: const Color(0xFFE7C400))),
                    ],
                  ),
                ),
              ),
              const Divider(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Legend(
                      dot: PColors.morado,
                      title: 'Ganancia neta',
                      amount: formatMoneyShort(profit),
                      amountColor: profit >= 0 ? PColors.verde : PColors.rojo,
                      caption: 'Ventas ${formatMoneyShort(sales)} · ${r.monthOrders} cuentas',
                    ),
                  ),
                  Expanded(
                    child: _Legend(
                      dot: const Color(0xFFE7C400),
                      title: 'Gastos',
                      amount: formatMoneyShort(expenses),
                      amountColor: PColors.tinta,
                      caption: 'Insumos ${formatMoneyShort(supplies)} ($suppliesPct% de ventas)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Efectivo ${formatMoneyShort(r.monthCashCents)} · Transferencia ${formatMoneyShort(r.monthTransferCents)}'
                ' · Descuentos ${formatMoneyShort(r.monthDiscountsCents)}',
                style: PText.bodyMd(color: PColors.gris),
              ),
              for (final kind in ExpenseKind.values)
                if ((r.monthExpenses[kind] ?? 0) > 0)
                  Text('${kind.label}: ${formatMoney(r.monthExpenses[kind]!)}', style: PText.label()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            children: [
              const SectionHeader('Rendimiento de platillos',
                  color: PColors.gris, trailing: Icon(Icons.insights, color: PColors.gris)),
              const SizedBox(height: 12),
              if (dishes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin ventas este mes', style: PText.bodyMd(color: PColors.gris)),
                )
              else ...[
                for (var i = 0; i < math.min(5, dishes.length); i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _DishRow(
                    icon: i == 0 ? Icons.star : Icons.restaurant,
                    iconBg: i == 0 ? PColors.amarillo : PColors.beigeOscuro,
                    iconColor: PColors.tinta,
                    name: dishes[i].name,
                    tag: i == 0 ? 'Top' : '#${i + 1}',
                    tagBg: i == 0 ? PColors.moradoTinta : PColors.moradoSuave,
                    tagFg: i == 0 ? PColors.blanco : PColors.morado,
                    detail: '${dishes[i].qty} vendidos · ${formatMoneyShort(dishes[i].revenueCents)} generados',
                    trailing: Icons.local_fire_department,
                    trailingColor: i == 0 ? PColors.amarilloTexto : PColors.gris,
                  ),
                ],
                if (dishes.length > 5) ...[
                  const SizedBox(height: 10),
                  _DishRow(
                    icon: Icons.flag_outlined,
                    iconBg: PColors.errorBg,
                    iconColor: PColors.rojo,
                    name: dishes.last.name,
                    tag: 'Revisar',
                    tagBg: PColors.errorBg,
                    tagFg: PColors.rojo,
                    detail: 'Solo ${dishes.last.qty} vendidos este mes',
                    trailing: Icons.help_outline,
                    trailingColor: PColors.gris,
                    onTrailing: () => showInfoSnack(context, 'Platillo con menor rotación en el mes'),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader('Stock bajo (${lowStock.length})',
                  color: PColors.gris, trailing: const Icon(Icons.warning_amber, color: PColors.naranja)),
              const SizedBox(height: 8),
              if (lowStock.isEmpty)
                Text('Todo el inventario está arriba del mínimo', style: PText.bodyMd(color: PColors.gris)),
              for (final i in lowStock)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(i.name, style: PText.bodyMd(weight: FontWeight.w600))),
                    Text('${formatQty(i.stockMilli)} / mín ${formatQty(i.minStockMilli)} ${i.unit.short}',
                        style: PText.label(color: PColors.rojo, weight: FontWeight.w700)),
                  ]),
                ),
              if (lowStock.isNotEmpty)
                TextButton(onPressed: () => context.go(Routes.inventario), child: const Text('Ir a inventario')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader('Cierres mensuales (${r.closures.length})', color: PColors.gris),
        const SizedBox(height: 8),
        PCard(
          padding: r.closures.isEmpty ? const EdgeInsets.all(16) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.closures.isEmpty)
                Text('El mes se cierra solo a partir del día 4 del mes siguiente.', style: PText.bodyMd(color: PColors.gris)),
              for (var i = 0; i < r.closures.length; i++) ...[
                if (i > 0) const Divider(),
                _ReportTile(
                  title: periodLabel(r.closures[i].period),
                  detail: '${formatMoneyShort(r.closures[i].salesCents)} ventas · '
                      'utilidad ${formatMoneyShort(r.closures[i].netCents)} · ${r.closures[i].salesDays} días',
                  highlight: i == 0,
                  onDownload: () => onExport(r.closures[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PColors.beigeOscuro, borderRadius: PRadius.cardBr),
          child: Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: PColors.morado),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Los datos se guardan en el celular con respaldo semanal en Google Drive. '
                  'El ícono de descarga comparte el cierre en PDF y CSV.',
                  style: PText.bodyMd(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({required this.values, required this.todayIndex});

  final List<int> values;
  final int todayIndex;

  static const _labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(1, (a, b) => b > a ? b : a);
    return LayoutBuilder(builder: (context, c) {
      const labelHeight = 28.0;
      const badgeHeight = 28.0;
      final barArea = c.maxHeight - labelHeight - badgeHeight - 10;
      return Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: PColors.borde),
                  bottom: BorderSide(color: PColors.borde),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (i == todayIndex)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: PColors.rojo, borderRadius: PRadius.pill),
                              child: FittedBox(
                                child: Text('⚡ ${formatMoneyShort(values[i])}',
                                    style: PText.label(color: PColors.blanco, weight: FontWeight.w700)),
                              ),
                            ),
                          _Bar(
                            height: i > todayIndex
                                ? barArea * 0.45
                                : math.max(6.0, barArea * values[i] / maxValue),
                            color: i == todayIndex
                                ? PColors.rojo
                                : (i > todayIndex ? const Color(0xFFB9A8E0) : PColors.morado),
                            dashed: i > todayIndex,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: labelHeight,
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        i == todayIndex ? '${_labels[i]} (Hoy)' : _labels[i],
                        style: PText.label(
                          color: i == todayIndex ? PColors.rojo : PColors.gris,
                          weight: i == todayIndex ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color, this.dashed = false});

  final double height;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        border: dashed ? Border.all(color: PColors.morado.withValues(alpha: 0.5)) : null,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.dot,
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.caption,
  });

  final Color dot;
  final String title;
  final String amount;
  final Color amountColor;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(title, style: PText.bodyMd(weight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Text(amount, style: PText.priceLg(color: amountColor)),
        Text(caption, style: PText.label(weight: FontWeight.w400)),
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.name,
    required this.tag,
    required this.tagBg,
    required this.tagFg,
    required this.detail,
    required this.trailing,
    required this.trailingColor,
    this.onTrailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String name;
  final String tag;
  final Color tagBg;
  final Color tagFg;
  final String detail;
  final IconData trailing;
  final Color trailingColor;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: PColors.beige, borderRadius: PRadius.cardBr),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis, style: PText.bodyLg(weight: FontWeight.w700).copyWith(fontSize: 18)),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(tag, background: tagBg, foreground: tagFg),
                ]),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: PText.bodyMd(color: PColors.gris)),
              ],
            ),
          ),
          IconButton(onPressed: onTrailing, icon: Icon(trailing, color: trailingColor)),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.title, required this.detail, required this.highlight, required this.onDownload});

  final String title;
  final String detail;
  final bool highlight;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlight ? PColors.moradoSuave : PColors.beigeOscuro,
              borderRadius: PRadius.cardBr,
            ),
            child: Icon(Icons.description_outlined, color: highlight ? PColors.morado : PColors.gris),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PText.bodyLg(weight: FontWeight.w700)),
                Text(detail, style: PText.bodyMd(color: PColors.gris)),
              ],
            ),
          ),
          Material(
            color: PColors.beigeOscuro,
            borderRadius: PRadius.cardBr,
            child: InkWell(
              borderRadius: PRadius.cardBr,
              onTap: onDownload,
              child: const SizedBox(width: 48, height: 48, child: Icon(Icons.download, color: PColors.morado)),
            ),
          ),
        ],
      ),
    );
  }
}
