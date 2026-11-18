import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta definida en `design/DESIGN.md` (raíz del repositorio).
abstract final class PColors {
  static const morado = Color(0xFF4B2A9B); // Morado Lona
  static const moradoProfundo = Color(0xFF33196F);
  static const moradoSuave = Color(0xFFE4DCF7);
  static const moradoTinta = Color(0xFF340685); // primary
  static const rojo = Color(0xFFD42B23); // Red Etiqueta
  static const rojoPressed = Color(0xFFB5201A);
  static const amarillo = Color(0xFFF6D21E); // Canary
  static const amarilloTexto = Color(0xFF6F5D00);
  static const naranja = Color(0xFFEF8A17); // Orange Paw
  static const verde = Color(0xFF2F9E5B);
  static const azul = Color(0xFF2F6FD6);
  static const crema = Color(0xFFFBF6E9);
  static const blanco = Color(0xFFFFFFFF);
  static const tinta = Color(0xFF1E1530);
  static const gris = Color(0xFF6B6478);
  static const borde = Color(0xFFE6DEC9);
  static const sombraContacto = Color(0xFFC9BFAC);
  static const beige = Color(0xFFF5EFDF); // fondos de input / filas
  static const beigeOscuro = Color(0xFFEDE6D3);
  static const offlineBg = Color(0xFFFFF3C4);
  static const errorBg = Color(0xFFFFDAD6);
}

abstract final class PRadius {
  static const card = 12.0;
  static final cardBr = BorderRadius.circular(card);
  static final pill = BorderRadius.circular(999);
}

/// Tipografía: Domine (títulos / precios) + Hanken Grotesk (UI).
abstract final class PText {
  static const _tab = [FontFeature.tabularFigures()];

  static TextStyle displayMobile({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 26, fontWeight: FontWeight.w700, height: 32 / 26, color: color);

  static TextStyle headlineLg({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 22, fontWeight: FontWeight.w700, height: 28 / 22, color: color);

  static TextStyle headlineMd({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 18, fontWeight: FontWeight.w600, height: 24 / 18, color: color);

  static TextStyle sectionHeader({Color color = PColors.tinta}) => GoogleFonts.domine(
      fontSize: 14, fontWeight: FontWeight.w700, height: 18 / 14, letterSpacing: 14 * 0.08, color: color);

  static TextStyle bodyLg({Color color = PColors.tinta, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: weight, height: 22 / 16, color: color);

  static TextStyle bodyMd({Color color = PColors.tinta, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: weight, height: 20 / 14, color: color);

  static TextStyle button({Color color = PColors.blanco}) => GoogleFonts.hankenGrotesk(
      fontSize: 16, fontWeight: FontWeight.w700, height: 20 / 16, letterSpacing: 0.32, color: color);

  static TextStyle label({Color color = PColors.gris, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: weight, height: 16 / 12, color: color);

  static TextStyle priceXl({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15, color: color, fontFeatures: _tab);

  static TextStyle priceLg({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 24, fontWeight: FontWeight.w700, height: 28 / 24, color: color, fontFeatures: _tab);

  static TextStyle priceSm({Color color = PColors.tinta}) =>
      GoogleFonts.domine(fontSize: 15, fontWeight: FontWeight.w700, height: 18 / 15, color: color, fontFeatures: _tab);
}

ThemeData buildPiolinTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PColors.morado,
      primary: PColors.morado,
      onPrimary: PColors.blanco,
      secondary: PColors.rojo,
      onSecondary: PColors.blanco,
      tertiary: PColors.amarillo,
      surface: PColors.crema,
      onSurface: PColors.tinta,
      error: const Color(0xFFBA1A1A),
    ),
    scaffoldBackgroundColor: PColors.crema,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: PRadius.cardBr,
    borderSide: const BorderSide(color: PColors.borde),
  );

  return base.copyWith(
    textTheme: GoogleFonts.hankenGroteskTextTheme(base.textTheme).apply(
      bodyColor: PColors.tinta,
      displayColor: PColors.tinta,
    ),
    dividerTheme: const DividerThemeData(color: PColors.borde, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PColors.beige,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: PColors.morado, width: 2),
      ),
      hintStyle: PText.bodyLg(color: PColors.gris, weight: FontWeight.w400),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PColors.tinta,
      contentTextStyle: PText.bodyMd(color: PColors.blanco, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PColors.blanco,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PColors.blanco,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: PRadius.cardBr),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(PColors.blanco),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? PColors.morado : PColors.beigeOscuro,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
