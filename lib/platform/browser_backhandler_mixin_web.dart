import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'js_interop_import.dart';

mixin BrowserBackHandlerMixin<T extends StatefulWidget> on State<T> {
  JSFunction? _popstateListener;

  void setupBrowserBackHandler() {
    if (kIsWeb) {
      _popstateListener = (JSAny event) {
        if (mounted) {
          context.pop();
        }
      }.toJS;

      window.addEventListener('popstate', _popstateListener!);
    }
  }

  void disposeBrowserBackHandler() {
    if (kIsWeb && _popstateListener != null) {
      window.removeEventListener('popstate', _popstateListener!);
    }
  }
}
