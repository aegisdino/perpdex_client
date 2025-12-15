import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../api/netclient.dart';
import '../common/cipher.dart';
import '/platform/platform.dart';
import '../config/env_config.dart';
import '../auth/securestorage.dart';
import '../config/config.dart';

import '/common/util.dart';
import '/pages/dex/providers/balance_provider.dart';
import '/pages/dex/providers/account_config_provider.dart';
import 'providers.dart';

class AccountData {
  int? seqno; // 서버의 시퀀스 번호
  String? userkey; // server의 userid의 다이제스트
  String? accesstoken;
  String? refreshtoken;
  String? memberId; // 이메일이나 아이디
  String? nickname; // 닉네임
  String? email; // 이메일
  String? phoneno; // 전화
  String? profileUrl;
  int? regdate;
  bool? useBiometricAuth;
  int? salt;
  int? agencyId;
  String? referrerCode;
  String? myReferrerCode;
  String? walletAddress; // 지갑 주소 (서버 인증 시)
  String? namespace; // 'evm' or 'solana' (JWT metadata.namespace)
  String? accountType; // 'eoa', 'mpc', 'idpass' (JWT metadata.accountType)
  String? walletType; // 'metamask', 'phantom', 'coinbase', 'trustwallet' (클라이언트 전용)

  Map<String, dynamic> assets = {};
  int level = 0;
  int totalWagered = 0;

  String get displayName => nickname ?? memberId ?? '';
  bool get isTeleAccount => memberId?.endsWith('@tg') ?? false;

  set balance(int v) => assets['cash'] = v;
  set bonus(int v) => assets['bonus'] = v;

  double get balanceUSD => (myBalance / 10000.0);
  double get cashUSD => (myCash / 10000.0);
  double get bonusUSD => (myBonus / 10000.0);

  int get myBalance => myCash + myBonus;
  int get myCash => assets['cash'] ?? 0;
  int get myBonus => assets['bonus'] ?? 0;
  int get myPoint => assets['point'] ?? 0;

  AccountData({
    this.seqno = 0,
    this.userkey = '',
    this.memberId = '',
    this.nickname = '',
    this.email,
    this.phoneno,
    this.accesstoken = '',
    this.refreshtoken = '',
    this.agencyId,
    this.regdate,
  });

  AccountData.fromJson(Map<String, dynamic> json)
      : seqno = json['seqno'],
        userkey = json['userkey'],
        memberId = json['memberid'],
        nickname = json['nickname'],
        email = json['email'],
        phoneno = json['phoneno'],
        agencyId = json['agencyId'],
        referrerCode = json['referrercode'],
        myReferrerCode = json['myreferrercode'],
        profileUrl = json['profileimage'],
        accesstoken = json['accesstoken'],
        refreshtoken = json['refreshtoken'],
        salt = json['salt'],
        regdate = json['regdate'],
        useBiometricAuth = json['usebiometricauth'],
        walletAddress = json['walletaddress'],
        namespace = json['namespace'],
        accountType = json['accounttype'],
        walletType = json['wallettype'] {
    decodeAccessToken();
  }

  void setAccessToken(String token) {
    accesstoken = token;
    decodeAccessToken();
  }

  void decodeAccessToken() {
    if (accesstoken == null) return;
    var data = JwtDecoder.tryDecode(accesstoken!);
    if (data != null) {
      if (data.containsKey('profileImage')) profileUrl = data['profileImage'];
      if (data.containsKey('email')) email = data['email'];
      if (data.containsKey('nickname')) nickname = data['nickname'];
      if (data.containsKey('memberId')) memberId = data['memberId'];
      if (data.containsKey('userkey')) userkey = data['userkey'];
      if (data.containsKey('agencyId')) agencyId = data['agencyId'];

      // JWT metadata에서 지갑 정보 추출
      if (data.containsKey('metadata') && data['metadata'] is Map) {
        final metadata = data['metadata'] as Map<String, dynamic>;
        if (metadata.containsKey('namespace') && metadata['namespace'] != null) {
          namespace = metadata['namespace'] as String;
        }
        if (metadata.containsKey('accountType') && metadata['accountType'] != null) {
          accountType = metadata['accountType'] as String;
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
        "seqno": seqno,
        "userkey": userkey,
        "memberid": memberId,
        "nickname": nickname,
        "email": email,
        "phoneno": phoneno,
        "agencyid": agencyId,
        "referrercode": referrerCode,
        "myreferrercode": myReferrerCode,
        "profileimage": profileUrl,
        "accesstoken": accesstoken,
        "refreshtoken": refreshtoken,
        "regdate": regdate,
        "usebiometricauth": useBiometricAuth,
        "walletaddress": walletAddress,
        "namespace": namespace,
        "accounttype": accountType,
        "wallettype": walletType,
      };

  void updateBalance(Map<String, dynamic> data) {
    if (data['cash'] != null) balance = parseInt(data['cash']);
    if (data['bonus'] != null) bonus = parseInt(data['bonus']);
  }
}

class AccountManager {
  factory AccountManager() => instance;

  AccountManager._();

  static final AccountManager instance = AccountManager._();

  AccountData acct = AccountData();

  String _deviceId = "";

  String get prefKey => '$serverTag.acctdata';

  String? get userkey =>
      acct.userkey.isNotNullEmptyOrWhitespace ? acct.userkey : null;

  String? get accesstoken => acct.accesstoken;
  String? get refreshtoken => acct.refreshtoken;

  String get deviceId => _deviceId;

  bool get isTelegramAccount => acct.memberId?.endsWith('@tg') == true;

  bool get isRegisteredAccount =>
      acct.userkey != null && acct.userkey.isNotNullEmptyOrWhitespace;

  Future init() async {
    // Initialize environment config first
    await EnvConfig().initialize();
    await loadDeviceId();
    await loadAccountInfo();
  }

  String encrypt(String text, {bool noUserKey = false}) {
    String encKey;
    if (noUserKey) {
      encKey = Config.current.encryptKey;
    } else {
      encKey = userkey ?? Config.current.encryptKey;
    }
    // Return empty string if no encryption key available
    if (encKey.isEmpty) {
      debugPrint('Warning: No encryption key available');
      return text; // Return unencrypted for development
    }
    return encryptAES(text, enckey: encKey);
  }

  String decrypt(String text, {bool noUserKey = false}) {
    String encKey;
    if (noUserKey) {
      encKey = Config.current.encryptKey;
    } else {
      encKey = userkey ?? Config.current.encryptKey;
    }
    // Return original text if no encryption key available
    if (encKey.isEmpty) {
      debugPrint('Warning: No decryption key available');
      return text; // Return unencrypted for development
    }
    return decryptAES(text, enckey: encKey) ?? '';
  }

  Future<String> loadDeviceId() async {
    if (_deviceId.isNullEmptyOrWhitespace) {
      _deviceId = await getDeviceId() ?? '';
    }
    return _deviceId;
  }

  bool get isAccessTokenExists => acct.accesstoken.isNotNullEmptyOrWhitespace;

  bool isAccessTokenValid() {
    if (isAccessTokenExists) {
      return accessTokenExpireTime >= 30;
    }
    return false;
  }

  int get accessTokenExpireTime {
    try {
      return JwtDecoder.getRemainingTime(acct.accesstoken!).inSeconds;
    } catch (e) {
      return 0;
    }
  }

  int getRefreshTokenExpireTime() {
    if (acct.refreshtoken.isNotNullEmptyOrWhitespace) {
      try {
        return JwtDecoder.getRemainingTime(acct.refreshtoken!).inSeconds;
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  bool isTokenLoginPossible() {
    return isAccessTokenValid() || isRefreshTokenValid();
  }

  Map<String, dynamic>? getDecodedAccessToken() {
    if (acct.accesstoken.isNotNullEmptyOrWhitespace) {
      return JwtDecoder.tryDecode(acct.accesstoken!);
    }
    return null;
  }

  bool isRefreshTokenValid() {
    if (acct.refreshtoken.isNotNullEmptyOrWhitespace) {
      return JwtDecoder.tryDecode(acct.refreshtoken!) != null &&
          !JwtDecoder.isExpired(acct.refreshtoken!);
    }
    return false;
  }

  Future<void> loadAccountInfo() async {
    // Secure storage에서 민감한 정보 로드
    final secureStorage = SecureStorage.instance;
    await secureStorage.init();

    String? acctdata = await secureStorage.getString('account_data');
    if (acctdata != null) {
      final acctMap = jsonDecode(acctdata);
      acct = AccountData.fromJson(acctMap);
    }

    debugPrint(
        'loadAccountInfo: accesstoken ${acct.accesstoken}, memberid ${acct.memberId}, cash ${acct.myCash}, bonus ${acct.myBonus}');
  }

  // save the data back asyncronously
  Future<void> saveNewAccountInfo(Map<String, dynamic>? newacctdata) async {
    final secureStorage = SecureStorage.instance;
    await secureStorage.init();

    if (newacctdata != null) {
      newacctdata["regdate"] = DateTime.now().millisecondsSinceEpoch;
      acct = AccountData.fromJson(newacctdata);
    }

    // Secure storage에 저장
    await secureStorage.setString('account_data', jsonEncode(acct.toJson()));
  }

  // save the data back asyncronously
  Future<void> saveAccountInfo(AccountData acct) async {
    final secureStorage = SecureStorage.instance;
    await secureStorage.init();

    try {
      String str = jsonEncode(acct.toJson());
      await secureStorage.setString('account_data', str);
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
  }

  void setAccessToken(String token) {
    acct.setAccessToken(token);
    saveAccountInfo(acct);
    debugPrint("setAccessToken: '${token}'");
  }

  void clearAccessToken() {
    setAccessToken('');
  }

  /// 지갑 인증으로 받은 토큰 저장
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
    required dynamic userId,
    required String userKey,
    String? walletAddress,
    String? walletType,
  }) async {
    acct.accesstoken = accessToken;
    acct.refreshtoken = refreshToken;
    acct.seqno = userId is int ? userId : int.tryParse(userId.toString());
    acct.userkey = userKey;
    if (walletAddress != null) acct.walletAddress = walletAddress;
    if (walletType != null) acct.walletType = walletType;

    // AccessToken 디코딩하여 추가 정보 추출 (namespace, accountType은 JWT metadata에서)
    acct.decodeAccessToken();

    await saveAccountInfo(acct);
    debugPrint('[AccountManager] Auth tokens saved - userId: $userId, userKey: $userKey, wallet: $walletAddress, type: $walletType');
  }

  void doLogout() {
    acct = AccountData(memberId: acct.memberId);
    saveAccountInfo(acct);
    debugPrint('AcocuntManager.doLogout');
  }

  void setUseBiometricAuth(bool v) {
    acct.useBiometricAuth = v;
    saveAccountInfo(acct);
  }

  Future onLoginSuccess(Map<String, dynamic> result) async {
    // 서버가 준 accesstoken이 empty가 아니라면
    if ((result['newaccesstoken'] as String?).isNotNullEmptyOrWhitespace) {
      if (acct.accesstoken != result['newaccesstoken']) {
        acct.setAccessToken(result['newaccesstoken']);
      }
    }

    if ((result['newrefreshtoken'] as String?).isNotNullEmptyOrWhitespace) {
      acct.refreshtoken = result['newrefreshtoken'];
    }

    acct.decodeAccessToken();

    if (result['userSeqno'] != null) acct.seqno = result['userSeqno'];
    if (result['memberId'] != null) acct.memberId = result['memberId'];
    if (result['userKey'] != null) acct.userkey = result['userKey'];
    if (result['nickname'] != null) acct.nickname = result['nickname'];
    if (result['phoneno'] != null) acct.phoneno = result['phoneno'];
    if (result['agencyId'] != null) acct.agencyId = result['agencyId'];
    if (result['cash'] != null) acct.balance = parseInt(result['cash']);
    if (result['bonus'] != null) acct.bonus = parseInt(result['bonus']);
    if (result['level'] != null) acct.level = parseInt(result['level']);
    if (result['totalWagered'] != null)
      acct.totalWagered = parseInt(result['totalWagered']);

    if (result['profileImage'] != null)
      acct.profileUrl = result['profileImage'];

    // 지갑 주소는 서버가 반환하는 경우 저장 (walletType은 클라이언트만 알고 있음)
    if (result['walletAddress'] != null) acct.walletAddress = result['walletAddress'];
    // namespace, accountType은 JWT metadata에서 자동으로 추출됨 (decodeAccessToken)

    await saveAccountInfo(acct);

    // 선물 잔고 및 계정 설정 fetch
    uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
    uncontrolledContainer.read(accountConfigProvider.notifier).fetchConfig();
  }

  Future refreshBalance() async {
    if (AccountManager().isAccessTokenValid()) {
      final result = await ServerAPI().loadBalance();
      if (result != null && result['result'] == 0) {
        acct.updateBalance(result);
        setBalanceUpdated();
      }
    }
  }

  // 모든 restful packet의 결과에 newaccesstoken, newrefreshtoken이 들어 있는 경우 갱신을 해줘야 함
  void checkUpdateToken(Map<String, dynamic> result) {
    try {
      bool needUpdate = false;
      if (result['newaccesstoken'] != null ||
          result['newrefreshtoken'] != null) {
        String? newaccesstoken = result['newaccesstoken'];
        String? newrefreshtoken = result['newrefreshtoken'];
        if (newrefreshtoken.isNotNullEmptyOrWhitespace) {
          acct.refreshtoken = newrefreshtoken;
          needUpdate = true;
          debugPrint(
              'checkUpdateToken.newrefreshtoken: new refresh token received');
        }
        if (newaccesstoken.isNotNullEmptyOrWhitespace) {
          acct.setAccessToken(newaccesstoken!);
          needUpdate = true;
          debugPrint(
              'checkUpdateToken.newaccesstoken: new access token receiverd');
        }

        if (needUpdate) saveAccountInfo(acct);
      }
    } catch (e) {
      debugPrint("checkUpdateToken: token update fail $e");
    }
  }
}
