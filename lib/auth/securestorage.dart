import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/platform/platform.dart';

class SecureStorage {
  factory SecureStorage() => _instance;
  SecureStorage._();
  static final SecureStorage _instance = SecureStorage._();
  static SecureStorage get instance => _instance;

  List<String> allStorageKeys = [
    'GApasscode',
  ];

  final storage = const FlutterSecureStorage();
  SharedPreferences? prefs;
  String prefix = '';

  void setAccountId(int userSeqno_) {
    prefix = '$userSeqno_.';
  }

  Future<void> init() async {
    if (prefs != null) return;
    prefs = await SharedPreferences.getInstance();
    final firstrunDate = prefs!.getString('first_run_date');
    if (firstrunDate == null) {
      await clearAllKeys();
      prefs!.setString('first_run_date', DateTime.now().toString());
    }
  }

  Future clearAllKeys() async {
    // SecureStorage에서 삭제
    await Future.wait(
        allStorageKeys.map((key) => storage.delete(key: '$prefix$key')));
  }

  Future<String?> getString(
    String key_, {
    bool useNoPrefix = false,
  }) async {
    final key = useNoPrefix ? key_ : '$prefix$key_';

    // SecureStorage 우선 시도, 없으면 SharedPreferences
    String? value = await SecureStorageImpl.read(key: key);
    value ??= prefs!.getString(key);
    return value;
  }

  Future setString(
    String key_,
    String value, {
    bool useNoPrefix = false,
  }) async {
    final key = useNoPrefix ? key_ : '$prefix$key_';

    await SecureStorageImpl.write(key: key, value: value);
  }
}
