import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/theme.dart';
import 'common.dart';

/// Abre la cámara y regresa el primer código leído (R2). Permite captura manual.
Future<String?> scanBarcode(BuildContext context, {String title = 'Escanear código'}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _ScannerPage(title: title)),
  );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.title});

  final String title;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done || code.trim().isEmpty) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code.trim());
  }

  Future<void> _manual() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Capturar código', style: PText.headlineMd()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Número debajo de las barras'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Usar')),
        ],
      ),
    );
    ctrl.dispose();
    if (code != null) _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: PColors.morado,
        foregroundColor: PColors.blanco,
        title: Text(widget.title, style: PText.headlineMd(color: PColors.blanco)),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final codes = capture.barcodes;
              final value = codes.isEmpty ? null : codes.first.rawValue;
              if (value != null) _finish(value);
            },
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo abrir la cámara. Revisa el permiso en Ajustes del teléfono o captura el código a mano.',
                  textAlign: TextAlign.center,
                  style: PText.bodyLg(color: PColors.blanco),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: PColors.amarillo, width: 3),
                borderRadius: PRadius.cardBr,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: PButton(
                label: 'Capturar a mano',
                icon: Icons.keyboard,
                variant: PButtonVariant.soft,
                onPressed: _manual,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
