import 'package:flutter/material.dart';

abstract final class ZColors {
  static const green = Color(0xFF01261F);
  static const greenActive = Color(0xFF1A3C34);
  static const greenMid = Color(0xFF43655C);
  static const greenSoft = Color(0xFFC5EADF);
  static const yellow = Color(0xFFFED65B);
  static const gold = Color(0xFFD4AF37);
  static const yellowText = Color(0xFF735C00);
  static const mint = Color(0xFFC5EADF);

  static const background = Color(0xFFF7F9FF);
  static const warmBackground = Color(0xFFF7F9FF);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF1F4F9);
  static const surfaceContainer = Color(0xFFEBEEF3);

  static const text = Color(0xFF181C20);
  static const muted = Color(0xFF414846);
  static const subtle = Color(0xFF717976);
  static const line = Color(0xFFC1C8C4);

  static const danger = Color(0xFFBA1A1A);
  static const dangerSoft = Color(0xFFFFDAD6);
  static const success = Color(0xFF2A7B5F);
  static const successSoft = Color(0xFFE7F5EF);
  static const warningSurface = Color(0xFFFFF3CF);
  static const shadow = Color(0x0D1A3C34);
}

abstract final class ZSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
}

abstract final class ZRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 12.0;
  static const xl = 24.0;
  static const hero = 24.0;
  static const pill = 30.0;
}

abstract final class ZShadow {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0D1A3C34),
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  static const float = <BoxShadow>[
    BoxShadow(
      color: Color(0x141A3C34),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];
}

ThemeData buildMarketPlusTheme() {
  const scheme = ColorScheme.light(
    primary: ZColors.green,
    onPrimary: Colors.white,
    primaryContainer: ZColors.greenActive,
    onPrimaryContainer: Color(0xFF83A69C),
    secondary: ZColors.yellowText,
    onSecondary: Colors.white,
    secondaryContainer: ZColors.yellow,
    onSecondaryContainer: ZColors.yellowText,
    tertiary: Color(0xFF002808),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF004012),
    onTertiaryContainer: Color(0xFF3AB551),
    surface: ZColors.surface,
    onSurface: ZColors.text,
    error: ZColors.danger,
    onError: Colors.white,
    outline: Color(0xFF717976),
    outlineVariant: ZColors.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ZColors.background,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineSmall: const TextStyle(
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w800,
        color: ZColors.green,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w800,
        color: ZColors.text,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w700,
        color: ZColors.text,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.55,
        fontWeight: FontWeight.w500,
        color: ZColors.text,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: ZColors.text,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.5,
        color: ZColors.muted,
      ),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZColors.background,
      foregroundColor: ZColors.green,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 62,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ZColors.green,
      ),
      iconTheme: IconThemeData(color: ZColors.green, size: 23),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: ZColors.subtle, fontSize: 14),
      labelStyle: const TextStyle(color: ZColors.muted, fontWeight: FontWeight.w600),
      prefixIconColor: ZColors.greenMid,
      suffixIconColor: ZColors.greenMid,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.md),
        borderSide: const BorderSide(color: Color(0xFFE5E8EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.md),
        borderSide: const BorderSide(color: ZColors.gold, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.md),
        borderSide: const BorderSide(color: ZColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ZRadius.md),
        borderSide: const BorderSide(color: ZColors.danger, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: ZColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZRadius.lg),
        side: const BorderSide(color: Color(0xFFE5E8EE)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: ZColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD7DADF),
        disabledForegroundColor: const Color(0xFF717976),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZRadius.pill)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: ZColors.green,
        side: const BorderSide(color: ZColors.green, width: 1.2),
        backgroundColor: Colors.transparent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZRadius.pill)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZColors.green,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5E8EE),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: ZColors.yellow,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? ZColors.green : ZColors.subtle,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? ZColors.green : ZColors.subtle,
          size: states.contains(WidgetState.selected) ? 24 : 22,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ZColors.green),
  );
}
