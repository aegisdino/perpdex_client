import 'package:flutter/material.dart';

import '/common/theme.dart';

Widget buildCheckBox(
  Widget content,
  bool checked,
  Function(bool?) onChanged, {
  double? maxWidth,
  bool? circle,
  Color? fillColor,
  Color? checkColor,
  double? scale,
}) {
  Color _fillColor = (fillColor ??
      (checked
          ? AppTheme.colorScheme.primary
          : AppTheme.colorScheme.onPrimary));
  Color _checkColor = checkColor ?? AppTheme.getMatchingTextColor(_fillColor);

  return Container(
    constraints: BoxConstraints(
      maxWidth: maxWidth ?? double.infinity,
    ),
    child: Row(
      spacing: 8,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Transform.scale(
          scale: scale ?? 1.0,
          child: Checkbox(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 터치 영역 축소
            visualDensity:
                const VisualDensity(horizontal: -4, vertical: -4), // 더 얇게
            value: checked,
            shape: circle == true
                ? const CircleBorder()
                : const ContinuousRectangleBorder(),
            onChanged: onChanged,
            side: checked ? const BorderSide(width: 0) : null,
            fillColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return _fillColor.withOpacity(.32);
              }
              return _fillColor;
            }),
            activeColor: _fillColor,
            checkColor: _checkColor,
          ),
        ),
        InkWell(
          onTap: () {
            onChanged(!checked);
          },
          child: content,
        )
      ],
    ),
  );
}
