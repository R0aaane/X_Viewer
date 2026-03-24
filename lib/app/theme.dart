import 'package:flutter/material.dart';

ThemeData buildAppTheme({required bool useBlackBackground}) {
  const seed = Color(0xFF0F766E);
  final brightness =
      useBlackBackground ? Brightness.dark : Brightness.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final scheme = useBlackBackground
      ? baseScheme.copyWith(
          surface: const Color(0xFF111111),
          surfaceContainerHighest: const Color(0xFF1F1F1F),
        )
      : baseScheme;

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor:
        useBlackBackground ? Colors.black : const Color(0xFFF4F7F5),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: useBlackBackground ? const Color(0xFF171717) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: useBlackBackground
          ? const Color(0xFF1A1A1A)
          : scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
