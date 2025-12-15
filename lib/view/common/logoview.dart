import 'package:flutter/material.dart';
import 'package:decorated_text/decorated_text.dart';

import '../../common/theme.dart';
import '../../config/config.dart';

class LogoView extends StatelessWidget {
  final double? height;
  final String? path;
  final Color? color;
  const LogoView({this.height, this.path, this.color, Key? key})
    : super(key: key);

  Widget _buildLogo() {
    if (path != null || Config.current.logo.endsWith('.png')) {
      return Image.asset(
        'assets/logo/${path ?? Config.current.logo}',
        height: height ?? Config.current.logoSize,
        fit: BoxFit.contain,
        color: color,
      );
    } else {
      return SizedBox(
        height: height ?? Config.current.logoSize,
        child: DecoratedText(
          Config.current.logo,
          borderColor: Colors.amber,
          borderWidth: 3,
          fontSize: ((height ?? 60) * 0.6),
          fontWeight: FontWeight.w800,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 3)),
          ],
          fillGradient: LinearGradient(
            colors: [
              AppTheme.colorScheme.primary,
              AppTheme.colorScheme.secondary,
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildLogo();
  }
}
