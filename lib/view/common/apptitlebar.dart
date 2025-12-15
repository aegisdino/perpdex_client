import 'package:flutter/material.dart';

import '/api/netclient.dart';
import '/common/theme.dart';

class AppTitleBar extends StatelessWidget {
  final String? title;
  final Function()? onMenuPressed;
  const AppTitleBar({this.title, this.onMenuPressed, Key? key})
      : super(key: key);

  static const String appVersion = 'v23.07.18.1';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppTheme.background,
      child: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: title != null ? _buildTitleAppBar() : _buildImageAppBar(),
      ),
    );
  }

  Widget _buildTitleAppBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset(
                'assets/logo/white.png',
                height: 35,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                title!,
                style: TextStyle(color: AppTheme.primary, fontSize: 20),
              ),
            ],
          ),
          if (onMenuPressed != null)
            Positioned(
              right: 5,
              top: 5,
              child: InkWell(
                onTap: onMenuPressed,
                child: Icon(
                  Icons.menu,
                  color: AppTheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageAppBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/logo/bar_white.png',
                  height: 35, color: AppTheme.primary),
            ],
          ),
          Positioned(
            right: 5,
            top: 20,
            child: Text(
              appVersion,
              style: TextStyle(
                color: AppTheme.onPrimary,
                fontSize: 8,
              ),
            ),
          ),
          if (ServerAPI().isOfflineMode)
            const Positioned(
                top: 0,
                right: 5,
                child: Icon(
                  Icons.wifi_off,
                  color: Colors.red,
                ))
        ],
      ),
    );
  }
}
