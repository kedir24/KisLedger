import 'package:flutter/material.dart';

/// Colour choices come from the subject: a shop ledger. Ink green carries the
/// brand, while debit and credit each get a fixed hue so a glance at any
/// column tells you which side you are reading.
class Tokens {
  static const inkGreen = Color(0xFF0E4B3C);
  static const inkGreenLight = Color(0xFF3FA88B);
  static const debit = Color(0xFF1F5C8B);
  static const credit = Color(0xFFA8542B);
  static const paper = Color(0xFFF7F8F6);
  static const night = Color(0xFF0D1311);
  static const nightSurface = Color(0xFF16201C);
}

ThemeData buildTheme({required Brightness brightness}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.inkGreen,
    brightness: brightness,
  ).copyWith(
    primary: dark ? Tokens.inkGreenLight : Tokens.inkGreen,
    surface: dark ? Tokens.nightSurface : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Tokens.night : Tokens.paper,
    fontFamily: 'NotoSansEthiopic',
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Tokens.night : Tokens.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansEthiopic',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: dark ? const Color(0xFF243029) : const Color(0xFFE3E7E2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF111A16) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF243029) : const Color(0xFFDDE2DC),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? const Color(0xFF243029) : const Color(0xFFDDE2DC),
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: 'NotoSansEthiopic',
            fontSize: 16,
            fontWeight: FontWeight.w700),
      ),
    ),
  );
}
