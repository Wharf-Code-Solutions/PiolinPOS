import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/dates.dart';
import '../../core/error_log.dart';
import '../../data/pos_store.dart';
import '../../services/backup_service.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/piolin_app_bar.dart';

/// Respaldo de la base en Google Drive: conectar, respaldar ahora y restaurar.
class RespaldoScreen extends StatefulWidget {
  const RespaldoScreen({super.key});

  @override
  State<RespaldoScreen> createState() => _RespaldoScreenState();
}

class _RespaldoScreenState extends State<RespaldoScreen> {
  final _service = BackupService.instance;
  bool _busy = false;
  Future<List<DriveBackup>>? _backups;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _service.signInSilently();
    } catch (e, s) {
      ErrorLog.record(e, s, context: 'Respaldo');
    }
    if (!mounted) return;
    setState(() {
      if (_service.account != null) _backups = _service.listBackups();
    });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    await runGuarded(context, action, success: success);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_service.account != null) _backups = _service.listBackups();
    });
  }

  Future<void> _restore(DriveBackup b) async {
    final ok = await confirmDialog(
      context,
      title: 'Restaurar respaldo',
      message: 'Se reemplazarán TODOS los datos del celular por el respaldo del ${formatDateTime(b.createdAt)}. '
          'Antes se guarda una copia local de seguridad. ¿Continuar?',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final store = StoreScope.read(context);
    await _run(() => _service.restore(store, b), success: 'Respaldo restaurado');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final account = _service.account;
    final last = DateTime.tryParse(store.settings['last_backup_at'] ?? '');
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Respaldo', showBack: true, showSync: false, showLogo: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(account == null ? Icons.cloud_off : Icons.cloud_done,
                      color: account == null ? PColors.gris : PColors.verde, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account == null ? 'Sin cuenta conectada' : account.email, style: PText.bodyLg(weight: FontWeight.w700)),
                        Text(last == null ? 'Nunca se ha respaldado' : 'Último respaldo: ${formatDateTime(last.toLocal())}',
                            style: PText.bodyMd(color: PColors.gris)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  'Se respalda solo cada 7 días al abrir la app y después de cada corte de caja. '
                  'Se conservan los últimos ${BackupService.keepLast} respaldos en la carpeta "${BackupService.folderName}".',
                  style: PText.bodyMd(color: PColors.gris),
                ),
                const SizedBox(height: 16),
                if (account == null)
                  PButton(
                    label: 'Conectar cuenta de Google',
                    icon: Icons.login,
                    variant: PButtonVariant.secondary,
                    onPressed: _busy ? null : () => _run(() async {
                      final acc = await _service.signIn(store);
                      if (acc == null) throw StateError('Inicio de sesión cancelado');
                    }, success: 'Cuenta conectada'),
                  )
                else ...[
                  PButton(
                    label: _busy ? 'Trabajando…' : 'Respaldar ahora',
                    icon: Icons.cloud_upload,
                    onPressed: _busy ? null : () => _run(() => _service.backupNow(store), success: 'Respaldo completado'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => _run(() => _service.signOut(store), success: 'Cuenta desconectada'),
                    child: const Text('Desconectar cuenta'),
                  ),
                ],
              ],
            ),
          ),
          if (account != null) ...[
            const SizedBox(height: 20),
            const SectionHeader('Respaldos en Drive', color: PColors.gris),
            const SizedBox(height: 8),
            FutureBuilder<List<DriveBackup>>(
              future: _backups,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return Text('No se pudo consultar Drive: ${snap.error}', style: PText.bodyMd(color: PColors.rojo));
                }
                final list = snap.data ?? const <DriveBackup>[];
                if (list.isEmpty) return Text('Aún no hay respaldos', style: PText.bodyMd(color: PColors.gris));
                return Column(children: [
                  for (final b in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storage, color: PColors.morado),
                      title: Text(formatDateTime(b.createdAt)),
                      subtitle: Text('${(b.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                      trailing: TextButton(onPressed: _busy ? null : () => _restore(b), child: const Text('Restaurar')),
                    ),
                ]);
              },
            ),
          ],
        ],
      ),
    );
  }
}
