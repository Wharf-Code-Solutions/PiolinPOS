import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';
import 'seed.dart';

const databaseFileName = 'piolinpos.db';

/// Abre (o crea) la base local. [factory] y [path] permiten usar sqflite_ffi en pruebas.
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), databaseFileName);
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final sql in schemaV1) {
          batch.execute(sql);
        }
        for (var v = 2; v <= version; v++) {
          for (final sql in migrations[v] ?? const <String>[]) {
            batch.execute(sql);
          }
        }
        await batch.commit(noResult: true);
        await seedBaseData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final batch = db.batch();
          for (final sql in migrations[v] ?? const <String>[]) {
            batch.execute(sql);
          }
          await batch.commit(noResult: true);
        }
      },
    ),
  );
}

Future<String> appDatabasePath() async => p.join(await getDatabasesPath(), databaseFileName);
