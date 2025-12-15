import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/securestorage.dart';
import '../config/server_config.dart';
import 'account.dart';
import 'data.dart';
import 'localization.dart';

class InitManager {
  static Future? configLoadFuture;
  static DateTime? startTime;
  static Completer initCompleter = new Completer();

  static Future startCheckApp(BuildContext context) async {
    if (startTime != null) return;

    startTime = DateTime.now();

    // create clientid/init secure storage
    await SecureStorage().init();
    await ServerConfig.initClientId();

    // load server's config such as aeskey
    configLoadFuture = ServerConfig.loadConfig();

    List<Future> futures = [
      Localization.init(context),
      DataManager().init(context),
      AccountManager().init(),
    ];

    Future.wait(futures).then((v) {
      if (!initCompleter.isCompleted) initCompleter.complete();
    });

    return initCompleter.future;
  }
}
