import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color orderStatusColor(String status) => switch (status) {
  'completed' => const Color(0xffa7dfba),
  'cancelled' => TcgColors.red,
  'delayed' || 'pending' => TcgColors.yellow,
  'shipped' => const Color(0xff9fd5f5),
  _ => TcgColors.lavender,
};
