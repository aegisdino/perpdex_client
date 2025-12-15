import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/config.dart';
import '/platform/platform.dart';

class AppPackage {
  static String pkgName = '';
  static String pkgVersion = '';
  static String buildNumber = '';

  static Map<String, String> tagNameMap = {
    'spoon': 'spoon',
  };

  static Future loadPackageInfo() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String appName = '';

    if (kIsWeb) {
      String url = getWindowLocation();

      for (var item in tagNameMap.entries) {
        if (url.contains(item.key)) {
          pkgName = item.value;
          break;
        }
      }
      appName = pkgName;
    } else {
      pkgName = packageInfo.packageName;
      pkgVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
      appName = pkgName.split('.').last;
    }

    if (Config.appConfig.containsKey(appName))
      Config.current = Config.appConfig[appName]!;

    if (kIsWeb) {
      pkgVersion = Config.current.version ?? '';
    }
  }
}
