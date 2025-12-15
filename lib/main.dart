import 'dart:async';
import 'dart:core';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '/game/websocket_client.dart';

import '/data/package.dart';
import '/data/providers.dart';
import '/pages/routes.dart';
import '/common/all.dart';
import '/common/image_cache_config.dart';
import '/wallet/wallet.dart';
import 'auth/authmanager.dart';
import 'data/data.dart';
import 'data/localization.dart';

Future _main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: reown_appkit는 Web에서 webview 없이 작동함
  // Web에서는 iframe 기반으로 자체 처리

  // Configure wallet authentication mode
  // 서버 모드: 프로덕션용 (서버와 nonce 연동)
  AuthService.configure(mode: AuthMode.server);

  // 클라이언트 모드: 개발/프로토타입용 (서버 없이 로컬에서만 검증)
  // AuthService.configure(mode: AuthMode.client);

  // Configure image cache settings
  ImageCacheConfig.configureCachedNetworkImage();

  initPlatform();

  // 출력을 디버그 모드에서만 하게
  debugPrint = (String? message, {int? wrapWidth}) {
    if (kDebugMode) {
      DateTime now = DateTime.now();
      String timeStr = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}.${now.millisecond}';
      debugPrintThrottled('[$timeStr] $message', wrapWidth: wrapWidth);
    }
  };

  FlutterError.onError = (details) {
    if (details.exception.toString().contains('disposed EngineFlutterView')) {
      // 이 에러는 무시
      return;
    }
    FlutterError.presentError(details);
  };

  List<Future> futures = [
    AppPackage.loadPackageInfo(),
    EasyLocalization.ensureInitialized(),
    Localization.init(null),
  ];
  await Future.wait(futures);

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: Localization.supportedLangs.map((e) {
          final vals = e.split('-');
          return vals.length == 2 ? Locale(vals[0], vals[1]) : Locale(e);
        }).toList(),
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        child: const MyApp(),
      ),
    ),
  );
}

Future<void> main() async {
  runZonedGuarded(() async {
    _main();
  }, (error, stack) {
    hideLoading();

    debugPrint('$error, $stack');
    //Util.showAlert('${stack}', title: '예외 발생: ${error.toString()}');
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    AppLifecycleManager.instance.initialize(onVisibilityChange: (isHidden) {
      if (isHidden) {
        AuthManager().pause();
      } else {
        AuthManager().resume();
      }
    }, onBeforeUnload: () {
      WebsocketClient().disconnect();
    });
  }

  @override
  void dispose() {
    AppLifecycleManager.resetInstance();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: uncontrolledContainer,
      child: MaterialApp.router(
        title: 'Perp Dex',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: AppRouter.router,
        theme: AppTheme.getTheme(),
        darkTheme: AppTheme.getDarkTheme(),
        themeMode: ThemeMode.dark,
        color: Colors.black,
        builder: (context, child) {
          final MediaQueryData data = MediaQuery.of(context);
          AppTheme.updateScheme(context);
          return StreamBuilder<DateTime?>(
            stream: DataManager().dataChangeNotifyStream.stream,
            builder: (context, snapshot) {
              return MediaQuery(
                data: data.copyWith(
                    textScaler: TextScaler.linear(DataManager().textScale)),
                child: child!,
              );
            },
          );
        },
        debugShowCheckedModeBanner: false,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown
          },
        ),
      ),
    );
  }
}
