import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchronized/synchronized.dart';

class SqliteImpl {
  // only the first db should be writable
  final List<Database> _databases = [];

  Future<String> getDbPath(String dbName) async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, dbName);
  }

  Future<Database?> initDB(
    String dbName, {
    Function(Database)? onOpen,
    bool? fromAssetDB,
    String? dbCopyDate,
  }) async {
    // 모바일이 아닌 경우는 ffi 사용해야 함
    // linux: libsqlite3 and libsqlite3-dev linux packages are required.
    //        sudo apt-get -y install libsqlite3-0 libsqlite3-dev
    // windows: sqlite3.dll is bundled and should be copied to the same folder in release mode
    // mac: work as is
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();

    if (fromAssetDB == true) {
      await copyAssetDB(dbName, dbPath, dbName + (dbCopyDate ?? ''));
    }

    String path = join(dbPath, dbName);
    try {
      final db = await openDatabase(
        path,
        version: 1,
        onOpen: (db) async {
          _databases.add(db);
          debugPrint('initDB: opened $path');
        },
      );
      await onOpen?.call(db);
      debugPrint('sqlite_mobile.initDB done');
      return db;
    } catch (e, s) {
      debugPrint('initDB: exception $e, $s');
      return null;
    }
  }

  Future deleteDB(String dbName, {String? dbCopyDate}) async {
    final path = await getDbPath(dbName + (dbCopyDate ?? ''));
    final fp = File(path);
    try {
      await fp.delete();
      debugPrint('sqlite_mobile: $path deleted');
    } catch (e) {
      debugPrint('sqlite_mobile: deleteDB exception $e');
    }
  }

  Future execute(String query,
      {List<Object?> params = const [], Database? db}) async {
    db ??= _databases.isNotEmpty ? _databases.first : null;
    await db?.execute(query, params);
  }

  Future<int> rawInsert(String query, {List<Object?> params = const []}) async {
    return await _databases.first.rawInsert(query, params);
  }

  Future executeMultiple(String query, List<List<dynamic>> params) async {
    final batch = _databases.first.batch();
    for (var p in params) {
      batch.rawQuery(query, p);
    }
    await batch.commit();
  }

  Future select(String query, List<dynamic> params, {Database? db}) async {
    db ??= _databases.isNotEmpty ? _databases.first : null;
    if (db == null) debugPrint('select: database is not initialized');
    return await db?.rawQuery(query, params);
  }

  void closeDB() {
    for (var db in _databases) {
      db.close();
    }
  }

  // 배치를 만들어서 주기적으로 몰아서 커밋을 하도록 한다.
  Batch? _logBatch;
  final _batchLock = Lock();

  Future get logBatch async {
    if (_logBatch != null) return _logBatch;
    _logBatch = _databases.first.batch();
    return _logBatch;
  }

  // synchronized version of commitBatch
  Future commitBatch() async {
    await _batchLock.synchronized(() {
      _commitBatch();
    });
  }

  void _commitBatch({bool force = false}) {
    commitTimer?.cancel();
    if (_logBatch != null) {
      _logBatch!.commit();
    }
  }

  Timer? commitTimer;

  void _armDelayedCommit({int delaySeconds = 5}) {
    commitTimer?.cancel();
    commitTimer = Timer(Duration(seconds: delaySeconds), () {
      commitBatch();
    });
  }

  Future batchQuery(String query, List<dynamic> params, bool commit) async {
    if (commit) {
      await execute(query, params: params);
    } else {
      final batch = await logBatch;
      await _batchLock.synchronized(() {
        batch.rawQuery(query, params);
        if (commit) {
          _commitBatch(force: true);
        } else {
          _armDelayedCommit();
        }
      });
    }
  }

  Future copyAssetDB(String assetDb, String dbPath, String? dbFileName) async {
    String path = join(dbPath, dbFileName ?? assetDb);

    // Only copy if the database doesn't exist
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      // Load database from asset and copy
      ByteData data = await rootBundle.load(join('assets/data', assetDb));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Save copied asset to documents
      await File(path).writeAsBytes(bytes);

      debugPrint('copyAssetDB: $assetDb -> $path');
    } else {
      debugPrint('copyAssetDB: $assetDb already exists');
    }
  }
}
