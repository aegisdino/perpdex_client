import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/common/all.dart';
import '/data/data.dart';
import 'indicator_data_manager.dart';

class IndicatorSelectPopupView extends StatefulWidget {
  final Function(String? indicator, bool selected)? onChangeSelection;
  IndicatorSelectPopupView({this.onChangeSelection, super.key});

  @override
  State<IndicatorSelectPopupView> createState() =>
      _IndicatorSelectPopupViewState();
}

class _IndicatorSelectPopupViewState extends State<IndicatorSelectPopupView> {
  List<String> items = [
    'Volume',
    'SMA20',
    'SMA50',
    'EMA12',
    'EMA26',
    'EMA20',
    'EMA50',
    'BB U',
    'BB M',
    'BB L',
    'ATR S',
    'ATR R',
    'StochRsi',
    'WilliamsR',
    'HMA',
    'MACD',
    'Momentum',
    'Heatmap',
  ];

  List<String> get selectedIndicators => DataManager().selectedIndicators;

  Widget _buildIndicatorPreview(String indicatorName) {
    final style = IndicatorDataManager.indicatorStyles[indicatorName];
    if (style == null) {
      return Container(width: 30, height: 3, color: Colors.grey);
    }

    return Container(
      width: 30,
      height: 5,
      child: CustomPaint(
        painter: _LineStylePainter(
          color: style.color,
          dashArray: style.dashArray,
          width: style.width * 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double indicatorWidth = 130;
    final double indicatorHeight = 40;

    // 4개 칩 너비(120*4) + 간격(10*3) + 여유 패딩
    final containerWidth = (indicatorWidth * 4) + (10 * 3) + 20;

    return SizedBox(
      width: containerWidth,
      child: Column(
        children: [
          Text('차트에 표시될 인디케이터들을 선택하세요.'),
          SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map(
              (e) {
                final style = IndicatorDataManager.indicatorStyles[e];
                final isSelected = selectedIndicators.contains(e);
                return Theme(
                  data: Theme.of(context).copyWith(
                    chipTheme: ChipThemeData(
                      backgroundColor: Colors.transparent,
                      selectedColor: Colors.transparent,
                      disabledColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      labelStyle: TextStyle(color: Colors.black),
                      secondaryLabelStyle: TextStyle(color: Colors.white),
                      side: BorderSide(
                        color: isSelected ? Colors.grey : Colors.transparent,
                        width: isSelected ? 1 : 0,
                      ),
                      selectedShadowColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      pressElevation: 0,
                    ),
                    splashFactory: NoSplash.splashFactory, // 스플래시 효과 제거
                  ),
                  child: Container(
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: ChoiceChip(
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _buildIndicatorPreview(e),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e,
                              style: TextStyle(
                                color: style?.color,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onSelected: (v) {
                        if (!v)
                          selectedIndicators.remove(e);
                        else
                          selectedIndicators.add(e);
                        widget.onChangeSelection?.call(e, v);
                        DataManager().saveIndicators();
                        setState(() {});
                      },
                      selected: isSelected,
                    ),
                  ),
                );
              },
            ).toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: InkWell(
                    onTap: () {
                      navigationPop(context);
                    },
                    child: Text('Close')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineStylePainter extends CustomPainter {
  final Color color;
  final List<double>? dashArray;
  final double width;

  _LineStylePainter({
    required this.color,
    this.dashArray,
    this.width = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.min(width, 5.0) // 최대 두께를 3으로 증가
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);

    if (dashArray != null && dashArray!.isNotEmpty) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final dashPath = Path();
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      int dashIndex = 0;

      while (distance < metric.length) {
        final dashLength = dashArray![dashIndex % dashArray!.length];
        final endDistance = math.min(distance + dashLength, metric.length);

        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, endDistance),
            Offset.zero,
          );
        }

        distance = endDistance;
        draw = !draw;
        dashIndex++;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future openIndicatorSelectPopup(
  BuildContext context, {
  final Function(String? indicator, bool selected)? onChangeSelection,
}) async {
  return await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        scrollable: true,
        content: IndicatorSelectPopupView(
          onChangeSelection: onChangeSelection,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        actionsPadding: EdgeInsets.all(0),
        actions: <Widget>[],
      );
    },
  );
}
