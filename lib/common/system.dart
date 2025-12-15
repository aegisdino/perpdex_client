import 'dart:io' as io if (dart.library.html) 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void exitProcess() {
  if (kIsWeb) {
    return;
  } 
  if (io.Platform.isAndroid) {
    SystemNavigator.pop();
    Future.delayed(Duration(milliseconds: 100), () {
      io.exit(0);
    });
  } else {
    io.exit(0);
  }
}
