import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/error_log.dart';
import '../core/money.dart';
import 'common.dart';

/// Ejecuta [action] y muestra el error en un SnackBar si falla.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (e, s) {
    ErrorLog.record(e, s, context: 'Acción');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: PColors.rojo,
        content: Text(e.toString().replaceFirst('Bad state: ', '')),
      ));
    return false;
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: PText.headlineMd()),
      content: Text(message, style: PText.bodyLg()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: destructive ? PColors.rojo : PColors.morado),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Pide un texto (motivo, nombre…). Regresa null si se cancela.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String? hint,
  String initial = '',
  String confirmLabel = 'Guardar',
  List<String> suggestions = const [],
  bool required = true,
  int maxLength = 80,
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title, style: PText.headlineMd()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: maxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: hint),
            ),
            if (suggestions.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() => ctrl.text = s),
                    ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PColors.morado),
            onPressed: (required && ctrl.text.trim().isEmpty) ? null : () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return result;
}

/// Pide un monto en pesos. Regresa centavos o null.
Future<int?> askMoney(BuildContext context, {required String title, String? message, int? initialCents}) async {
  final ctrl = TextEditingController(text: initialCents == null ? '' : centsToInput(initialCents));
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: PText.headlineMd()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message, style: PText.bodyMd(color: PColors.gris)), const SizedBox(height: 8)],
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: PText.priceLg(),
            decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PColors.morado),
          onPressed: () {
            final cents = parseMoney(ctrl.text);
            if (cents == null) return;
            Navigator.pop(ctx, cents);
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

/// Campo de texto con etiqueta, para formularios.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.suffixText,
    this.errorText,
    this.maxLength,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
    this.isRequired = false,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? suffixText;
  final String? errorText;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool isRequired;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: PText.label(color: PColors.tinta, weight: FontWeight.w700).copyWith(fontSize: 13)),
            if (isRequired) Text(' *', style: PText.label(color: PColors.rojo, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  onChanged: onChanged,
                  textCapitalization: textCapitalization,
                  style: PText.bodyLg(),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixText: prefixText,
                    suffixText: suffixText,
                    errorText: errorText,
                    counterText: '',
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ],
      ),
    );
  }
}

/// Formateadores de uso común.
final moneyInputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
final digitsOnly = [FilteringTextInputFormatter.digitsOnly];

/// "1.5" → 1500 milésimas.
int? parseQtyMilli(String text) {
  final v = double.tryParse(text.replaceAll(',', '.').trim());
  if (v == null) return null;
  return (v * 1000).round();
}

String formatQty(int milli) {
  final v = milli / 1000;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(v * 10 == (v * 10).roundToDouble() ? 1 : 3);
}

/// Encabezado de pantalla de lista con botón de acción.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PText.headlineLg()),
              if (subtitle != null) Text(subtitle!, style: PText.label()),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// SnackBar informativo (re-export de conveniencia).
void showInfo(BuildContext context, String message, {IconData icon = Icons.info_outline}) =>
    showInfoSnack(context, message, icon: icon);
