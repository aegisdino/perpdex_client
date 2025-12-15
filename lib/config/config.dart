import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '/common/util.dart';
import '/platform/platform.dart';
import 'env_config.dart';

//String serverTag = 'live';
//String serverTag = 'test';
String serverTag = 'dev';

class Config {
  final String title;
  final String icon;
  final String logo;
  double? logoSize;
  Color? iconbgcolor;
  double? iconSize;
  final String companyName;
  final bool supportNFT;
  final bool supportMultiChain;
  final String? version;
  final Map<String, String>? marketUrl_;
  final Map<String, String> apiHost;
  final Map<String, String>? wsHost_;
  String? routerPrefix;
  final String? walletApiUrl;
  final String? s3Path;

  // Get encryption key from environment or server
  String get encryptKey {
    // Try to get from environment config first
    final envKey = EnvConfig().encryptionKey;
    if (envKey.isNotEmpty) {
      return envKey;
    }

    // For backward compatibility during migration
    // This should be removed once server-side is ready
    if (!kIsWeb) {
      // Mobile can use platform-specific secure storage
      return ''; // Should be loaded from secure storage
    }

    // Web should never have hardcoded keys
    return '';
  }

  Config({
    required this.title,
    required this.icon,
    required this.logo,
    this.logoSize,
    this.iconbgcolor,
    this.iconSize,
    required this.companyName,
    required this.supportNFT,
    required this.supportMultiChain,
    required this.apiHost,
    this.wsHost_,
    this.routerPrefix,
    this.version,
    this.marketUrl_,
    this.walletApiUrl,
    this.s3Path,
  });

  static String getPath(String path) {
    return "${current.routerPrefix}$path";
  }

  static Uri getUri(String path) {
    if (path.startsWith('/')) {
      final uri = Uri.parse(current.apiHost[serverTag]!);
      return Uri.parse(
          "${uri.origin}/${current.routerPrefix}${path.substring(1)}");
    } else {
      return Uri.parse(
          "${current.apiHost[serverTag]}/${current.routerPrefix}$path");
    }
  }

  static String? get wsHost {
    return current.wsHost_?[serverTag];
  }

  String? get marketUrl {
    if (marketUrl_ == null) return null;
    if (isIOS()) {
      return marketUrl_!['ios'];
    } else {
      return marketUrl_!['android'];
    }
  }

  static Config current = appConfig['perpdex']!;

  static Map<String, Config> appConfig = {
    'perpdex': Config(
      title: 'perpdex',
      icon: 'square_logo.png',
      logo: 'square_logo.png',
      iconbgcolor: Colors.transparent,
      logoSize: 70,
      iconSize: 70,
      companyName: 'Anonymous LTD.',
      supportNFT: false,
      supportMultiChain: false,
      version: "20250920.1",
      apiHost: {
        'test': 'https://game.ateon.io:7002/api',
        'dev': 'https://localserver.ateon.io:7002/api',
      },
      wsHost_: {
        'live': 'wss://perpdex.monster/ws',
        'test': 'wss://game.ateon.io:8081',
        'dev': 'wss://localserver.ateon.io:9090',
      },
      routerPrefix: '',
    ),
  };
}

bool isOlderVersion(String serverVersion) {
  final serverValues = serverVersion.split('.');
  final myValues = Config.current.version!.split('.');

  if (serverValues.length == 2 && myValues.length == 2) {
    int myMajor = parseInt(myValues[0]);
    int serverMajor = parseInt(serverValues[0]);

    bool isOlder = myMajor < serverMajor ||
        (myMajor == serverMajor &&
            parseInt(myValues[1]) < parseInt(serverValues[1]));
    return isOlder;
  }
  return false;
}
