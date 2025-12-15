import 'dart:ui';

import 'package:flutter/material.dart';

class CenterToCornerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double? endFontSize;
  final double? endY;
  final double? centerCircleSize;
  final int animationCount;
  final Duration centerDuration;
  final Duration moveDuration;
  final Offset leftTopOffset;
  final GlobalKey parentKey; // parent widget의 key

  const CenterToCornerText({
    required this.text,
    required this.style,
    required this.parentKey,
    required this.animationCount,
    this.endFontSize = 12,
    this.endY = 10,
    this.centerCircleSize = 100,
    this.centerDuration = const Duration(seconds: 1),
    this.moveDuration = const Duration(milliseconds: 500),
    this.leftTopOffset = const Offset(5, 5),
  });

  @override
  State<CenterToCornerText> createState() => _CenterToCornerTextState();
}

class _CenterToCornerTextState extends State<CenterToCornerText>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fontSizeAnimation;

  Size get parentSize {
    try {
      final RenderBox? renderBox =
          widget.parentKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox?.hasSize ?? false) return renderBox!.size;
      return Size.zero;
    } catch (e) {
      return Size.zero;
    }
  }

  Size measureText(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    return textPainter.size;
  }

  @override
  void initState() {
    super.initState();

    final originalFontSize = widget.style.fontSize ?? 14.0;
    _initAnimation(originalFontSize);
  }

  void _initAnimation(double originalFontSize) {
    _controller = AnimationController(
      duration: widget.moveDuration,
      vsync: this,
    );

    _fontSizeAnimation = Tween<double>(
      begin: originalFontSize,
      end: widget.endFontSize,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(widget.centerDuration, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(CenterToCornerText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animationCount != oldWidget.animationCount) {
      _controller.stop();
      _controller.dispose();

      final originalFontSize = widget.style.fontSize ?? 14.0;
      _initAnimation(originalFontSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final widgetSize = parentSize;
    Size currentTextSize = Size.zero;
    double fontSize = _fontSizeAnimation.value;

    if (widget.text.length > 0) {
      while (fontSize > widget.endFontSize!) {
        currentTextSize =
            measureText(widget.text, widget.style.copyWith(fontSize: fontSize));

        if (widgetSize.width - 40 < currentTextSize.width) {
          fontSize -= 1.0;
          continue;
        }
        break;
      }
    }

    final startX = (widgetSize.width - currentTextSize.width) / 2;
    final endX = 10.0;

    final startY = (widgetSize.height - currentTextSize.height) / 2;
    final endY = widget.endY ?? 10.0;

    final x = lerpDouble(startX, endX, _controller.value) ?? startX;
    final y = lerpDouble(startY, endY, _controller.value) ?? startY;

    return Positioned(
      left: x,
      top: y,
      child: (_controller.value < 1.0)
          ? Text(
              widget.text,
              style: widget.style.copyWith(
                fontSize: fontSize,
              ),
            )
          : SizedBox(
              width: (widgetSize.width - (widget.centerCircleSize ?? 100)) / 2,
              child: Text(
                widget.text,
                style: widget.style.copyWith(
                  fontSize: fontSize,
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
