import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'js_interop_import.dart';

import 'platform.dart';

// 글로벌하게 하나 만들어서 사용
// - main.dart에서 instance를 부르면 됨
// - web에서는 didChangeAppLifecycleState의 사용이 효과적이지 못해서,
//   모바일에서 didChangeAppLifecycleState를 사용하도록 함.

class AppLifecycleManager with WidgetsBindingObserver {
  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance =>
      _instance ??= AppLifecycleManager._();

  AppLifecycleManager._();

  Timer? _pauseTimer;
  bool _isInitialized = false;

  Function(bool isHidden)? onVisibilityChange;
  Function? onBeforeUnload;

  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  void initialize({
    Function(bool isHidden)? onVisibilityChange,
    Function? onBeforeUnload,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;

    if (onVisibilityChange != null) {
      this.onVisibilityChange = onVisibilityChange;
    }
    if (onBeforeUnload != null) {
      this.onBeforeUnload = onBeforeUnload;
    }

    // 웹: visibilitychange 이벤트 사용
    setupVisibilityListener(_onVisibilityChange);

    // beforeUnload ㅗ무읻ㄱ cnrk
    window.addEventListener(
        'beforeunload',
        (JSAny event) {
          onBeforeUnload?.call();
        }.toJS);
  }

  // 웹용 가시성 변경 핸들러
  void _onVisibilityChange(bool isHidden) {
    onVisibilityChange?.call(isHidden);
  }

  // 현재 앱이 숨겨져 있는지 확인
  bool get isAppHidden => web.document.hidden; // web.document.hidden 사용

  void dispose() {
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _isInitialized = false;
  }
}
