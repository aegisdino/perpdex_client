import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class IconDotPainter extends FlDotPainter {
  final IconData icon;
  final Color color;
  final double size;

  const IconDotPainter({
    required this.icon,
    this.color = Colors.red,
    this.size = 12,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInSpace) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        offsetInSpace.dx - textPainter.width / 2,
        offsetInSpace.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(size * 2, size * 2);
  }

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is IconDotPainter && b is IconDotPainter) {
      return IconDotPainter(
        icon: b.icon,
        color: Color.lerp(a.color, b.color, t)!,
        size: ui.lerpDouble(a.size, b.size, t)!,
      );
    }
    return b;
  }

  @override
  Color get mainColor => color;

  @override
  List<Object?> get props => [icon, color, size];
}

class ImageDotPainter extends FlDotPainter {
  final ui.Image image;
  final double size;
  final Color? tintColor;

  ImageDotPainter({
    required this.image,
    this.size = 20,
    this.tintColor,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInSpace) {
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(
      center: offsetInSpace,
      width: size,
      height: size,
    );

    final paint = Paint();
    if (tintColor != null) {
      paint.colorFilter = ColorFilter.mode(
        tintColor!,
        BlendMode.srcIn,
      );
    }

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  Size getSize(FlSpot spot) => Size(size, size);

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is ImageDotPainter && b is ImageDotPainter) {
      return ImageDotPainter(
        image: b.image,
        size: ui.lerpDouble(a.size, b.size, t)!,
        tintColor: Color.lerp(a.tintColor, b.tintColor, t),
      );
    }
    return b;
  }

  @override
  Color get mainColor => tintColor ?? Colors.transparent;

  @override
  List<Object?> get props => [image, size, tintColor];
}

class ChartImageManager {
  factory ChartImageManager() {
    return _singleton;
  }

  ChartImageManager._internal();

  static final ChartImageManager _singleton = ChartImageManager._internal();

  Map<String, ui.Image> assetImageMap = {};
  List<String> updownAssetNames = ["happy", "sad", "up", "down"];

  Future loadImages() async {
    if (assetImageMap.isNotEmpty) return;
    for (var asset in ["finish", ...updownAssetNames]) {
      final image = Image.asset(
          "${(kDebugMode && kIsWeb) ? "" : "assets/"}image/$asset.png");

      final completer = Completer<ui.Image>();

      image.image.resolve(ImageConfiguration()).addListener(
        ImageStreamListener(
          (info, _) {
            completer.complete(info.image);
          },
        ),
      );

      final loadedImage = await completer.future;
      assetImageMap[asset] = loadedImage;
    }
  }
}
