import 'package:flutter/material.dart';

import '../../common/styles.dart';
import '../../common/theme.dart';

class TitleContentWidget extends StatelessWidget {
  final double? titleWidth;
  final double? inputWidth;
  final String titleText;
  final Widget inputWidget;
  final Color? titleColor;
  final TextStyle? titleStyle;
  final bool verticalCenterAlign;
  final bool intrinsicSize;
  final Axis direction; // New parameter for layout direction

  const TitleContentWidget(
    this.titleText,
    this.inputWidget, {
    this.titleWidth,
    this.inputWidth,
    this.titleColor,
    this.titleStyle,
    this.verticalCenterAlign = false,
    this.intrinsicSize = true,
    this.direction = Axis.horizontal, // Default to horizontal (Row)
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: direction == Axis.horizontal
            ? (inputWidth == null || intrinsicSize == false
                ? _buildRow()
                : IntrinsicWidth(child: _buildRow()))
            : (intrinsicSize == false
                ? _buildColumn()
                : IntrinsicHeight(child: _buildColumn())),
      ),
    );
  }

  Widget _buildRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: verticalCenterAlign == true
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: titleWidth,
          child: MyStyledText(
            titleText,
            textAlign: TextAlign.center,
            style: titleStyle ??
                TextStyle(
                  fontWeight: FontWeight.bold,
                  color: titleColor ?? AppTheme.onBackground[100],
                ),
          ),
        ),
        if (inputWidth != null)
          SizedBox(
            width: inputWidth,
            child: inputWidget,
          )
        else
          Expanded(
            // Flexible 대신 Expanded 사용
            child: inputWidget,
          ),
      ],
    );
  }

  Widget _buildColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: verticalCenterAlign == true
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MyStyledText(
          titleText,
          style: titleStyle ??
              TextStyle(
                fontWeight: FontWeight.bold,
                color: titleColor ?? AppTheme.onBackground[100],
              ),
        ),
        SizedBox(height: 8),
        if (inputWidth != null)
          SizedBox(
            width: inputWidth, // Use inputWidth as height
            child: inputWidget,
          )
        else
          Expanded(
            child: inputWidget,
          ),
      ],
    );
  }
}
