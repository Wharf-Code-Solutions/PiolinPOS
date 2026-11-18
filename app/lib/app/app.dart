import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../data/pos_store.dart';
import '../services/backup_service.dart';
import 'router.dart';
import 'theme.dart';

class PiolinApp extends StatefulWidget {
  const PiolinApp({super.key, required this.store});

  final PosStore store;

  @override
  State<PiolinApp> createState() => _PiolinAppState();
}

class _PiolinAppState extends State<PiolinApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => BackupService.instance.maybeAutoBackup(widget.store));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackupService.instance.maybeAutoBackup(widget.store);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: MaterialApp.router(
        title: 'El Piolín POS',
        debugShowCheckedModeBanner: false,
        theme: buildPiolinTheme(),
        routerConfig: _router,
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
