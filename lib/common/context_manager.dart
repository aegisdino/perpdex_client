import 'package:flutter/material.dart';

class ContextManager {
  static final navKey = GlobalKey<NavigatorState>();
  static List<GlobalKey<ScaffoldState>> scaffoldStack = [];

  static void pushScaffold(GlobalKey<ScaffoldState> key) {
    scaffoldStack.add(key);
  }

  static void popScaffold(GlobalKey<ScaffoldState> key) {
    scaffoldStack.remove(key);
  }

  static GlobalKey<ScaffoldState>? get scaffold {
    return scaffoldStack.isNotEmpty ? scaffoldStack.last : null;
  }

  static BuildContext? getTopBuildContext() {
    if (scaffoldStack.isNotEmpty) {
      return scaffoldStack.first.currentContext ?? null;
    } else {
      return (navKey.currentState != null &&
              navKey.currentState!.overlay != null)
          ? navKey.currentState!.overlay!.context
          : null;
    }
  }

  static BuildContext? get buildContext {
    if (scaffoldStack.isNotEmpty) {
      return scaffoldStack.last.currentContext ?? null;
    } else {
      return (navKey.currentState != null &&
              navKey.currentState!.overlay != null)
          ? navKey.currentState!.overlay!.context
          : null;
    }
  }
}
