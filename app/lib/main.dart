import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/error_log.dart';
import 'data/pos_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ErrorLog.init();
  try {
    final store = await PosStore.open();
    runApp(PiolinApp(store: store));
  } catch (e, s) {
    ErrorLog.record(e, s, context: 'Arranque');
    runApp(_StartupError(error: e));
  }
}

/// Pantalla mínima si la base de datos no se pudo abrir.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo abrir la base de datos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Cierra y vuelve a abrir la app. Si continúa, contacta a soporte.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
