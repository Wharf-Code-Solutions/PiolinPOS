import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/pos_store.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';
import 'compra_sheet.dart';
import 'gasto_imprevisto_sheet.dart';

/// Gastos y compras de los últimos 31 días (R15).
class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  Future<List<Expense>>? _future;
  int _version = -1;

  Future<List<Expense>> _load(PosStore store) {
    final from = businessDate(DateTime.now().subtract(const Duration(days: 31)));
    return store.repo.loadExpenses(fromDate: from);
  }

  Future<void> _delete(Expense e) async {
    final ok = await confirmDialog(context,
        title: 'Eliminar gasto',
        message: '¿Eliminar ${formatMoney(e.amountCents)} "${e.description}"? El inventario de una compra no se revierte; '
            'ajústalo desde el insumo si es necesario.',
        confirmLabel: 'Eliminar',
        destructive: true);
    if (!ok || !mounted) return;
    await runGuarded(context, () => StoreScope.read(context).deleteExpense(e), success: 'Gasto eliminado');
    if (mounted) setState(() => _future = _load(StoreScope.read(context)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Recargar cuando cambia el estado (nuevo gasto o compra).
    final version = store.revision;
    if (_future == null || version != _version) {
      _version = version;
      _future = _load(store);
    }
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Gastos y compras', showBack: true, showSync: false, showLogo: false),
      body: FutureBuilder<List<Expense>>(
        future: _future,
        builder: (context, snap) {
          final list = snap.data ?? const <Expense>[];
          final total = list.fold(0, (a, e) => a + e.amountCents);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                  child: PButton(
                    label: 'Gasto',
                    icon: Icons.add,
                    variant: PButtonVariant.soft,
                    onPressed: () => showGastoImprevistoSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PButton(
                    label: 'Compra',
                    icon: Icons.local_shipping,
                    variant: PButtonVariant.secondary,
                    onPressed: () => showCompraSheet(context),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SectionHeader('Últimos 31 días · ${formatMoney(total)}', color: PColors.gris),
              const SizedBox(height: 8),
              if (snap.connectionState != ConnectionState.done)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const EmptyState(icon: Icons.receipt_long, title: 'Sin gastos registrados'),
              for (final e in list)
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
                              Text(
                                e.description.isEmpty ? (store.expenseCategoryById(e.categoryId)?.name ?? 'Gasto') : e.description,
                                style: PText.bodyLg(weight: FontWeight.w700),
                              ),
                              Text(
                                '${store.expenseCategoryById(e.categoryId)?.name ?? ''} · ${e.method.label}'
                                '${e.paidFromRegister ? ' · de caja' : ''} · ${formatDateTime(e.createdAt)}',
                                style: PText.bodyMd(color: PColors.gris),
                              ),
                            ],
                          ),
                        ),
                        Text(formatMoney(e.amountCents), style: PText.priceSm()),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline, color: PColors.gris),
                          onPressed: () => _delete(e),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
