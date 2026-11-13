import 'package:flutter/material.dart';

/// Identidad FitMakyp: morado, moderno, limpio y femenino sin ser infantil.
///
/// Los colores que dependen del tema (claro/oscuro) son getters: al cambiar [dark]
/// la app se reconstruye entera (ver `FitMakypApp`).
abstract final class FmColors {
  /// true mientras la app se muestra en modo oscuro.
  static bool dark = false;

  /// Morado profundo de marca: fijo (degradados, dibujos de la mascota).
  static const deep = Color(0xFF2B1B43);
  static const mint = Color(0xFF7CCFC3); // turquesa suave (acentos de éxito / agua)
  static const lilac = Color(0xFFB79CE6);

  // Principal (en oscuro, un poco más claro para que se lea sobre el fondo)
  static Color get primary => dark ? const Color(0xFF9468E0) : const Color(0xFF7041B8);

  /// Texto principal.
  static Color get ink => dark ? const Color(0xFFEEE7FA) : deep;

  /// Fondo suave morado (chips, resaltados).
  static Color get lavender => dark ? const Color(0xFF3A2A57) : const Color(0xFFDCCBFA);

  /// Fondo de pantalla.
  static Color get warmWhite => dark ? const Color(0xFF130E1B) : const Color(0xFFFBF8FF);

  /// Tarjetas y hojas.
  static Color get surface => dark ? const Color(0xFF1E1729) : Colors.white;
  static Color get muted => dark ? const Color(0xFFA9A0BD) : const Color(0xFF7B7290);
  static Color get line => dark ? const Color(0xFF342A47) : const Color(0xFFECE4F8);
}

ThemeData buildTheme({bool dark = false}) {
  FmColors.dark = dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7041B8),
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: FmColors.primary,
    onPrimary: Colors.white,
    secondary: FmColors.lilac,
    tertiary: FmColors.mint,
    surface: FmColors.surface,
    onSurface: FmColors.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: FmColors.warmWhite,
  );
  // Se fusiona con la geometría (tamaños) para que los estilos fuera de Theme.of tengan tamaño.
  final text = Typography.englishLike2021.merge(base.textTheme).apply(
        bodyColor: FmColors.ink,
        displayColor: FmColors.ink,
      );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: FmColors.warmWhite,
      foregroundColor: FmColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: FmColors.ink),
    ),
    cardTheme: CardThemeData(
      color: FmColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: FmColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        backgroundColor: FmColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: FmColors.primary,
        side: BorderSide(color: FmColors.lavender, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: FmColors.primary)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FmColors.surface,
      indicatorColor: FmColors.lavender,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? FmColors.ink : FmColors.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? FmColors.ink : FmColors.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: FmColors.warmWhite,
      side: BorderSide(color: FmColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: FmColors.surface),
    dialogTheme: DialogThemeData(backgroundColor: FmColors.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FmColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: FmColors.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: FmColors.line)),
    ),
    dividerTheme: DividerThemeData(color: FmColors.line, space: 1),
  );
}
