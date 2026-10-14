import 'package:flutter/material.dart';

abstract final class TcgColors {
  static TcgPalette of(BuildContext context) =>
      TcgPalette(Theme.of(context).brightness == Brightness.dark);
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

class TcgPalette {
  const TcgPalette(this.dark);
  final bool dark;
  Color get bg => dark ? TcgColors.bg : const Color(0xfffaf7ef);
  Color get surface => dark ? TcgColors.surface : const Color(0xfffffdf7);
  Color get raised => dark ? TcgColors.raised : const Color(0xffeee9df);
  Color get ink => dark ? TcgColors.ink : const Color(0xff24232b);
  Color get muted => dark ? TcgColors.muted : const Color(0xff625e6c);
  Color get yellow => dark ? TcgColors.yellow : const Color(0xff806009);
  Color get lavender => dark ? TcgColors.lavender : const Color(0xff684397);
  Color get border => dark ? TcgColors.border : const Color(0xff8b8590);
  Color get red => dark ? TcgColors.red : const Color(0xffa52c3e);
}

ThemeData storeTheme([Brightness brightness = Brightness.dark]) {
  final colors = TcgPalette(brightness == Brightness.dark);
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: colors.yellow,
      secondary: colors.lavender,
      surface: colors.surface,
      onSurface: colors.ink,
      onPrimary: brightness == Brightness.dark ? colors.bg : Colors.white,
      onSecondary: brightness == Brightness.dark ? colors.bg : Colors.white,
      onError: brightness == Brightness.dark ? colors.bg : Colors.white,
      error: colors.red,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: colors.ink, displayColor: colors.ink)
        .copyWith(
          headlineLarge: TextStyle(
            color: colors.ink,
            fontFamily: 'Barlow',
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
          headlineMedium: TextStyle(
            color: colors.ink,
            fontFamily: 'Barlow',
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: colors.ink,
            fontFamily: 'Barlow',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.ink,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.yellow, width: 2),
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
        textStyle: TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.yellow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.bg
              : colors.muted,
        ),
      ),
    ),
    dividerColor: colors.border,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.raised,
      contentTextStyle: TextStyle(color: colors.ink, fontSize: 14),
      actionTextColor: colors.yellow,
    ),
  );
}
