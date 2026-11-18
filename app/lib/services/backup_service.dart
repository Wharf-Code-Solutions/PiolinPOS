import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/dates.dart';
import '../core/error_log.dart';
import '../data/pos_store.dart';

class DriveBackup {
  const DriveBackup({required this.id, required this.name, required this.createdAt, required this.sizeBytes});

  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Respaldo de la base SQLite en Google Drive (carpeta propia de la app).
///
/// Usa el permiso `drive.file`: la app solo ve los archivos que ella misma creó.
/// Requiere configurar el cliente OAuth de Android (ver docs/configuracion-google-drive.md).
class BackupService {
  BackupService._();

  static final instance = BackupService._();

  static const folderName = 'PiolinPOS Respaldos';
  static const keepLast = 8;
  static const autoEvery = Duration(days: 7);
  static const _sqliteHeader = 'SQLite format 3';

  final GoogleSignIn _signIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  bool _running = false;

  bool get isRunning => _running;
  GoogleSignInAccount? get account => _signIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() => _signIn.signInSilently();

  Future<GoogleSignInAccount?> signIn(PosStore store) async {
    final acc = await _signIn.signIn();
    if (acc != null) await store.setSetting('backup_account', acc.email);
    return acc;
  }

  Future<void> signOut(PosStore store) async {
    await _signIn.disconnect();
    await store.setSetting('backup_account', '');
  }

  Future<drive.DriveApi> _api() async {
    if (_signIn.currentUser == null) await _signIn.signInSilently();
    final client = await _signIn.authenticatedClient();
    if (client == null) throw StateError('Conecta una cuenta de Google en Ajustes › Respaldo');
    return drive.DriveApi(client);
  }

  Future<String> _folderId(drive.DriveApi api) async {
    final found = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final existing = found.files;
    if (existing != null && existing.isNotEmpty) return existing.first.id!;
    final folder = await api.files.create(drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder');
    return folder.id!;
  }

  /// Sube una copia consistente de la base. Devuelve la fecha del respaldo.
  Future<DateTime> backupNow(PosStore store) async {
    if (_running) throw StateError('Ya hay un respaldo en curso');
    _running = true;
    try {
      final api = await _api();
      final folderId = await _folderId(api);
      final copy = await store.exportDatabaseCopy();
      final now = DateTime.now();
      final stamp = '${businessDate(now)}_${formatTime(now).replaceAll(':', '')}';
      await api.files.create(
        drive.File()
          ..name = 'piolinpos_$stamp.db'
          ..parents = [folderId],
        uploadMedia: drive.Media(copy.openRead(), await copy.length()),
      );
      await copy.delete();
      await _prune(api, folderId);
      await store.setSetting('last_backup_at', toIso(now));
      return now;
    } finally {
      _running = false;
    }
  }

  Future<void> _prune(drive.DriveApi api, String folderId) async {
    final list = await listBackups(api: api, folderId: folderId);
    for (final old in list.skip(keepLast)) {
      await api.files.delete(old.id);
    }
  }

  Future<List<DriveBackup>> listBackups({drive.DriveApi? api, String? folderId}) async {
    final a = api ?? await _api();
    final folder = folderId ?? await _folderId(a);
    final res = await a.files.list(
      q: "'$folder' in parents and trashed = false",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id,name,createdTime,size)',
    );
    return [
      for (final f in res.files ?? const <drive.File>[])
        DriveBackup(
          id: f.id!,
          name: f.name ?? '',
          createdAt: (f.createdTime ?? DateTime.now()).toLocal(),
          sizeBytes: int.tryParse(f.size ?? '') ?? 0,
        ),
    ];
  }

  /// Reemplaza la base local por un respaldo. Antes guarda una copia local de seguridad.
  Future<void> restore(PosStore store, DriveBackup backup) async {
    if (_running) throw StateError('Hay un respaldo en curso');
    _running = true;
    try {
      final api = await _api();
      final media = await api.files.get(backup.id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final tmpDir = await getTemporaryDirectory();
      final downloaded = File(p.join(tmpDir.path, 'restaurar.db'));
      final sink = downloaded.openWrite();
      await media.stream.pipe(sink);

      final header = String.fromCharCodes((await downloaded.openRead(0, 15).first).take(15));
      if (header != _sqliteHeader) {
        await downloaded.delete();
        throw StateError('El archivo descargado no es una base de PiolinPOS válida');
      }

      final supportDir = await getApplicationSupportDirectory();
      final safety = File(p.join(supportDir.path, 'antes_de_restaurar.db'));
      final current = await store.exportDatabaseCopy();
      await current.copy(safety.path);
      await current.delete();

      await store.replaceDatabase((dbPath) async {
        for (final suffix in ['-wal', '-shm', '-journal']) {
          final f = File('$dbPath$suffix');
          if (await f.exists()) await f.delete();
        }
        await downloaded.copy(dbPath);
      });
      await downloaded.delete();
    } finally {
      _running = false;
    }
  }

  /// Respaldo semanal automático (al abrir la app, al volver a ella y tras el corte).
  Future<void> maybeAutoBackup(PosStore store, {bool force = false}) async {
    final accountEmail = store.settings['backup_account'] ?? '';
    if (accountEmail.isEmpty || _running) return;
    final last = DateTime.tryParse(store.settings['last_backup_at'] ?? '');
    if (!force && last != null && DateTime.now().difference(last) < autoEvery) return;
    try {
      final acc = await _signIn.signInSilently();
      if (acc == null) return;
      await backupNow(store);
    } catch (e, s) {
      ErrorLog.record(e, s, context: 'Respaldo automático');
    }
  }
}
