import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../common/theme.dart';

class CircularProgressTimerView extends StatefulWidget {
  final int durationMillis;
  final int remainMillis;
  final double? size;
  final Color? background;
  final Color? color;

  const CircularProgressTimerView({
    required this.durationMillis,
    required this.remainMillis,
    this.size = 80,
    this.background,
    this.color,
    super.key,
  });

  @override
  State<CircularProgressTimerView> createState() =>
      _CircularProgressTimerViewState();
}

class _CircularProgressTimerViewState extends State<CircularProgressTimerView> {
  Timer? timerId;

  // 표시에 사용할 초 단위 값 계산
  int get displaySeconds => (widget.remainMillis / 1000).ceil();

  // 진행률 계산 (0~1 사이 값)
  double get progressRatio => math.max(
      0,
      math.min(1,
          widget.remainMillis.toDouble() / widget.durationMillis.toDouble()));

  void _startTimer() {
    timerId?.cancel();

    // 100ms마다 화면 갱신
    timerId = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant CircularProgressTimerView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    timerId?.cancel();
    super.dispose();
  }

  Color getColorByProgress(num timeRatio) {
    if (timeRatio <= 0) return Colors.red;
    if (timeRatio > 0.7) return Colors.green;

    return Color.lerp(
            Colors.red, // 시간이 적게 남았을 때
            Colors.green, // 시간이 많이 남았을 때
            timeRatio.toDouble()) ??
        Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = getColorByProgress(progressRatio);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.background ?? Colors.black,
      ),
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 100,
            showLabels: false,
            showTicks: false,
            isInversed: true,
            startAngle: 270,
            endAngle: 270,
            axisLineStyle: AxisLineStyle(
              thickness: 0.1,
              color: const Color.fromARGB(255, 56, 67, 77),
              thicknessUnit: GaugeSizeUnit.factor,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: 100 * progressRatio,
                width: 0.1,
                sizeUnit: GaugeSizeUnit.factor,
                color: color,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$displaySeconds',
                      style: AppTheme.num20.copyWith(
                        fontSize: math.max(widget.size! * 0.4, 30),
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -10),
                      child: Text(
                        'SEC',
                        style: TextStyle(
                          fontSize: math.max(widget.size! * 0.1, 10),
                          color: Colors.orange[200],
                        ),
                      ),
                    ),
                  ],
                ),
                positionFactor: 0.1,
                angle: 90,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
