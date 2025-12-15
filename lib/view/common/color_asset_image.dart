import 'package:flutter/material.dart';

class ColoredAssetImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final Color? color;

  const ColoredAssetImage(this.imagePath,
      {this.width, this.height, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0
      ]),
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        color: color ?? Colors.grey,
        colorBlendMode: BlendMode.modulate,
      ),
    );
  }
}
