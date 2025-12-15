import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/platform/sqlite_native.dart'
    if (dart.library.html) '/platform/sqlite_web.dart';

const String _dataDBName = "datadb.db";
const String _dbCopyDateKey = "db_copy_date";

class DataDB extends SqliteImpl {
  DataDB._();

  static final DataDB _db = DataDB._();
  factory DataDB() => _db;

  Future init() async {
    // update db copy date
    final dbCopyDate = await updateDBCopyDate();

    // bus db
    await initDB(
      _dataDBName,
      fromAssetDB: true,
      dbCopyDate: dbCopyDate,
    );

    debugPrint('DataDB.init: done');
  }

  Future clearCache() async {}

  Future<String> updateDBCopyDate() async {
    final pref = await SharedPreferences.getInstance();
    String? dbCopyDate = pref.getString(_dbCopyDateKey);
    if (dbCopyDate == null) {
      dbCopyDate = DateFormat('yyyyMMddHHss').format(DateTime.now());
      pref.setString(_dbCopyDateKey, dbCopyDate);
    }
    return dbCopyDate;
  }
}
