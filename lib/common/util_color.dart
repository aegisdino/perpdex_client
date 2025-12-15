import 'package:flutter/material.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

extension ColorDarken on Color {
  /// 색상을 어둡게 만드는 함수
  /// amount: 0.0 (변화없음) ~ 1.0 (완전히 검은색)
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  /// RGB 값을 직접 줄여서 어둡게 만드는 함수
  Color darkenRGB([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);

    final f = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }

  /// 색상을 밝게 만드는 함수
  /// amount: 0.0 (변화없음) ~ 1.0 (완전히 흰색)
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));

    return hslLight.toColor();
  }

  /// RGB 값을 직접 늘려서 밝게 만드는 함수
  Color lightenRGB([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);

    return Color.fromARGB(
      alpha,
      (red + ((255 - red) * amount)).round(),
      (green + ((255 - green) * amount)).round(),
      (blue + ((255 - blue) * amount)).round(),
    );
  }
}

class ColorUtils {
  /// 색상을 어둡게 만드는 정적 함수
  static Color darken(Color color, [double amount = 0.1]) {
    return color.darken(amount);
  }

  /// RGB 방식으로 어둡게 만드는 정적 함수
  static Color darkenRGB(Color color, [double amount = 0.1]) {
    return color.darkenRGB(amount);
  }

  /// 색상을 밝게 만드는 정적 함수
  static Color lighten(Color color, [double amount = 0.1]) {
    return color.lighten(amount);
  }

  /// RGB 방식으로 밝게 만드는 정적 함수
  static Color lightenRGB(Color color, [double amount = 0.1]) {
    return color.lightenRGB(amount);
  }
}
