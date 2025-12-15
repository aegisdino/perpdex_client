import 'dart:async';
import 'dart:convert';

import '/config/server_config.dart';
import '/data/account.dart';
import '/common/util.dart';
import '/config/config.dart';
import '/platform/platform.dart';

class ServerAPI {
  factory ServerAPI() {
    return _singleton;
  }

  ServerAPI._internal();

  static final ServerAPI _singleton = ServerAPI._internal();

  final _acctMgr = AccountManager();
  bool _offlineMode = false;

  bool get isOfflineMode => _offlineMode;

  void setOfflineMode() {
    _offlineMode = true;
  }

  // 캐시된 값
  String? cachedDeviceId;

  // 디버깅용 하드코딩 토큰 (지갑 로그인 안됐을 때 사용)
  static const String _debugAccessToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJtZW1iZXJJZCI6IjB4ZjdjNTUwZGIxOTk5NDE2ZDI3NDUzYWJjYzFhZjdkNmUwMTU0NTQyOCIsInVzZXJLZXkiOiJlYzkxNDFkM2IwMjQyNmIwNDdlZjUzMjEyNWM0Mzg3MyIsInVzZXJUeXBlIjoyLCJkZXZpY2VJZCI6ImExZWNjMWJmZDZlODJmOTYxNTk4NDcyMGQwNTY0NmEwYTk1MTczZTMiLCJjbGllbnRJZCI6ImExZWNjMWJmNDhjZjNmZTUiLCJtZXRhZGF0YSI6eyJuYW1lc3BhY2UiOiJldm0iLCJhY2NvdW50VHlwZSI6IndhbGxldF9lb2EiLCJuaWNrbmFtZSI6IlBsYXllcl8weGY3YzUiLCJwcm9maWxlSW1hZ2UiOm51bGwsImFnZW5jeUlkIjowfSwidHlwZSI6ImFjY2VzcyIsImlhdCI6MTc2NDk5ODY1NCwiZXhwIjoxNzY1MDAyMjU0fQ.Vbb3I69mPZGI0uLKWQCrEXHoePFrJT6bto0IuFm6vrY';

  Future<Map<String, dynamic>> addAccessTokenToParam(
    Map<String, dynamic>? params, {
    bool? addRToken,
  }) async {
    params ??= <String, dynamic>{};

    bool atokenValid = _acctMgr.isAccessTokenValid();

    if (atokenValid) {
      params['accesstoken'] = _acctMgr.accesstoken;
    } else {
      // 지갑 로그인 안됐을 때 디버깅용 하드코딩 토큰 사용
      // print('[Debug] Using hardcoded access token');
      // params['accesstoken'] = _debugAccessToken;
    }
    if (_acctMgr.isRefreshTokenValid() && (addRToken == true || !atokenValid)) {
      params['refreshtoken'] = _acctMgr.refreshtoken;
    }

    if (cachedDeviceId == null) cachedDeviceId = await _acctMgr.loadDeviceId();
    params['deviceId'] = cachedDeviceId;
    params['clientId'] = ServerConfig.clientId;

    return params;
  }

  Future<dynamic> createGoldAccount(Map<String, dynamic> params) async {
    return await postServer("create_goldaccount", params);
  }

  Future<dynamic> checkGoldAccount(Map<String, dynamic> params) async {
    return await postServer("check_goldaccount", params);
  }

  Future<dynamic> loadConfig() async {
    return await postServer("config", {});
  }

  Future<dynamic> loadAgencyList() async {
    return await postServer("load_agency_list", {});
  }

  Future<dynamic> register(Map<String, dynamic> params) async {
    return await postServer("reg_idpass_user", params);
  }

  Future<dynamic> setUserAgency(Map<String, dynamic> params) async {
    return await postServer("set_user_agency", params);
  }

  Future<dynamic> login(Map<String, dynamic> params) async {
    bool hasNoPassword = (params['passwd'] as String?).isNullEmptyOrWhitespace;
    return await postServer(
      "auth/login", params,
      // 암호가 없으면 refreshToken을 추가해서 보내야 함
      addRToken: hasNoPassword,
      silent: true,
    );
  }

  // 토큰을 강제 갱신함
  Future<dynamic> refreshtoken() async {
    return await postServer("auth/refresh_token", {}, addRToken: true);
  }

  Future<dynamic> logout() async {
    final result = await postServer("auth/logout", {});
    return result;
  }

  Future<dynamic> loadBalance() async {
    return await postServer("balance", {});
  }

  Future<dynamic> searchReferrerId(Map<String, dynamic> params) async {
    return await postServer("search_referrer", params);
  }

  Future<dynamic> loadReferrerInfo() async {
    return await postServer("load_referrer_info", {});
  }

  Future<dynamic> updateUserData(Map<String, dynamic> params) async {
    return await postServer("update_user_data", params);
  }

  Future<dynamic> changePassword(Map<String, dynamic> params) async {
    return await postServer("change_password", params);
  }

  Future<dynamic> charge(Map<String, dynamic> params) async {
    return await postServer("charge", params);
  }

  Future<dynamic> requestWithdrawMoney(Map<String, dynamic> params) async {
    return await postServer("request_withdrawmoney", params);
  }

  Future<dynamic> checkWithdrawStatus(Map<String, dynamic> params) async {
    return await postServer("load_withdraw_status", params);
  }

  Future<dynamic> loadNotice(Map<String, dynamic> params) async {
    return await postServer("load_notices", params);
  }

  Future<dynamic> loadMemo(Map<String, dynamic> params) async {
    return await postServer("load_memos", params);
  }

  Future<dynamic> removeMemo(Map<String, dynamic> params) async {
    return await postServer("remove_memo", params);
  }

  Future<dynamic> loadPointList(Map<String, dynamic> params) async {
    return await postServer("load_point_list", params);
  }

  Future<dynamic> collectPoints() async {
    return await postServer("user_collect_allpoints", {});
  }

  Future<dynamic> depositTest(int amount, {String assetType = 'cash'}) async {
    return await postServer(
        "deposit_test", {'assetType': assetType, 'amount': amount});
  }

  Future<dynamic> createBetTransaction(
      {required String fromAddress,
      required double amount,
      String? privateKey,
      String? sessionKey}) async {
    return await postServer("web3/create_bet_tx", {
      'from': fromAddress,
      'amount': amount,
      'session': sessionKey,
      'secret': privateKey
    });
  }

  Future<dynamic> getBalanceSOL(String address) async {
    return await postServer("web3/balancesol", {'walletaddress': address});
  }

  Future<dynamic> loadUserBetList(
    String address, {
    int start = 0,
    int count = 20,
  }) async {
    return await postServer("load_user_betlist", {
      'start': start,
      'count': count,
    });
  }

  // type: highroller, dailyhighroller
  Future<dynamic> loadLeaderboard(
    String type,
    String tableType,
    String currency, {
    int start = 0,
    int count = 20,
  }) async {
    return await postServer("load_leaderboard", {
      'type': type,
      'tabletype': tableType,
      'currency': currency,
      'start': start,
      'count': count,
    });
  }

  // type: streak, monthly
  Future<dynamic> loadJackpotHistory(
    String poolType,
    String currency, {
    int start = 0,
    int count = 20,
  }) async {
    return await postServer("load_jackpothistory", {
      'pooltype': poolType,
      'currency': currency,
      'start': start,
      'count': count,
    });
  }

  Future<dynamic> loadChargeGoldList(Map<String, dynamic> params) async {
    return await postServer("load_charge_gold_list", params);
  }

  Future<dynamic> loadWithdrawRequests(Map<String, dynamic> params) async {
    return await postServer("load_withdraw_requests", params);
  }

  Future<dynamic> loadWithdrawAddresses(Map<String, dynamic> params) async {
    return await postServer("load_withdraw_addresses", params);
  }

  Future<dynamic> sendQAMessage(Map<String, dynamic> params) async {
    return await postServer("send_qa_message", params);
  }

  Future<dynamic> loadQAMessages(Map<String, dynamic> params) async {
    return await postServer("load_qa_messages", params);
  }

  Future<dynamic> rollbitPlaceBet(Map<String, dynamic> params) async {
    return await postServer("rollbit_place_bet", params);
  }

  Future<dynamic> rollbitCloseBet(Map<String, dynamic> params) async {
    return await postServer("rollbit_close_bet", params);
  }

  Future<dynamic> rollbitLoadMyBetList(Map<String, dynamic> params) async {
    return await postServer("rollbit_load_mybet", params);
  }

  Future<dynamic> rollbitLoadPublicBetList(Map<String, dynamic> params) async {
    return await postServer("rollbit_load_public_bets", params);
  }

  Future<dynamic> rollbitUpdateMyBet(Map<String, dynamic> params) async {
    return await postServer("rollbit_load_mybet", params);
  }

  ///////////////////////////////////////////////////////////////////////////

  Future<dynamic> loadFxPrices(Map<String, dynamic> params) async {
    return await postServer("load_fxdata", params);
  }

  Future<dynamic> loadOrderbookSnapshot(Map<String, dynamic> params) async {
    return await postServer("nova/load_orderbook_snapshot", params);
  }

  Future<dynamic> loadIndicatorData(Map<String, dynamic> params) async {
    return await postServer("nova/load_indicators", params);
  }

  /// 선물 주문 생성
  /// [params] 필수: symbol, side, type, quantity, leverage
  /// side: 'BUY' | 'SELL'
  /// type: 'LIMIT' | 'MARKET' | 'POST_ONLY'
  Future<dynamic> createFuturesOrder(Map<String, dynamic> params) async {
    print('[Order] accessToken: ${_acctMgr.accesstoken}');
    print('[Order] params: $params');
    return await postServer("futures/orders", params);
  }

  /// 조건부 주문 생성 (STOP_MARKET, STOP_LIMIT, TRAILING_STOP, TAKE_PROFIT, STOP_LOSS)
  /// [params] 필수: symbol, orderType, side, quantity, leverage
  Future<dynamic> createConditionOrder(Map<String, dynamic> params) async {
    print('[ConditionOrder] accessToken: ${_acctMgr.accesstoken}');
    print('[ConditionOrder] params: $params');
    return await postServer("futures/conditionorders", params);
  }

  /// 계정 설정 조회 (Position Mode, Margin Mode, Multi-Asset Mode)
  Future<dynamic> getAccountSettings() async {
    return await getServer("futures/accountSettings", {});
  }

  /// 마진 모드 변경 (CROSS | ISOLATED)
  Future<dynamic> setMarginMode(String marginMode) async {
    return await postServer("futures/marginMode", {'marginMode': marginMode});
  }

  /// 포지션 모드 변경 (ONE_WAY | HEDGE)
  Future<dynamic> setPositionMode(String positionMode) async {
    return await postServer("futures/positionMode", {'positionMode': positionMode});
  }

  /// 멀티 에셋 모드 변경 (SINGLE_ASSET | MULTI_ASSET)
  Future<dynamic> setMultiAssetMode(String multiAssetMode) async {
    return await postServer("futures/multiAssetMode", {'multiAssetMode': multiAssetMode});
  }

  /// 선물 주문 취소
  Future<dynamic> cancelFuturesOrder(int orderId) async {
    print('[CancelOrder] orderId: $orderId');
    print('[CancelOrder] accessToken: ${_acctMgr.accesstoken}');
    final result = await postServer("futures/orders/cancel", {
      'orderId': orderId,
    });
    print('[CancelOrder] result: $result');
    return result;
  }

  /// 선물 주문 목록 조회 (GET 방식)
  Future<dynamic> getFuturesOrders({String? symbol, String? status}) async {
    var result =
        await _getFuturesOrdersInternal(symbol: symbol, status: status);

    // 토큰 무효화 에러 시 토큰 갱신 후 재시도
    if (result != null && result['error'] == 'atoken_invalidated') {
      print('[Order] Token invalidated, trying to refresh...');
      final refreshResult = await refreshtoken();
      if (refreshResult != null && refreshResult['result'] == 0) {
        print('[Order] Token refreshed, retrying...');
        _acctMgr.checkUpdateToken(refreshResult);
        result =
            await _getFuturesOrdersInternal(symbol: symbol, status: status);
      } else {
        print('[Order] Token refresh failed');
      }
    }

    return result;
  }

  /// 주문 목록 조회 내부 함수
  Future<dynamic> _getFuturesOrdersInternal(
      {String? symbol, String? status}) async {
    final params = <String, String>{};
    if (symbol != null) params['symbol'] = symbol;
    if (status != null) params['status'] = status;

    return await getServer("futures/orders", params);
  }

  /// 선물 포지션 조회
  Future<dynamic> getFuturesPositions({String? symbol}) async {
    final params = <String, dynamic>{};
    if (symbol != null) params['symbol'] = symbol;
    return await getServer("futures/positions", params);
  }

  /// 선물 포지션 종료
  /// [positionId] 포지션 ID
  /// [quantity] 청산할 수량 (null이면 전체 청산, 값이 있으면 부분 청산)
  Future<dynamic> closeFuturesPosition(String positionId, {String? quantity}) async {
    print('[ClosePosition] positionId: "$positionId" (length: ${positionId.length})');
    print('[ClosePosition] quantity: $quantity');
    print('[ClosePosition] accessToken: ${_acctMgr.accesstoken}');

    // positionId가 비어있거나 숫자로 변환할 수 없으면 에러 반환
    if (positionId.isEmpty) {
      print('[ClosePosition] ERROR: positionId is empty!');
      return {'result': -1, 'error': 'Position ID is empty'};
    }

    final parsedId = int.tryParse(positionId);
    if (parsedId == null) {
      print('[ClosePosition] ERROR: Cannot parse positionId to int: "$positionId"');
      return {'result': -1, 'error': 'Invalid position ID format'};
    }

    final params = <String, dynamic>{'positionId': parsedId};

    // quantity가 있으면 부분 청산
    if (quantity != null && quantity.isNotEmpty) {
      params['quantity'] = quantity;
    }

    final result = await postServer("futures/positions/close", params);
    print('[ClosePosition] result: $result');
    return result;
  }

  /// 선물 포지션 종료 (고급 버전 - Hedge Mode 지원)
  /// Hedge Mode에서는 LONG과 SHORT 포지션을 동시에 보유할 수 있으므로
  /// positionSide로 어떤 포지션을 닫을지 명시해야 합니다.
  ///
  /// [symbol] 심볼 (예: "BTCUSDT")
  /// [positionSide] "LONG" 또는 "SHORT" - 닫을 포지션의 방향
  /// [quantity] 닫을 수량 (전체 종료는 포지션의 전체 수량 입력)
  /// [type] 주문 타입 "MARKET" 또는 "LIMIT"
  /// [price] LIMIT 주문일 경우 가격 (MARKET 주문은 null)
  /// [leverage] 레버리지 (기본값 20.0)
  ///
  /// 참고: LONG 포지션을 닫으려면 SELL 주문, SHORT 포지션을 닫으려면 BUY 주문
  Future<dynamic> closeFuturesPositionAdvanced({
    required String symbol,
    required String positionSide, // "LONG" or "SHORT"
    required String quantity,
    String type = 'MARKET',
    String? price,
    double leverage = 20.0,
  }) async {
    // LONG 포지션을 닫으려면 SELL, SHORT 포지션을 닫으려면 BUY
    final side = positionSide == 'LONG' ? 'SELL' : 'BUY';

    final params = {
      'symbol': symbol,
      'side': side,
      'type': type,
      'quantity': quantity,
      'leverage': leverage,
      'reduceOnly': true, // 포지션 축소만 가능 (새 포지션 생성 불가)
      'positionSide': positionSide, // Hedge Mode 지원
    };

    if (type == 'LIMIT' && price != null) {
      params['price'] = price;
    }

    print('[ClosePosition] Advanced params: $params');
    final result = await postServer("futures/orders", params);
    print('[ClosePosition] Advanced result: $result');
    return result;
  }

  /// 선물 잔고 조회
  Future<dynamic> getFuturesBalance() async {
    return await getServer("futures/balance", {});
  }

  /// 레버리지 티어 정보 조회
  /// [symbol] 심볼 (예: BTCUSDT)
  Future<dynamic> getLeverageTiers(String symbol) async {
    return await getServer("futures/leverage/tier", {'symbol': symbol});
  }

  /// 레버리지 유효성 검증
  /// [symbol] 심볼 (예: BTCUSDT)
  /// [leverage] 레버리지
  /// [quantity] 수량 (선택)
  /// [notionalValue] 명목가치 (선택)
  Future<dynamic> validateLeverage({
    required String symbol,
    required int leverage,
    double? quantity,
    double? notionalValue,
  }) async {
    final body = <String, dynamic>{
      'symbol': symbol,
      'leverage': leverage,
    };
    if (quantity != null) body['quantity'] = quantity.toString();
    if (notionalValue != null) body['notionalValue'] = notionalValue.toString();

    return await postServer("futures/leverage/validate", body);
  }

  /// 주문 이력 조회 (체결/취소/거부된 주문)
  /// [symbol] 심볼 필터 (선택)
  /// [status] 상태 필터: FILLED, CANCELLED, REJECTED 등 (선택)
  /// [startDate] 시작 날짜 (선택)
  /// [endDate] 종료 날짜 (선택)
  /// [limit] 조회 개수 (기본 50)
  /// [offset] 오프셋 (기본 0)
  Future<dynamic> getFuturesOrderHistory({
    String? symbol,
    String? status,
    String? startDate,
    String? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (symbol != null) params['symbol'] = symbol;
    if (status != null) params['status'] = status;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    return await getServer("futures/orders/history", params);
  }

  /// 거래(체결) 내역 조회
  /// [symbol] 심볼 필터 (선택)
  /// [startDate] 시작 날짜 (선택)
  /// [endDate] 종료 날짜 (선택)
  /// [limit] 조회 개수 (기본 50)
  /// [offset] 오프셋 (기본 0)
  Future<dynamic> getFuturesMyTrades({
    String? symbol,
    String? startDate,
    String? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (symbol != null) params['symbol'] = symbol;
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;

    return await getServer("futures/my-trades", params);
  }

  /// 계정 설정 전체 조회
  Future<dynamic> getAccountConfig() async {
    return await getServer("futures/account/config", {});
  }

  /// 심볼별 설정 조회
  Future<dynamic> getSymbolConfig(String symbol) async {
    return await getServer("futures/account/config/symbol", {'symbol': symbol});
  }

  /// 심볼별 설정 업데이트 (통합)
  Future<dynamic> updateSymbolConfig({
    required String symbol,
    String? positionMode,
    String? marginMode,
    int? leverage,
  }) async {
    final params = <String, dynamic>{'symbol': symbol};
    if (positionMode != null) params['positionMode'] = positionMode;
    if (marginMode != null) params['marginMode'] = marginMode;
    if (leverage != null) params['leverage'] = leverage;
    return await postServer("futures/account/config/symbol", params);
  }

  /// 심볼별 레버리지 설정 (간편)
  Future<dynamic> setSymbolLeverage(String symbol, int leverage) async {
    return await postServer("futures/leverage", {
      'symbol': symbol,
      'leverage': leverage,
    });
  }

  /// 심볼별 마진 모드 설정 (간편)
  Future<dynamic> setSymbolMarginMode(String symbol, String marginMode) async {
    return await postServer("futures/marginMode", {
      'symbol': symbol,
      'marginMode': marginMode,
    });
  }

  /// 심볼별 포지션 모드 설정
  Future<dynamic> setSymbolPositionMode(String symbol, String positionMode) async {
    return await postServer("futures/account/config/symbol", {
      'symbol': symbol,
      'positionMode': positionMode,
    });
  }

  ///////////////////////////////////////////////////////////////////////////

  Map<String, String> toastErrorMsgMap = {
    'connection timeout': '서버 접속 시간이 초과됐습니다.',
    'data timeout': '데이터 응답 시간이 초과됐습니다.',
    'timeout': '서버 응답 시간이 초과됐습니다.',
    'server error': '작업 처리중 알 수 없는 오류가 발생했습니다.',
    'alreadyinprogress': '이미 처리중인 작업이 있습니다.',
    'no authority': '권한이 없습니다.',
    'nofacert': '블록체인 지갑이 존재하지 않습니다.',
  };

  Map<String, String> alertErrorMsgMap = {
    'invalidaccesstoken': '액세스 토큰이 만료됐습니다. 로그인을 다시 진행합니다.',
    'loginfail': '로그인에 실패했습니다.',
    'atoken_device_mismatch': '토큰이 무효화되었습니다. (다른 디바이스에서 로그인됨)',
    'atoken_client_mismatch': '토큰이 무효화되었습니다. (새로운 세션으로 로그인됨)',
    'atoken_invalid': '토큰이 유효하지 않습니다.',
    'atoken_invalidated': '토큰이 무효화됐습니다 (중복된 로그인).',
    'atoken_expired': '토큰이 만료되었습니다.',
    'atoken_duplogin': '토큰이 무효화되었습니다. (중복된 로그인)',
    // 'atoken_none': '토큰이 존재하지 않습니다.',
    'rtoken_none': '토큰이 존재하지 않습니다.',
    'rtoken_expired': '토큰이 만료되었습니다. 다시 로그인해주세요.',
  };

  void processError(
    Map<String, dynamic>? result, {
    String? cmd,
    Map<String, dynamic>? params,
  }) {
    if (result == null) {
      return;
    }

    if (result['result'] == 101) {
      Util.showAlert(
          '[${result['unregdate']}]에 탈퇴한 계정입니다.\n탈퇴한지 7일이내에는 재가입이 불가능합니다.\n문의 사항은 contact@fortknox.io로 보내주시기 바랍니다.');
      return;
    }

    if (result['error'] == 'atoken_none' || result['error'] == 'rtoken_none')
      return;

    String? message = toastErrorMsgMap[result['error']];
    if (message != null) {
      Util.toastError(message);
    } else {
      message = alertErrorMsgMap[result['error']];
      if (message != null) {
        Util.showAlert(message, onOK: () {
          navigationPush(ContextManager.buildContext!, '/');
        });
      } else {
        print('processError: input ($cmd, $params), error ${result['error']}');
        Util.toastError('처리되지 않은 오류: $cmd ${result['error'] ?? '알수없는 오류'}');
      }
    }
  }

  Future<dynamic> postServer(
    String cmd,
    Map<String, dynamic> params, {
    bool addAccessToken = true,
    bool addRToken = false,
    bool silent = false,
  }) async {
    Map<String, dynamic>? result;

    // 2회 시도
    // - 다음의 경우 2회 실행
    //   . result가 null (일반적으로 네트워크 연결이 없을 때)
    //   . 1회째 atoken_user_notfound라면 2회째는 refreshToken을 넣어서 시도하는 경우
    for (var tryCount = 0; tryCount < 2; tryCount++) {
      result = await postMainServer(
        cmd,
        params,
        addAccessToken: addAccessToken,
        addRToken: addRToken,
      );
      if (result != null) {
        if (result['result'] != null && result['result'] >= 99) {
          // refresh token을 넣어서 다시 시도
          if (result['error'] == 'atoken_user_notfound' && !addRToken) {
            addRToken = true;
            continue;
          }
          if (!silent) {
            processError(result, cmd: cmd, params: params);
          }
        }
        break;
      }
    }
    return result;
  }

  Future<dynamic> postMainServer(
    String path,
    Map<String, dynamic> params, {
    bool addAccessToken = false,
    bool addRToken = false,
  }) async {
    var uri = Config.getUri(path);
    if (addAccessToken) {
      params = await addAccessTokenToParam(params, addRToken: addRToken);
    }
    var result = await postUri(uri, params);
    if (result != null) {
      if (result['success'] != null && result['success'] is bool) {
        result['result'] = result['success'] == true ? 0 : 1;
      } else if (result['result'] != null &&
          result['result'] is String &&
          int.tryParse(result['result']) != null) {
        result['result'] = parseInt(result['result']);
      }
    }
    return result;
  }

  Future<dynamic> getServer(
    String cmd,
    Map<String, dynamic> params, {
    bool addAccessToken = true,
    bool addRToken = false,
    bool silent = false,
  }) async {
    Map<String, dynamic>? result;

    // 2회 시도
    // - 다음의 경우 2회 실행
    //   . result가 null (일반적으로 네트워크 연결이 없을 때)
    //   . 1회째 atoken_user_notfound라면 2회째는 refreshToken을 넣어서 시도하는 경우
    for (var tryCount = 0; tryCount < 2; tryCount++) {
      result = await getMainServer(
        cmd,
        params,
        addAccessToken: addAccessToken,
        addRToken: addRToken,
      );
      if (result != null) {
        if (result['result'] != null && result['result'] >= 99) {
          // refresh token을 넣어서 다시 시도
          if (result['error'] == 'atoken_user_notfound' && !addRToken) {
            addRToken = true;
            continue;
          }
          if (!silent) {
            processError(result, cmd: cmd, params: params);
          }
        }
        break;
      }
    }
    return result;
  }

  Future<dynamic> getMainServer(
    String path,
    Map<String, dynamic> params, {
    bool addAccessToken = false,
    bool addRToken = false,
  }) async {
    var uri = Config.getUri(path);
    if (addAccessToken) {
      params = await addAccessTokenToParam(params, addRToken: addRToken);
    }

    uri = uri.replace(queryParameters: params);
    var result = await getUri(uri, dontWrapStatusCode: true);
    if (result != null) {
      try {
        // string으로 넘어옴
        result = jsonDecode(result);

        if (result['success'] != null && result['success'] is bool) {
          result['result'] = result['success'] == true ? 0 : 1;
        } else if (result['result'] != null &&
            result['result'] is String &&
            int.tryParse(result['result']) != null) {
          result['result'] = parseInt(result['result']);
        }
      } catch (e) {
        print('getUri: ${e}');
      }
    }

    return result;
  }
}
