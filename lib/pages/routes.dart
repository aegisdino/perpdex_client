import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'main_page.dart';

class AppRouter {
  static final _mainScreenKey = GlobalKey<MainScreenState>();

  static final GoRouter router = GoRouter(
    debugLogDiagnostics: kDebugMode, // 디버그 모드에서 라우팅 로그 출력
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) {
          return MaterialPage(
            key: ValueKey('main'),
            child: MainScreen(key: _mainScreenKey),
          );
        },
        routes: [],
      ),
    ],
    // 경로를 찾을 수 없을 때
    errorBuilder: (context, state) {
      print("ROUTE WAS NOT FOUND !!!");
      return Scaffold(
        body: Center(
          child: Text('페이지를 찾을 수 없습니다'),
        ),
      );
    },
  );
}
