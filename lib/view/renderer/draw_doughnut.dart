import 'package:flutter/material.dart';

class DonutWidget extends StatelessWidget {
  final Color? color;
  final double? innerRadius;
  DonutWidget({this.color, this.innerRadius, Key? key}) : super(key: key);

  Widget build(BuildContext context) {
    return Container(
        child: CustomPaint(
      child: Container(),
      painter: DonutChartPainter(
          color: color ?? Colors.blue, innerRadius: innerRadius),
    ));
  }
}

class DonutChartPainter extends CustomPainter {
  final Color color;
  double? innerRadius;

  DonutChartPainter({
    required this.color,
    this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final c = Offset(size.width / 2.0, size.height / 2.0);
    if (innerRadius == null) innerRadius = (size.width / 2) * 0.7;

    canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: size.width / 2)),
          Path()
            ..addOval(Rect.fromCircle(center: c, radius: innerRadius!))
            ..close(),
        ),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
