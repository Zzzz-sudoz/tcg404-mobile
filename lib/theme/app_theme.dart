import 'package:flutter/material.dart';

abstract final class TcgColors {
  static const bg = Color(0xff15161c);
  static const surface = Color(0xff202129);
  static const raised = Color(0xff2d2e38);
  static const ink = Color(0xfff6f3e9);
  static const muted = Color(0xffbdbdcb);
  static const yellow = Color(0xfff6db79);
  static const lavender = Color(0xffc6b6ef);
  static const border = Color(0xff777886);
  static const red = Color(0xffffa6aa);
}

ThemeData storeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: TcgColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: TcgColors.yellow,
      secondary: TcgColors.lavender,
      surface: TcgColors.surface,
      onSurface: TcgColors.ink,
      onPrimary: TcgColors.bg,
      onSecondary: TcgColors.bg,
      onError: TcgColors.bg,
      error: TcgColors.red,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: TcgColors.ink, displayColor: TcgColors.ink)
        .copyWith(
          headlineLarge: const TextStyle(
            color: TcgColors.ink,
            fontFamily: 'Barlow',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
          headlineMedium: const TextStyle(
            color: TcgColors.ink,
            fontFamily: 'Barlow',
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            color: TcgColors.ink,
            fontFamily: 'Barlow',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TcgColors.bg,
      foregroundColor: TcgColors.ink,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TcgColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TcgColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TcgColors.yellow, width: 2),
      ),
      errorMaxLines: 4,
      helperMaxLines: 3,
      contentPadding: const EdgeInsets.all(16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TcgColors.bg,
        backgroundColor: TcgColors.yellow,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: TcgColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TcgColors.surface,
      indicatorColor: TcgColors.yellow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? TcgColors.bg
              : TcgColors.muted,
        ),
      ),
    ),
    dividerColor: TcgColors.border,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: TcgColors.raised,
      contentTextStyle: TextStyle(color: TcgColors.ink, fontSize: 14),
      actionTextColor: TcgColors.yellow,
    ),
  );
}
