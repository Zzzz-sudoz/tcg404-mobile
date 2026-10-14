import 'package:flutter/material.dart';
import '../theme/theme_state.dart';

class ThemeModeSwitch extends StatelessWidget {
  const ThemeModeSwitch({super.key});
  @override
  Widget build(BuildContext context) {
    final state = ThemeScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Dark mode',
      toggled: dark,
      child: Tooltip(
        message: dark ? 'Switch to light mode' : 'Switch to dark mode',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: state?.toggle,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              width: 96,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: dark
                      ? const [Color(0xff293958), Color(0xff081c2a)]
                      : const [Color(0xffbde9ec), Color(0xff5699a4)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: dark ? 12 : null,
                    right: dark ? null : 10,
                    top: 14,
                    child: Icon(
                      dark ? Icons.auto_awesome : Icons.cloud,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  AnimatedAlign(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    alignment: dark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? const Color(0xffe8e7d9)
                              : const Color(0xffffdb57),
                        ),
                        child: Icon(
                          dark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_rounded,
                          color: dark
                              ? const Color(0xff475470)
                              : const Color(0xff806009),
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
