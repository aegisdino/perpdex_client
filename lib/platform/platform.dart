export 'platform_mobile.dart' if (dart.library.html) 'platform_web.dart';
export 'navigation_mobile.dart' if (dart.library.html) 'navigation_web.dart';
export 'browser_backhandler_mixin_mobile.dart'
    if (dart.library.html) 'browser_backhandler_mixin_web.dart';

export 'game_webview_mobile.dart'
    if (dart.library.html) 'game_webview_web.dart';

export 'app_lifecycle_manager_mobile.dart'
    if (dart.library.html) 'app_lifecycle_manager_web.dart';

//export 'package:google_maps_flutter/google_maps_flutter.dart';
//export 'package:naver_map_plugin/naver_map_plugin.dart';
