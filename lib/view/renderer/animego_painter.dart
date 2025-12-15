import 'dart:math' as math;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ArcTextPainter extends CustomPainter {
  final double radius;
  final double? initAngle;
  final String? text;
  final List<TextSpan>? textSpans;
  final TextStyle? textStyle;
  final Color? outlineColor;
  final bool clockWise;

  ArcTextPainter({
    required this.radius,
    this.text,
    this.textSpans,
    this.initAngle,
    this.textStyle,
    this.outlineColor,
    this.clockWise = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text == null && textSpans == null) return;

    final Offset center = Offset(size.width / 2, size.height / 2);

    double textWidth;
    Paint? strokeForeground;

    if (outlineColor != null) {
      // 윤곽선을 위한 텍스트 스타일
      strokeForeground = Paint()
        ..color = outlineColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
    }

    // 텍스트 길이 측정
    final textStyleFill = textSpans == null
        ? (textStyle ??
            TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 0))
        : null;

    final textPainter = TextPainter(
        text: TextSpan(text: text, children: textSpans, style: textStyleFill),
        textDirection: TextDirection.ltr);

    textPainter.layout();
    textWidth = textPainter.width;

    // 원 호(arc) 위의 텍스트 시작 각도를 계산합니다.
    double startAngle = (initAngle ?? 0) +
        (clockWise ? -(textWidth / radius) / 2 : (textWidth / radius) / 2);

    double textStartOffset = 0;

    void drawChar(TextPainter charPainter) {
      charPainter.layout();

      final charWidth = charPainter.width;

      // 문자별로 각도를 조정하여 반시계 방향으로 배치합니다.
      final double charAngle = clockWise
          ? startAngle + textStartOffset / radius
          : startAngle - textStartOffset / radius;

      final position = center +
          Offset(math.cos(charAngle), math.sin(charAngle)) *
              (radius +
                  (clockWise
                      ? charPainter.height / 2
                      : -charPainter.height / 2));

      canvas.save();
      canvas.translate(position.dx, position.dy);
      // 텍스트를 올바른 각도로 회전합니다.
      canvas.rotate(clockWise
          ? charAngle + math.pi / 2
          : charAngle + math.pi + math.pi / 2);
      // 중앙 정렬을 위해 X축으로 이동
      charPainter.paint(canvas, Offset(-charWidth / 2, 0));

      canvas.restore();

      textStartOffset += charWidth;
    }

    void drawText(Paint? foreground, {Offset? offset}) {
      textStartOffset = 0;
      if (text != null) {
        TextStyle txStyle = textStyleFill!.copyWith(foreground: foreground);
        for (int i = 0; i < text!.length; i++) {
          final charPainter = TextPainter(
            text: TextSpan(text: text![i], style: txStyle),
            textDirection: TextDirection.ltr,
          );
          drawChar(charPainter);
        }
      } else {
        for (int i = 0; i < textSpans!.length; i++) {
          for (int j = 0; j < textSpans![i].text!.length; j++) {
            final charPainter = TextPainter(
              text: TextSpan(
                  text: textSpans![i].text![j],
                  style: textSpans![i].style?.copyWith(foreground: foreground)),
              textDirection: TextDirection.ltr,
            );
            drawChar(charPainter);
          }
        }
      }
    }

    if (strokeForeground != null) drawText(strokeForeground);
    drawText(null);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Future<ui.Image> loadImage(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}

class WalkRingPainer extends CustomPainter {
  final double angle;
  final EdgeInsets padding;
  final ui.Image image;
  final ui.Image icon;
  final double? iconSize;
  final double cylinderThickness;

  WalkRingPainer({
    required this.image,
    required this.angle,
    required this.icon,
    this.padding = EdgeInsets.zero,
    this.cylinderThickness = 0,
    this.iconSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    //--------------------------------------------------------------------------
    // 이미지를 캔버스 중앙에 그림
    //--------------------------------------------------------------------------
    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width,
          height: size.height),
      image: image,
      fit: BoxFit.contain,
    );

    // 타원의 중심, 반지름 설정
    double cx =
        padding.left + (size.width - padding.left - padding.right) / 2 + 2;
    double cy = padding.top + (size.height - padding.top - padding.bottom) / 2;
    double rx = (size.width - padding.left - padding.right) / 2 -
        cylinderThickness / 2; // 가로 반지름
    double ry = (size.height - padding.top - padding.bottom) / 2 -
        cylinderThickness * 0.7; // 세로 반지름

    // 3d perspective인 관계로 위쪽 타원은 세로 반지름이 조금 더 크게 계산해야 함
    if (angle > pi) ry += 15;

    // center, 0, 90, 180, 270도에 포인트 찍어줌
    // final paint = Paint();
    // canvas.drawCircle(Offset(cx, cy), 5, paint..color = Colors.red);
    // canvas.drawCircle(Offset(cx, cy - ry - 15), 5, paint..color = Colors.red);
    // canvas.drawCircle(Offset(cx, cy + ry), 5, paint..color = Colors.red);
    // canvas.drawCircle(Offset(cx - rx, cy), 5, paint..color = Colors.red);
    // canvas.drawCircle(Offset(cx + rx, cy), 5, paint..color = Colors.red);

    //--------------------------------------------------------------------------
    // 신발 아이콘을 rotate를 해서 그림
    //--------------------------------------------------------------------------
    canvas.save(); // 캔버스 상태 저장

    // 타원상의 점 계산
    final double x = cx + rx * cos(angle);
    final double y = cy + ry * sin(angle);
    final _iconSize = iconSize ?? 30;

    canvas.translate(x, y); // 회전의 중심을 이미지 중심으로 이동
    canvas.rotate(angle + pi); // 주어진 각도로 회전 (라디안 단위)

    paintImage(
      canvas: canvas,
      rect: Rect.fromCenter(
          center: Offset.zero, width: _iconSize, height: _iconSize),
      image: icon,
      fit: BoxFit.contain,
    );

    canvas.restore(); // 캔버스 rotation 원복

    // final paint = Paint();
    // canvas.drawCircle(Offset(x, y), 5, paint..color = Colors.red);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
