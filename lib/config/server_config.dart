import 'package:uuid/uuid.dart';

import '../platform/platform.dart';
import '/api/netclient.dart';
import '/common/util.dart';

class ServerConfig {
  static String? agencyCode; // 웹 링크로 넘어오는 코드
  static String? telegramToken;
  static String chainType = 'mainnet';
  static String coinTicker = 'gold';
  static String? telegramLink;
  static bool referrerEnabled = false;

  static String exchangeRecvAddress = '';
  static int exchangeRate = 1;

  static Map<String, String> version = {};

  static String aesKey = '';

  static String clientId = '';

  static Future initClientId({bool forceNew = false}) async {
    if (clientId.isNullEmptyOrWhitespace || forceNew) {
      // {timestamp}_{deviceId앞8자리}{uuid앞8자리} 형식으로 clientId 생성
      // 서버가 timestamp를 비교하여 이전 연결을 삭제할 수 있음
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceId = (await getDeviceId() ?? '').padRight(8, '0').substring(0, 8);
      final uuid = Uuid().v4().substring(0, 8);

      clientId = '${timestamp}_$deviceId$uuid';

      print('ServerConfig: new clientId ${clientId}');
    }
  }

  /// clientId에서 timestamp 추출
  /// clientId 형식: {timestamp}_{deviceId앞8자리}{uuid앞8자리}
  static int? getTimestampFromClientId(String? id) {
    if (id == null || !id.contains('_')) return null;
    final parts = id.split('_');
    return int.tryParse(parts[0]);
  }

  /// 주어진 clientId가 현재 clientId보다 이전 것인지 확인
  static bool isOlderClientId(String? otherId) {
    final currentTs = getTimestampFromClientId(clientId);
    final otherTs = getTimestampFromClientId(otherId);
    if (currentTs == null || otherTs == null) return false;
    return otherTs < currentTs;
  }

  static Future loadConfig() async {
    final result = await ServerAPI().loadConfig();
    if (result != null) {
      if (result['aesKey'] != null) aesKey = result['aesKey'];
      if (result['exchangeAddress'] != null)
        exchangeRecvAddress = result['exchangeAddress'];
      if (result['exchangeRate'] != null) exchangeRate = result['exchangeRate'];
      if (result['telegram'] != null) telegramLink = result['telegram'];
      if (result['version'] != null)
        version = Map<String, String>.from(result['version']);
      if (result['referrerEnabled'] != null)
        referrerEnabled = result['referrerEnabled'];
    }
  }
}
