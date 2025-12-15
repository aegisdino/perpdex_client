import '/common/util.dart';
import 'package:flutter/material.dart';

class CircleIconButton extends StatelessWidget {
  final Icon icon;
  final String? text;
  final Function()? onTap;
  final Color? color;
  final double buttonSize;

  const CircleIconButton({
    required this.icon,
    this.text,
    this.color,
    this.onTap,
    this.buttonSize = 50,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color ?? AppTheme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          if (text != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: SizedBox(
                width: 50,
                child: FittedBox(
                  child: Text(
                    text!,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
