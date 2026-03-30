import 'package:flutter/material.dart';
import 'constants.dart';

// ═══════════════════════════════════════════════════════════════
// UYGULAMA TEMASI — Cyan-Free Premium Dark Theme
// ═══════════════════════════════════════════════════════════════
ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: kBg,
    cardColor: kCard,
    canvasColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccentBlue,
      secondary: kPurple,
      surface: kCard,
      background: kBg,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kAccentOrange,
      unselectedItemColor: Colors.white24,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: kAccentBlue,
      thumbColor: kAccentOrange,
      inactiveTrackColor: Colors.white.withOpacity(0.1),
      overlayColor: kAccentBlue.withOpacity(0.2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected) ? kAccentOrange : Colors.white38),
      trackColor: MaterialStateProperty.resolveWith((states) =>
        states.contains(MaterialState.selected) ? kAccentBlue.withOpacity(0.5) : Colors.white12),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kAccentOrange),
    ),
  );
}
