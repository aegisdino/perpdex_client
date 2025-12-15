import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../util.dart';

/// Syncfusion 사각형 슬라이더 트랙 shape
class CustomSfTrackShape extends SfTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Offset? thumbCenter,
    Offset? startThumbCenter,
    Offset? endThumbCenter, {
    required RenderBox parentBox,
    required SfSliderThemeData themeData,
    SfRangeValues? currentValues,
    dynamic currentValue,
    required Animation<double> enableAnimation,
    required Paint? inactivePaint,
    required Paint? activePaint,
    required TextDirection textDirection,
  }) {
    // parentBox가 제대로 초기화되지 않은 경우 기본 구현 사용
    if (!parentBox.hasSize) {
      return;
    }

    final Canvas canvas = context.canvas;
    final double trackHeight = themeData.activeTrackHeight;
    final double trackY = offset.dy + (parentBox.size.height / 2);

    // Inactive track (전체 트랙)
    final Rect inactiveTrackRect = Rect.fromLTWH(
      offset.dx,
      trackY - trackHeight / 2,
      parentBox.size.width,
      trackHeight,
    );

    final Paint inactiveTrackPaint = Paint()
      ..color =
          themeData.inactiveTrackColor ?? Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(inactiveTrackRect, inactiveTrackPaint);

    // Active track (thumb까지의 트랙)
    if (thumbCenter != null) {
      final double activeWidth = thumbCenter.dx - offset.dx;
      final Rect activeTrackRect = Rect.fromLTWH(
        offset.dx,
        trackY - trackHeight / 2,
        activeWidth,
        trackHeight,
      );

      final Paint activeTrackPaint = Paint()
        ..color = themeData.activeTrackColor ?? AppTheme.primary
        ..style = PaintingStyle.fill;

      canvas.drawRect(activeTrackRect, activeTrackPaint);
    }
  }
}

/// Syncfusion 사각형 슬라이더 thumb shape
class CustomSfRectThumbShape extends SfThumbShape {
  const CustomSfRectThumbShape();

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required RenderBox? child,
    required SfSliderThemeData themeData,
    SfRangeValues? currentValues,
    dynamic currentValue,
    required Paint? paint,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required SfThumb? thumb,
  }) {
    final Canvas canvas = context.canvas;

    // thumb을 아래로 2픽셀 이동
    final adjustedCenter = Offset(center.dx, center.dy + 2);

    final rect = Rect.fromCenter(
      center: adjustedCenter,
      width: 10,
      height: 10,
    );

    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      rect,
      thumbPaint,
    );
  }
}
