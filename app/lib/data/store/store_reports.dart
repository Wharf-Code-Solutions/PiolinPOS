part of '../pos_store.dart';

/// Datos de la pantalla de reportes, calculados en SQLite.
class ReportData {
  const ReportData({
    required this.weekStart,
    required this.weekSales,
    required this.weekChangePct,
    required this.monthSalesCents,
    required this.monthOrders,
    required this.monthDiscountsCents,
    required this.monthCashCents,
    required this.monthTransferCents,
    required this.monthExpenses,
    required this.dishes,
    required this.closures,
  });

  final DateTime weekStart;

  /// Ventas lunes..domingo de la semana en curso.
  final List<int> weekSales;

  /// Variación contra la semana anterior al mismo día; null sin base.
  final int? weekChangePct;
  final int monthSalesCents;
  final int monthOrders;
  final int monthDiscountsCents;
  final int monthCashCents;
  final int monthTransferCents;
  final Map<ExpenseKind, int> monthExpenses;

  /// Productos del mes, de más a menos vendidos.
  final List<DishStat> dishes;
  final List<MonthlyClosure> closures;

  int get monthExpensesCents => monthExpenses.values.fold(0, (a, b) => a + b);
  int get monthSuppliesCents => monthExpenses[ExpenseKind.supplies] ?? 0;
}

extension PosStoreReports on PosStore {
  Future<void> loadReports() async {
    loadingReports = true;
    _changed();
    try {
      await closeDueMonths();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final byDay = await repo.salesByDay(businessDate(weekStart), businessDate(weekEnd));
      final week = [
        for (var i = 0; i < 7; i++) byDay[businessDate(weekStart.add(Duration(days: i)))] ?? 0,
      ];
      final currentToDate = week.take(today.weekday).fold(0, (a, b) => a + b);
      final prevStart = weekStart.subtract(const Duration(days: 7));
      final prevByDay = await repo.salesByDay(
          businessDate(prevStart), businessDate(prevStart.add(Duration(days: today.weekday - 1))));
      final prevToDate = prevByDay.values.fold(0, (a, b) => a + b);

      final monthFrom = '${periodOf(now)}-01';
      final monthTo = '${periodOf(now)}-31';
      final summary = await repo.salesSummary(monthFrom, monthTo);
      reports = ReportData(
        weekStart: weekStart,
        weekSales: week,
        weekChangePct: prevToDate == 0 ? null : ((currentToDate - prevToDate) * 100 / prevToDate).round(),
        monthSalesCents: summary['sales']!,
        monthOrders: summary['orders']!,
        monthDiscountsCents: summary['discounts']!,
        monthCashCents: summary['cash']!,
        monthTransferCents: summary['transfer']!,
        monthExpenses: await repo.expensesByKind(monthFrom, monthTo),
        dishes: await repo.dishStats(monthFrom, monthTo),
        closures: await repo.loadClosures(),
      );
    } finally {
      loadingReports = false;
      _changed();
    }
  }

  /// R11: cierra los meses anteriores con 3 días de margen para capturar gastos tardíos.
  Future<void> closeDueMonths({int graceDays = 3}) async {
    final now = DateTime.now();
    final current = periodOf(now);
    final previous = periodOf(DateTime(now.year, now.month - 1));
    for (final period in await repo.periodsWithActivity()) {
      if (period.compareTo(current) >= 0) continue;
      if (period == previous && now.day <= graceDays) continue;
      await repo.closeMonth(period);
    }
  }
}
