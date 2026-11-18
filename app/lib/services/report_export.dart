import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../core/error_log.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../data/pos_store.dart';

/// Exporta cierres mensuales (R11) a PDF y CSV y los comparte.
abstract final class ReportExport {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'reportes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> closurePdf(MonthlyClosure c, {required String businessName}) async {
    final doc = pw.Document(title: 'Cierre ${periodLabel(c.period)}', author: businessName);
    final margin = c.salesCents == 0 ? 0 : (c.netCents * 100 / c.salesCents).round();

    pw.Widget row(String label, int cents, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null))),
            pw.Text(formatMoney(cents), style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
          ]),
        );

    final days = c.dailySales.keys.toList()..sort();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Text(businessName, style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('Cierre mensual · ${periodLabel(c.period)}', style: const pw.TextStyle(fontSize: 14)),
        pw.Text('Generado: ${formatDateTime(c.closedAt)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, text: 'Ventas'),
        row('Ventas cobradas (${c.ordersCount} cuentas, ${c.salesDays} días)', c.salesCents, bold: true),
        row('  Efectivo', c.cashSalesCents),
        row('  Transferencia', c.transferSalesCents),
        row('Descuentos y promociones otorgados', c.discountsCents),
        pw.SizedBox(height: 10),
        pw.Header(level: 1, text: 'Gastos'),
        row('Insumos', c.suppliesExpenseCents),
        row('Operativos', c.operatingExpenseCents),
        row('Imprevistos', c.unforeseenExpenseCents),
        row('Total de gastos', c.totalExpensesCents, bold: true),
        pw.SizedBox(height: 10),
        pw.Header(level: 1, text: 'Resultado'),
        row('Utilidad (ventas - gastos)', c.netCents, bold: true),
        pw.Text('Margen: $margin %'),
        pw.SizedBox(height: 10),
        pw.Header(level: 1, text: 'Productos más vendidos'),
        if (c.topProducts.isEmpty) pw.Text('Sin ventas'),
        if (c.topProducts.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Producto', 'Piezas', 'Ingreso'],
            data: [for (final d in c.topProducts) [d.name, '${d.qty}', formatMoney(d.revenueCents)]],
            cellAlignment: pw.Alignment.centerLeft,
          ),
        pw.SizedBox(height: 10),
        pw.Header(level: 1, text: 'Ventas por día'),
        if (days.isEmpty) pw.Text('Sin ventas'),
        if (days.isNotEmpty)
          pw.TableHelper.fromTextArray(
            headers: ['Día', 'Ventas'],
            data: [for (final d in days) [formatShortDate(parseBusinessDate(d)), formatMoney(c.dailySales[d]!)]],
          ),
      ],
    ));
    final file = File(p.join((await _dir()).path, 'cierre_${c.period}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static Future<File> periodCsv(PosStore store, String period) async {
    final rows = await store.repo.paidOrdersForExport(period);
    String money(Object? v) => ((v as int? ?? 0) / 100).toStringAsFixed(2);
    final data = <List<Object?>>[
      ['fecha', 'folio', 'cliente', 'canal', 'destino', 'subtotal', 'promociones', 'descuento', 'motivo_descuento', 'total', 'pagos', 'cobrado_en'],
      for (final r in rows)
        [
          r['business_date'],
          'A-${(r['folio'] as int).toString().padLeft(3, '0')}',
          r['customer_name'],
          r['channel'],
          r['dining_option'],
          money(r['subtotal_cents']),
          money(r['promo_discount_cents']),
          money(r['discount_cents']),
          r['discount_reason'] ?? '',
          money(r['total_cents']),
          r['pagos'] ?? '',
          r['paid_at'] == null ? '' : formatDateTime(fromIso(r['paid_at'] as String)),
        ],
    ];
    final file = File(p.join((await _dir()).path, 'ventas_$period.csv'));
    // BOM para que Excel respete los acentos.
    await file.writeAsString('﻿${const ListToCsvConverter().convert(data)}');
    return file;
  }

  static Future<void> shareFiles(List<File> files, {required String subject}) async {
    try {
      await Share.shareXFiles([for (final f in files) XFile(f.path)], subject: subject);
    } catch (e, s) {
      ErrorLog.record(e, s, context: 'Compartir');
      rethrow;
    }
  }
}
