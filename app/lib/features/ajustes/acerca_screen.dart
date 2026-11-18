import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/piolin_app_bar.dart';

/// Versión de la app y contacto de soporte (F7.5).
class AcercaScreen extends StatelessWidget {
  const AcercaScreen({super.key});

  static const supportContact = 'Wharf Code · soporte de PiolinPOS';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PiolinAppBar(title: 'Acerca de', showBack: true, showSync: false, showLogo: false),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          final info = snap.data;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: PiolinLogo(size: 96)),
              const SizedBox(height: 16),
              Center(child: Text('El Piolín POS', style: PText.displayMobile())),
              Center(
                child: Text(
                  info == null ? '' : 'Versión ${info.version} (${info.buildNumber})',
                  style: PText.bodyLg(color: PColors.gris),
                ),
              ),
              const SizedBox(height: 24),
              PCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Soporte', style: PText.headlineMd()),
                    const SizedBox(height: 4),
                    Text(supportContact, style: PText.bodyLg()),
                    const SizedBox(height: 8),
                    Text(
                      'Si algo falla, exporta el registro de errores desde Ajustes y envíalo a soporte.',
                      style: PText.bodyMd(color: PColors.gris),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Los datos viven en este celular (SQLite) y se respaldan en la cuenta de Google del negocio.',
                textAlign: TextAlign.center,
                style: PText.label(),
              ),
            ],
          );
        },
      ),
    );
  }
}
