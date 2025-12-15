import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:go_router/go_router.dart';

import 'js_interop_import.dart';

export 'package:page_transition/page_transition.dart';

//
// transition
// - PageTransitionType.rightToLeft
// - PageTransitionType.fade
//
Future navigationPush(
  BuildContext context,
  dynamic target, {
  PageTransitionType? transition,
  int? milliseconds,
  Object? extra,
}) async {
  if (target is Widget) {
    // 웹에서 브라우저 히스토리에 상태 추가
    final routeName = '/${target.runtimeType}';
    try {
      final stateObj = <String, String>{'route': routeName}.jsify();
      window.history.pushState(stateObj, routeName, '#$routeName');
    } catch (e) {
      debugPrint('Failed to push browser history: $e');
    }
    return await Navigator.push(
      context,
      transition != null
          ? PageTransition(
              type: transition,
              child: target,
              duration: Duration(milliseconds: milliseconds ?? 100),
              settings: RouteSettings(name: routeName, arguments: extra),
            )
          : MaterialPageRoute(
              builder: (context) => target,
              settings: RouteSettings(name: routeName, arguments: extra),
            ),
    );
  } else {
    // GoRouter를 사용하여 네비게이션
    await context.push(target, extra: extra);
    return null;
  }
}

void navigationPop(
  BuildContext context, {
  Object? result,
}) {
  try {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      debugPrint('navigationPop: Cannot pop, no route to pop');
    }
  } catch (e) {
    debugPrint('navigationPop: exception ${e.toString()}');
  }
}

class MyNavigatorObserver extends NavigatorObserver {
  static final MyNavigatorObserver _singleton =
      new MyNavigatorObserver._internal();
  factory MyNavigatorObserver() {
    return _singleton;
  }
  MyNavigatorObserver._internal() {}
  List<Route<dynamic>> routeStack = [];
  bool get isRoot => routeStack.length == 1;
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.add(route);
  }

  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.removeLast();
  }

  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeStack.removeLast();
  }

  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    routeStack.removeLast();
    if (newRoute != null) routeStack.add(newRoute);
  }
}
