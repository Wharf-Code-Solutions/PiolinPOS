import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Registro local de errores para soporte (se exporta desde Ajustes).
abstract final class ErrorLog {
  static const _maxBytes = 512 * 1024;
  static File? _file;

  static Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File(p.join(dir.path, 'errores.log'));
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, context: 'Flutter');
      previousOnError?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'Plataforma');
      return true;
    };
  }

  static File? get file => _file;

  static void record(Object error, StackTrace? stack, {String context = 'App'}) {
    debugPrint('[$context] $error');
    final f = _file;
    if (f == null) return;
    try {
      if (f.existsSync() && f.lengthSync() > _maxBytes) {
        f.writeAsStringSync('');
      }
      f.writeAsStringSync(
        '--- ${DateTime.now().toIso8601String()} [$context]\n$error\n${stack ?? ''}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Nunca fallar por registrar un error.
    }
  }
}
