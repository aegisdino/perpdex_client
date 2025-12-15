import 'package:flutter/material.dart';
import 'package:styled_text/styled_text.dart';

import 'theme.dart';

export 'package:styled_text/styled_text.dart';

class MyStyledText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final double? height;
  final Color? color;
  final TextAlign? textAlign;
  final TextStyle? style;
  final Map<String, StyledTextTagBase>? addStyles;
  final TextOverflow? overflow;

  const MyStyledText(
    this.text, {
    this.fontSize,
    this.height,
    this.color,
    this.textAlign,
    this.style,
    this.addStyles,
    this.overflow,
    key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, StyledTextTagBase>? newStyles;
    if (addStyles != null) {
      newStyles = {};
      newStyles.addAll(defaultStyles);
      newStyles.addAll(addStyles!);
    }
    return StyledText(
      text: text,
      style:
          style ??
          TextStyle(
            fontSize: fontSize,
            color: color ?? AppTheme.colorScheme.onSurface,
          ),
      textAlign: textAlign ?? TextAlign.left,
      tags: newStyles ?? defaultStyles,
      newLineAsBreaks: true,
      overflow: overflow ?? TextOverflow.fade,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }
}

Map<String, StyledTextTagBase> defaultStyles = {
  'u': StyledTextTag(
    style: const TextStyle(decoration: TextDecoration.underline),
  ),
  'bold': StyledTextTag(style: const TextStyle(fontWeight: FontWeight.bold)),
  'b': StyledTextTag(style: const TextStyle(fontWeight: FontWeight.bold)),
  'i': StyledTextTag(style: const TextStyle(fontStyle: FontStyle.italic)),
  'large': StyledTextTag(style: const TextStyle(fontSize: 16)),
  'sm': StyledTextTag(style: const TextStyle(fontSize: 9)),
  'esm': StyledTextTag(style: const TextStyle(fontSize: 7)),
  'md': StyledTextTag(style: const TextStyle(fontSize: 11)),
  'nm': StyledTextTag(style: const TextStyle(fontSize: 13)),
  'f50': StyledTextTag(style: const TextStyle(fontSize: 50)),
  'f40': StyledTextTag(style: const TextStyle(fontSize: 40)),
  'f30': StyledTextTag(style: const TextStyle(fontSize: 30)),
  'f24': StyledTextTag(style: const TextStyle(fontSize: 24)),
  'f20': StyledTextTag(style: const TextStyle(fontSize: 20)),
  'f18': StyledTextTag(style: const TextStyle(fontSize: 18)),
  'f16': StyledTextTag(style: const TextStyle(fontSize: 16)),
  'f15': StyledTextTag(style: const TextStyle(fontSize: 15)),
  'f14': StyledTextTag(style: const TextStyle(fontSize: 14)),
  'f13': StyledTextTag(style: const TextStyle(fontSize: 13)),
  'f12': StyledTextTag(style: const TextStyle(fontSize: 12)),
  'f11': StyledTextTag(style: const TextStyle(fontSize: 11)),
  'f10': StyledTextTag(style: const TextStyle(fontSize: 10)),
  'f9': StyledTextTag(style: const TextStyle(fontSize: 9)),
  'red': StyledTextTag(style: const TextStyle(color: Colors.red)),
  'blue': StyledTextTag(style: const TextStyle(color: Colors.blue)),
  'green': StyledTextTag(style: const TextStyle(color: Colors.green)),
  'orange': StyledTextTag(style: const TextStyle(color: Colors.orange)),
  'yellow': StyledTextTag(style: const TextStyle(color: Colors.yellow)),
  'grey8': StyledTextTag(style: TextStyle(color: Colors.grey[800])),
  'grey': StyledTextTag(style: const TextStyle(color: Colors.grey)),
  'w': StyledTextTag(style: const TextStyle(color: Colors.white)),
  'sales': StyledTextTag(style: TextStyle(fontSize: 8, color: Colors.red[800])),
  'b8': StyledTextTag(style: TextStyle(color: Colors.blue[800])),
  'g8': StyledTextTag(style: TextStyle(color: Colors.green[800])),
  'o8': StyledTextTag(style: TextStyle(color: Colors.orange[800])),
  'b5': StyledTextTag(style: TextStyle(color: Colors.blue[500])),
  'g5': StyledTextTag(style: TextStyle(color: Colors.green[500])),
  'o5': StyledTextTag(style: TextStyle(color: Colors.orange[500])),
  'y5': StyledTextTag(style: TextStyle(color: Colors.yellow[500])),
  'erase': StyledTextTag(
    style: const TextStyle(decoration: TextDecoration.lineThrough),
  ),
  'error': StyledTextTag(style: TextStyle(color: AppTheme.colorScheme.error)),
  'primary': StyledTextTag(
    style: TextStyle(color: AppTheme.colorScheme.primary),
  ),
  'secondary': StyledTextTag(
    style: TextStyle(color: AppTheme.colorScheme.secondary),
  ),
  'onPrimary': StyledTextTag(
    style: TextStyle(color: AppTheme.colorScheme.onPrimary),
  ),
  'onSecondary': StyledTextTag(
    style: TextStyle(color: AppTheme.colorScheme.onSecondary),
  ),
  'onBackground': StyledTextTag(
    style: TextStyle(color: AppTheme.colorScheme.onSurface),
  ),
};
