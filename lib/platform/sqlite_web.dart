import 'package:flutter/foundation.dart';
import 'package:sqlite3/wasm.dart';

class SqliteImpl {
  CommonDatabase? _databaseWeb;

  bool webSupportEnabled = false;

  Future<CommonDatabase?> initDB(
    String dbName, {
    Function? onOpen,
    bool? fromAssetDB,
    String? dbCopyDate,
  }) async {
    try {
      final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      sqlite3.registerVirtualFileSystem(
        await IndexedDbFileSystem.open(dbName: dbName),
        makeDefault: true,
      );

      _databaseWeb = sqlite3.open(dbName);
      await onOpen?.call(_databaseWeb);
      debugPrint('sqlite_web.initDB done');
      return _databaseWeb!;
    } catch (e, s) {
      //debugPrint('sqlite_web.initDB: ${dbName}, exception $e');
      return null;
    }
  }

  Future deleteDB(
    String dbName, {
    String? dbCopyDate,
  }) async {
    try {
      await IndexedDbFileSystem.deleteDatabase(dbName);
    } catch (e) {
      debugPrint('sqlite_web.deleteDB: exception $e');
    }
  }

  Future execute(String query, {List<Object?> params = const []}) async {
    if (webSupportEnabled) _databaseWeb!.execute(query, params);
  }

  Future<int> rawInsert(String query, {List<Object?> params = const []}) async {
    final stmt = _databaseWeb!.prepare(query);
    stmt.execute(params);
    stmt.dispose();

    final row = _databaseWeb!.select('SELECT last_insert_rowid() as id');
    return row.first['id'];
  }

  Future select(String query, List<dynamic> params) async {
    return _databaseWeb!.select(query, params);
  }

  Future executeMultiple(String query, List<List<dynamic>> params) async {
    if (webSupportEnabled) {
      final stmt = _databaseWeb!.prepare(query);
      params.forEach((p) {
        stmt.execute(p);
      });
      stmt.dispose();
    }
  }

  void closeDB() {
    _databaseWeb?.dispose();
  }

  void commitBatch() {}

  Future batchQuery(String query, List<dynamic> params, bool commit) async {
    if (webSupportEnabled) {
      final stmt = _databaseWeb!.prepare(query);
      stmt.execute(params);
      stmt.dispose();
    }
  }
}
