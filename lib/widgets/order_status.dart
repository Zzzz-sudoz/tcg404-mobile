import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color orderStatusColor(String status, {BuildContext? context}) {
  final colors = context == null
      ? const TcgPalette(true)
      : TcgColors.of(context);
  return switch (status) {
    'completed' =>
      colors.dark ? const Color(0xffa7dfba) : const Color(0xff21653a),
    'cancelled' => colors.red,
    'delayed' || 'pending' => colors.yellow,
    'shipped' =>
      colors.dark ? const Color(0xff9fd5f5) : const Color(0xff245e86),
    _ => colors.lavender,
  };
}
