import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/auth/authmanager.dart';

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

    // 모바일: AppLifecycleState 사용
    WidgetsBinding.instance.addObserver(this);
  }

  // 모바일용 생명주기 핸들러
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 웹이 아닐 때만 처리
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      onVisibilityChange?.call(true);
      //_onPauseApp();
    } else if (state == AppLifecycleState.resumed) {
      onVisibilityChange?.call(false);
      //_onResumeApp();
    }
  }

  // 현재 앱이 숨겨져 있는지 확인
  bool get isAppHidden {
    // 모바일에서는 다른 방식으로 확인 (필요시 구현)
    return false;
  }

  void dispose() {
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _isInitialized = false;
  }
}
