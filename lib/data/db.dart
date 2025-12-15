import 'dart:async';
import 'package:flutter/foundation.dart';

import '/platform/sqlite_native.dart'
    if (dart.library.html) '/platform/sqlite_web.dart';
import 'datadb.dart';

export 'datadb.dart';

const String _mainDBName = "data.db";

class MainDB extends SqliteImpl {
  MainDB._();

  static final MainDB _db = MainDB._();
  factory MainDB() => _db;

  Future init() async {
    // main db
    await initDB(
      _mainDBName,
      onOpen: (db) async {
        await checkCreateTables();
      },
    );

    await loadData();
  }

  Future checkCreateTables() async {
    var futures = <Future>[];
    List<String> initcmds = [];

    if (initcmds.isNotEmpty) {
      for (var cmd in initcmds) {
        futures.add(execute(cmd));
      }
      try {
        await Future.wait(futures);
      } catch (e) {
        debugPrint('checkCreateTables: exception $e');
        if (e.toString().contains('malformed')) {
          await checkCreateTables();
          return;
        }
      }
    }

    final indexCmds = [];

    futures = [];

    if (indexCmds.isNotEmpty) {
      for (var cmd in indexCmds) {
        futures.add(execute(cmd).onError((error, stackTrace) => null));
      }
      await Future.wait(futures);
    }

    debugPrint('checkCreateTable: tables for $_mainDBName created');
  }

  Future clearCache() async {
    await DataDB().clearCache();

    debugPrint('clearCache: cleared');
  }

  Future loadData() async {}
}
