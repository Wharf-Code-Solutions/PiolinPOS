import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/error_log.dart';
import '../../data/pos_store.dart';
import '../../services/report_export.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Ajustes y administración.
class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final store = StoreScope.read(context);
    final name = await askText(context, title: 'Nombre del negocio', initial: store.businessName, maxLength: 40);
    if (name == null || !context.mounted) return;
    await runGuarded(context, () => store.setSetting('business_name', name), success: 'Nombre actualizado');
  }

  Future<void> _exportLog(BuildContext context) async {
    final file = ErrorLog.file;
    if (file == null || !await file.exists() || await file.length() == 0) {
      if (context.mounted) showInfoSnack(context, 'No hay errores registrados', icon: Icons.check_circle);
      return;
    }
    if (!context.mounted) return;
    await runGuarded(context, () => ReportExport.shareFiles([file], subject: 'Registro de errores PiolinPOS'));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final backupAccount = store.settings['backup_account'] ?? '';
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Ajustes', showBack: true, showSync: false, showAdmin: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PCard(
            onTap: () => _editName(context),
            child: Row(children: [
              const PiolinLogo(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.businessName, style: PText.headlineMd()),
                    Text('Toca para cambiar el nombre', style: PText.label()),
                  ],
                ),
              ),
              const Icon(Icons.edit, color: PColors.gris),
            ]),
          ),
          const SizedBox(height: 16),
          const SectionHeader('Operación', color: PColors.gris),
          _Tile(icon: Icons.point_of_sale, title: 'Turno y corte de caja', subtitle: store.hasOpenShift ? 'Turno abierto' : 'Sin turno abierto', onTap: () => context.push(Routes.turno)),
          _Tile(icon: Icons.price_change, title: 'Menú y precios', subtitle: 'Productos, categorías, modificadores y promociones', onTap: () => context.push(Routes.catalogo)),
          _Tile(icon: Icons.receipt_long, title: 'Gastos y compras', subtitle: 'Últimos 31 días', onTap: () => context.push(Routes.gastos)),
          _Tile(icon: Icons.label, title: 'Categorías de gasto', subtitle: 'Insumos, operativos e imprevistos; % de merma', onTap: () => context.push(Routes.categoriasGasto)),
          const SizedBox(height: 12),
          const SectionHeader('Datos', color: PColors.gris),
          _Tile(
            icon: Icons.cloud_upload,
            title: 'Respaldo en Google Drive',
            subtitle: backupAccount.isEmpty ? 'Sin cuenta conectada' : backupAccount,
            onTap: () => context.push(Routes.respaldo),
          ),
          const _Tile(
            icon: Icons.print_disabled,
            title: 'Impresora Bluetooth',
            subtitle: 'En espera · las comandas se guardan con impresión pendiente',
          ),
          const SizedBox(height: 12),
          const SectionHeader('Soporte', color: PColors.gris),
          _Tile(icon: Icons.bug_report, title: 'Exportar registro de errores', subtitle: 'Para enviarlo a soporte', onTap: () => _exportLog(context)),
          _Tile(icon: Icons.info_outline, title: 'Acerca de', subtitle: 'Versión y contacto', onTap: () => context.push(Routes.acerca)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: true,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: onTap == null ? PColors.beigeOscuro : PColors.moradoSuave, borderRadius: PRadius.cardBr),
        child: Icon(icon, color: onTap == null ? PColors.gris : PColors.morado),
      ),
      title: Text(title, style: PText.bodyLg(weight: FontWeight.w700, color: onTap == null ? PColors.gris : PColors.tinta)),
      subtitle: Text(subtitle, style: PText.bodyMd(color: PColors.gris)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: PColors.gris),
      onTap: onTap,
    );
  }
}
