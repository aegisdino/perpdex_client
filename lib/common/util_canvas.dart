import 'dart:math';

import 'package:flutter/painting.dart';

Offset degreeToPoint(num degree, num radius, Offset center) {
  degree = degreesToRadians(degree);
  return Offset(
      center.dx + cos(degree) * radius, center.dy + sin(degree) * radius);
}

/// Convert degree to radian
num degreesToRadians(num deg) {
  return deg * (pi / 180);
}
