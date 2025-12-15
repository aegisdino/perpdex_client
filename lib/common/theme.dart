import 'dart:math';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/localization.dart';

const String englishFontFamily = 'Outfit';

class AppTheme {
  static const double phoneSizeThreshold = 600;

  // We are on phone width media, based on our definition in this app.
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < phoneSizeThreshold;
  }

  // In dark mode?
  static bool isDark(BuildContext context) {
    return _isDarkMode = (Theme.of(context)).brightness == Brightness.dark;
  }

  static bool _isDarkMode = false;

  static bool get isDarkMode {
    return _isDarkMode;
  }

  // DEX 커스텀 색상 스킴 (스크린샷 기반)
  static const Color dexPrimary = Color(0xFFEFBE84); // 연한 오렌지/베이지 (버튼 색상)
  static const Color dexSecondary = Color(0xFF232323); // 어두운 회색
  static const Color dexBackground = Color(0xFF191919); // 매우 어두운 배경
  static const Color dexSurface = Color(0xFF232323); // 카드/컴포넌트 배경
  static const Color dexSurfaceVariant = Color(0xFF1E2329); // 헤더/툴바 배경

  static const Color popupBackground = AppTheme.dexSurface;
  static const Color popupSubBackground = Color(0xFF2E2923);

  // 커스텀 FlexColorScheme 정의
  static const FlexSchemeColor dexLightScheme = FlexSchemeColor(
    primary: dexPrimary,
    primaryContainer: Color(0xFFE5C62E),
    secondary: dexSecondary,
    secondaryContainer: Color(0xFF3A404A),
    tertiary: Color(0xFF4A5568),
    tertiaryContainer: Color(0xFF5A6578),
    appBarColor: dexSurfaceVariant,
    error: Color(0xFFFF1100), // downColor
  );

  static const FlexSchemeColor dexDarkScheme = FlexSchemeColor(
    primary: dexPrimary,
    primaryContainer: Color(0xFFE5C62E),
    secondary: dexSecondary,
    secondaryContainer: Color(0xFF3A404A),
    tertiary: Color(0xFF4A5568),
    tertiaryContainer: Color(0xFF5A6578),
    appBarColor: dexSurfaceVariant,
    error: Color(0xFFFF1100), // downColor
  );

  static String? getNonEnglishFontFamily() {
    String languageCode = Localization.language;

    switch (languageCode) {
      case 'ko':
        return GoogleFonts.notoSansKr().fontFamily;
      case 'ja':
        return GoogleFonts.notoSansJp().fontFamily;
      case 'zh-CH': // simplified chinese
        return GoogleFonts.notoSansSc().fontFamily;
      case 'zh-TW': // traditional chinese
        return GoogleFonts.notoSansTc().fontFamily;
      default:
        return englishFontFamily;
    }
  }

  static ThemeData getTheme() {
    return FlexThemeData.light(
      colors: dexLightScheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 0, // 블렌딩 없이 순수 색상 사용
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        blendOnColors: false,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: englishFontFamily,
    );
  }

  static ThemeData getDarkTheme() {
    return FlexThemeData.dark(
      colors: dexDarkScheme,
      surfaceMode: FlexSurfaceMode.custom,
      surface: dexBackground, // 메인 배경색
      scaffoldBackground: dexBackground,
      blendLevel: 0, // 블렌딩 없이 순수 색상 사용
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        blendOnColors: false,
        // 카드 배경
        cardRadius: 4.0,
        // 버튼 스타일
        elevatedButtonRadius: 4.0,
        outlinedButtonRadius: 4.0,
        textButtonRadius: 4.0,
        // 입력 필드
        inputDecoratorRadius: 4.0,
      ),
      // 추가 색상 오버라이드
      extensions: const <ThemeExtension<dynamic>>[],
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      fontFamily: englishFontFamily,
    ).copyWith(
      // 추가 색상 커스터마이징
      cardColor: dexSurface,
      canvasColor: dexBackground,
      scaffoldBackgroundColor: dexBackground,
      dividerColor: AppTheme.dexSecondary,
      // AppBar 스타일
      appBarTheme: const AppBarTheme(
        backgroundColor: dexSurfaceVariant,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      // Dialog 스타일
      dialogTheme: const DialogThemeData(
        backgroundColor: dexSurface,
      ),
    );
  }

  // bgColor에 매칭되는 텍스트 칼라
  static Color getMatchingTextColor(Color bgColor) {
    if (bgColor == colorScheme.primary) {
      return colorScheme.onPrimary;
    } else if (bgColor == colorScheme.secondary) {
      return colorScheme.onSecondary;
    } else {
      return ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light
          ? Colors.black
          : Colors.white;
    }
  }

  static Color getTextColor(Color bgColor) {
    return getMatchingTextColor(bgColor);
  }

  static late ColorScheme colorScheme;
  static late TextTheme textTheme;

  static late TextStyle labelSmall;
  static late TextStyle bodyLarge;
  static late TextStyle bodyMedium;
  static late TextStyle bodySmall;
  static late TextStyle headlineSmall;
  static late TextStyle headlineMedium;
  static late TextStyle headlineLarge;
  static late TextStyle headlineLargeBold;

  static late TextStyle bodySmallBold;
  static late TextStyle bodyMediumBold;
  static late TextStyle bodyLargeBold;
  static late TextStyle headlineSmallBold;

  static late TextStyle num10;
  static late TextStyle num12;
  static late TextStyle num14;
  static late TextStyle num16;
  static late TextStyle num20;

  static late MaterialColor primary;
  static late MaterialColor primaryContainer;
  static late MaterialColor secondary;
  static late MaterialColor background;
  static late MaterialColor onPrimary;
  static late MaterialColor onSecondary;
  static late MaterialColor onBackground;

  static TextStyle smallText({Color? color}) {
    if (color != null) {
      return AppTheme.textTheme.labelSmall!.copyWith(color: color);
    } else {
      return AppTheme.textTheme.labelSmall!;
    }
  }

  static TextStyle get labelSmallOnPrimary => AppTheme.textTheme.labelSmall!
      .copyWith(color: AppTheme.colorScheme.onPrimary);

  static void updateScheme(BuildContext context) {
    colorScheme = Theme.of(context).colorScheme;
    textTheme = Theme.of(context).textTheme;

    primary = createMaterialColor(colorScheme.primary);
    primaryContainer = createMaterialColor(colorScheme.primaryContainer);
    secondary = createMaterialColor(colorScheme.secondary);
    background = createMaterialColor(colorScheme.surface);
    onPrimary = createMaterialColor(colorScheme.onPrimary);
    onSecondary = createMaterialColor(colorScheme.onSecondary);
    onBackground = createMaterialColor(colorScheme.onSurface);

    String? nonEnglishFallbackFont = getNonEnglishFontFamily();
    List<String> fallbackFonts = (nonEnglishFallbackFont != null)
        ? [nonEnglishFallbackFont]
        : ['Malgun Gothic', 'sans-serif'];

    labelSmall =
        textTheme.labelSmall!.copyWith(fontFamilyFallback: fallbackFonts);
    bodyLarge =
        textTheme.bodyLarge!.copyWith(fontFamilyFallback: fallbackFonts);
    bodyMedium =
        textTheme.bodyMedium!.copyWith(fontFamilyFallback: fallbackFonts);
    bodySmall =
        textTheme.bodySmall!.copyWith(fontFamilyFallback: fallbackFonts);
    headlineSmall =
        textTheme.headlineSmall!.copyWith(fontFamilyFallback: fallbackFonts);
    headlineMedium =
        textTheme.headlineMedium!.copyWith(fontFamilyFallback: fallbackFonts);
    headlineLarge =
        textTheme.headlineLarge!.copyWith(fontFamilyFallback: fallbackFonts);

    bodySmallBold = textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.bold, fontFamilyFallback: fallbackFonts);
    bodyMediumBold = textTheme.bodyMedium!.copyWith(
        fontWeight: FontWeight.bold, fontFamilyFallback: fallbackFonts);
    bodyLargeBold = textTheme.bodyLarge!.copyWith(
        fontWeight: FontWeight.bold, fontFamilyFallback: fallbackFonts);
    headlineSmallBold = textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold, fontFamilyFallback: fallbackFonts);
    headlineLargeBold = textTheme.headlineLarge!.copyWith(
        fontWeight: FontWeight.bold, fontFamilyFallback: fallbackFonts);

    num10 = textTheme.labelSmall!.copyWith(
        fontSize: 10, fontFamily: GoogleFonts.robotoFlex().fontFamily);
    num12 = textTheme.labelSmall!.copyWith(
        fontSize: 12, fontFamily: GoogleFonts.robotoFlex().fontFamily);
    num14 = textTheme.labelSmall!.copyWith(
        fontSize: 14, fontFamily: GoogleFonts.robotoFlex().fontFamily);
    num16 = textTheme.labelSmall!.copyWith(
        fontSize: 16, fontFamily: GoogleFonts.robotoFlex().fontFamily);
    num20 = textTheme.headlineSmall!.copyWith(
        fontSize: 20, fontFamily: GoogleFonts.robotoFlex().fontFamily);
  }

  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  static MaterialColor createMaterialColor2(Color color) {
    return MaterialColor(color.value, {
      50: tintColor(color, 0.9),
      100: tintColor(color, 0.8),
      200: tintColor(color, 0.6),
      300: tintColor(color, 0.4),
      400: tintColor(color, 0.2),
      500: color,
      600: shadeColor(color, 0.1),
      700: shadeColor(color, 0.2),
      800: shadeColor(color, 0.3),
      900: shadeColor(color, 0.4),
    });
  }

  static int tintValue(int value, double factor) =>
      max(0, min((value + ((255 - value) * factor)).round(), 255));

  static Color tintColor(Color color, double factor) => Color.fromRGBO(
      tintValue(color.red, factor),
      tintValue(color.green, factor),
      tintValue(color.blue, factor),
      1);

  static int shadeValue(int value, double factor) =>
      max(0, min(value - (value * factor).round(), 255));

  static Color shadeColor(Color color, double factor) => Color.fromRGBO(
      shadeValue(color.red, factor),
      shadeValue(color.green, factor),
      shadeValue(color.blue, factor),
      1);

  static Color upColor = Color(0xFF34CBC5);
  static Color downColor = Color(0xFFF16F4F);

  static Color upColorBg = Color(0xFF1F3E3C);
  static Color downColorBg = Color(0xFF472A24);
}
