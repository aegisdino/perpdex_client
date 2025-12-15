import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import '/auth/securestorage.dart';
import '/auth/authmanager.dart';
import '/data/providers.dart';
import '../config/config.dart';
import '../config/server_config.dart';
import '/data/account.dart';
import '/common/util.dart';
import '/platform/platform.dart';
import '/pages/dex/providers/position_provider.dart';
import '/pages/dex/providers/order_provider.dart';
import '/pages/dex/providers/balance_provider.dart';

class GameNotification extends Notification {
  final String type;
  final dynamic data;

  GameNotification(this.type, this.data);
}

enum WSConnectState { NotConnected, Connecting, Connected }

class WebsocketClient {
  factory WebsocketClient() => instance;

  WebsocketClient._();

  static final WebsocketClient instance = WebsocketClient._();
  final _storage = SecureStorage();

  // notificationProvider는 providers.dart로 이동됨

  WebSocketChannel? _socket;

  bool get isConnected => connState == WSConnectState.Connected;
  bool get isConnecting => connState == WSConnectState.Connecting;
  bool get isReconnecting => _reconnectTimer?.isActive ?? false;
  bool get isExpelled => _connExpelled == true;

  WSConnectState connState = WSConnectState.NotConnected;

  bool _connExpelled = false;
  bool _autoConnectWsOnDisconnect = true;
  bool get _appIsPaused => isAppHidden();

  final acctMgr = AccountManager();

  Timer? _pingPongTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  static const int _maxReconnectAttempts = 10;

  void sendNotification(String type, dynamic data) {
    uncontrolledContainer.read(notificationProvider.notifier).state =
        GameNotification(type, data);
  }

  String? lastAuthData;

  Map<String, dynamic> getAuthData() {
    final data = {
      'deviceId': acctMgr.deviceId,
      'clientId': ServerConfig.clientId,
      'accessToken': acctMgr.acct.accesstoken
    };
    return data;
  }

  Future authenticate() async {
    if (isConnected) {
      // 이미 접속되어 있는 경우, authenticate 보냄
      if (acctMgr.isAccessTokenValid()) {
        try {
          final authData = getAuthData();
          final encoded = jsonEncode(authData);
          if (encoded != lastAuthData) {
            debugPrint('WebSocket.authenticate: authData ${encoded}');
            sendData('authenticate', authData);
            lastAuthData = encoded;
          } else {
            debugPrint('WebSocket.authenticate: auth data not changed');
          }
        } catch (e) {
          debugPrint('WebSocket.authenticate: exception ${e}');
        }
      } else {
        debugPrint('WebSocket.authenticate: access token is not valid');
      }
    } else {
      debugPrint(
          'WebsocketClient.authenticate: not connected. start websocket');

      // 없으면 접속 시작
      await startWebSocket();
    }
  }

  Future<bool> startWebSocket({
    bool isReconnect = false,
  }) async {
    if (Config.wsHost.isNullEmptyOrWhitespace) {
      debugPrint('startWebSocket: no wsHost specified');
      return false;
    }

    String uri = Config.wsHost!;

    // 이미 연결 시도 중인지 확인하는 플래그 추가
    if (isConnecting) {
      debugPrint('startWebSocket: already in connecting');
      return false;
    } else if (isConnected) {
      debugPrint('startWebSocket: already connected');
      return true;
    }

    // 재접속 시도가 아니라면 try회수 클리어하고 재접속 타이머 초기화
    if (!isReconnect) {
      _stopReconnect();
    }

    connState = WSConnectState.Connecting;
    _connExpelled = false;

    sendNotification('connecting', null);

    try {
      final connectUrl =
          '$uri?deviceId=${acctMgr.deviceId}&clientId=${ServerConfig.clientId}&accessToken=${acctMgr.acct.accesstoken}';

      debugPrint('startWebSocket: ${connectUrl}');

      // isConnecting/isConnected를 넘어갔지만, 소켓이 있을 수 있음
      if (_socket != null) {
        debugPrint('startWebSocket: _socket exists. close it first');
        _closeSocket();
      }

      final socket = await connectToWebSocket(connectUrl);
      await socket.ready;

      debugPrint('startWebSocket: connected');

      // 연결됨
      _socket = socket;

      connState = WSConnectState.Connected;

      _autoConnectWsOnDisconnect = true; // 자동 재접속 켜둠
      _reconnectAttempts = 0;

      // 연결 성공된 인증 데이터 유지
      lastAuthData = jsonEncode(getAuthData());

      // 스트림 리스닝 시작
      _socket!.stream.listen(
        (dynamic message) => _onData(message),
        onError: _onError,
        onDone: _onDone,
      );

      sendNotification('connected', null);
    } catch (e) {
      connState = WSConnectState.NotConnected;
      debugPrint('startWebSocket: ${e}');

      sendNotification('connectfail', null);

      _checkArmReconnect('connecting');
    }

    return true;
  }

  void _closeSocket() {
    if (_socket != null) {
      final _s = _socket;
      _socket = null; // 미리 클리어해서 onDone에서 close처리하지 않게
      _s!.sink.close();
    }
  }

  void _startPingPong() {
    _pingPongTimer?.cancel();

    _pingPongTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      sendData('ping', DateTime.now().millisecondsSinceEpoch.toString());
      debugPrint('send ping');
    });
  }

  /// 웹소켓 연결 성공 후 초기 데이터 로드 (로그인된 경우에만)
  void _loadInitialData(bool isAuthenticated) {
    if (!isAuthenticated) {
      debugPrint('[WS] Skip loading initial data - not authed socket');
      return;
    }

    debugPrint('[WS] Loading initial data...');
    // 잔고 조회
    uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
    // 포지션 조회
    uncontrolledContainer.read(positionListProvider.notifier).fetchPositions();
    // 미체결 주문 조회
    uncontrolledContainer
        .read(orderListProvider.notifier)
        .fetchOrders(status: 'OPEN');
  }

  void _stopPingPong() {
    _pingPongTimer?.cancel();
    _pingPongTimer = null;
  }

  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  int? lastEventTime;

  void _onData(dynamic message) async {
    try {
      final Map<String, dynamic> src = jsonDecode(message);
      debugPrint('[WS] _onData received: ${src['type']}, full: $src');

      switch (src['type']) {
        case 'join':
          _startPingPong();
          // 초기 데이터 로드
          _loadInitialData(src['authenticated']);
          break;

        case 'blocked':
          sendNotification('blocked', null);
          break;

        case 'error':
          await _processErrorMessage(src);
          break;

        case 'notification':
          sendNotification('servernotification', jsonDecode(src['message']));
          break;

        // DEX 알림 (주문/포지션/잔고 이벤트)
        case 'dex_notif':
          _handleDexNotification(src);
          break;

        default:
          //debugPrint('websocket::default: $message');
          break;
      }
    } catch (e, s) {
      debugPrint('Error parsing message: $e, $s');
      debugPrint('Error parsing message: $message');
    }
  }

  void _onDone() async {
    if (await _isFoolishFlutterHotRestarted()) return;

    final closeCode = _socket?.closeCode;
    final closeReason = _socket?.closeReason;

    debugPrint(
        'WebSocket::onDone: connState ${connState}, ${_socket != null ? 'socket exists' : 'socket null'}, close code ${closeCode}, reason ${closeReason}, appPaused ${_appIsPaused}');

    if (_socket != null) {
      sendNotification('disconnected', null);

      connState = WSConnectState.NotConnected;

      // 소켓 정리 (disconnect 호출하지 않고 직접 처리)
      _stopPingPong();
      _closeSocket();

      if (_connExpelled) {
        debugPrint('WebSocket::onDone: expelled connection');
        return;
      }

      // session_replaced (code 4000) - 새 연결이 이미 있음, 재연결 안 함
      if (closeCode == 4000) {
        debugPrint(
            'WebSocket::onDone: session replaced by newer connection, not reconnecting');
        return;
      }

      // 정상적인 종료가 아닌 경우에만 재연결 시도
      if (!_appIsPaused && closeCode != 1000 && _autoConnectWsOnDisconnect) {
        debugPrint(
            'WebSocket::onDone: not disconnected gracefully. starting reconnect attempts');

        // 3초 후에 재접속을 시도 함
        _checkArmReconnect('onDone');
      }
    }
  }

  void _onError(Object error, StackTrace strace) async {
    debugPrint(
        'WebSocket Error: ${error}, connstate ${connState}, expelled connection? ${_connExpelled}');

    // 접속중이 아닌 경우라면 연결이 끊김 알려줌
    if (!isConnecting) {
      sendNotification('disconnected', null);
    }

    // 소켓 정리
    connState = WSConnectState.NotConnected;
    _stopPingPong();

    if (_socket != null) {
      _closeSocket();
      debugPrint('WebSocket::onError: disconnected');
    }

    if (_connExpelled) return;

    _checkArmReconnect('onError');
  }

  List<int> _reconnectTimeTable = [1, 3, 5, 7, 9, 11, 15, 30];

  void _checkArmReconnect(String func) {
    final delay = (_reconnectAttempts++ < _reconnectTimeTable.length - 1)
        ? _reconnectTimeTable[_reconnectAttempts]
        : 60;

    debugPrint(
        'WebSocket::${func}: reconnect attempts ${_reconnectAttempts}/${_maxReconnectAttempts}, try after ${delay} sec');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
        Duration(seconds: delay), () => startWebSocket(isReconnect: true));
  }

  void _notifyDisconnection(String notif) {
    AuthManager().invalidateAccessToken();
    sendNotification(notif, null);
  }

  // Flutter가 web에서 Hot restart를 하는 경우
  // 이전 websocket이 남아 있는 채로, _socket 변수만 클리어가 됨
  // - 서버는 이전 세션을 끊어버리는데, 클라는 그게 이전 것인지 확인할 방법이 없음
  // - web local storage에 데이터를 기록하는 것만이 해당 상태를 파악 할 수 있음
  //   (SharedPreference는 상태가 유지되지 않음)
  Future<bool> _isFoolishFlutterHotRestarted() async {
    final hotrestarttime = parseInt(await _storage.getString('hotrestarttime'));

    final elapsed = DateTime.now().millisecondsSinceEpoch - hotrestarttime;
    if (elapsed < 1000) {
      await _storage.setString('hotrestarttime', '0');
      print('_onDone: Hot refresh close! ${elapsed}ms');
      return true;
    }

    return false;
  }

  Future<bool> _checkFoolishFlutterHotRestart(Map<String, dynamic> src) async {
    final oldDeviceId = src['data']['deviceId'] as String?;
    final oldClientId = src['data']['clientId'] as String?;
    final currentClientId = ServerConfig.clientId;

    print('_onData:[$oldDeviceId, $oldClientId], [$currentClientId]');

    if (oldDeviceId != acctMgr.deviceId || oldClientId != currentClientId) {
      await _storage.setString(
          'hotrestarttime', '${DateTime.now().millisecondsSinceEpoch}');
      debugPrint(
          '_onData: ${src['message']}, deviceId/clientId is not mine [$oldDeviceId, $oldClientId], [$currentClientId]');
      return true;
    }

    return false;
  }

  Future _processErrorMessage(Map<String, dynamic> src) async {
    switch (src['message']) {
      case 'idleexpel':
        _connExpelled = true;
        sendNotification('idleexpel', null);
        break;

      case 'duplicated_login':
      case 'atoken_duplogin':
        if (await _checkFoolishFlutterHotRestart(src)) break;

        // 중복 로그인의 경우, refresh token은 여전히 유효하므로 로그아웃하지 않음
        debugPrint('_onData: ${src['message']}, duplicated login detected');
        _autoConnectWsOnDisconnect = false; // 자동 재연결 중지

        _notifyDisconnection('duplicatedlogin');
        break;

      case 'session_reset':
        _autoConnectWsOnDisconnect = false; // 자동 재연결 중지
        _notifyDisconnection('sessionreset');
        break;

      case 'atoken_user_notfound':
        // 이건 유저가 redis에도 없는 경우
        // refreshToken을 시도해보는 게 좋음
        AuthManager().refreshAccessToken(forceUpdate: true);
        break;

      // 실제로 토큰이 무효화된 경우들
      case 'atoken_device_mismatch':
      case 'atoken_client_mismatch':
      case 'atoken_invalidated':
      case 'atoken_invalid':
      case 'atoken_expired':
        debugPrint(
            '_onData: ${src['message']}, reset account and try connect again');
        _notifyDisconnection('tokeninvalid');
        break;

      case 'logout':
        // 일반 유저로 재접속이 되어야 함
        debugPrint('_onData: ${src['message']}, try connect again');
        sendNotification('logout', null);
        break;

      case 'blocked':
        sendNotification('blocked', null);
        break;

      case 'newconnection':
        _connExpelled = true;
        break;

      default:
        debugPrint('error: ${src['message']}');
        break;
    }
  }

  /// DEX 알림 처리 (주문/포지션/잔고 이벤트)
  /// 서버에서 type: 'dex_notif', eventType: 'ORDER_UPDATE' 등으로 전송
  void _handleDexNotification(Map<String, dynamic> src) {
    final eventType = src['eventType'] as String?;
    debugPrint('[WS] DEX notification: $eventType, data: $src');

    if (eventType == null) return;

    switch (eventType) {
      case 'ORDER_CREATED':
        debugPrint('[WS] >>> ORDER_CREATED: fetching orders + balance');
        uncontrolledContainer
            .read(orderListProvider.notifier)
            .fetchOrders(status: 'OPEN');
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'ORDER_FILLED':
        debugPrint(
            '[WS] >>> ORDER_FILLED: fetching orders + positions + balance');
        uncontrolledContainer
            .read(orderListProvider.notifier)
            .fetchOrders(status: 'OPEN');
        uncontrolledContainer
            .read(positionListProvider.notifier)
            .fetchPositions();
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'ORDER_CANCELLED':
        debugPrint('[WS] >>> ORDER_CANCELLED: fetching orders + balance');
        uncontrolledContainer
            .read(orderListProvider.notifier)
            .fetchOrders(status: 'OPEN');
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'ORDER_UPDATE':
        debugPrint(
            '[WS] >>> ORDER_UPDATE: fetching orders + positions + balance');
        uncontrolledContainer
            .read(orderListProvider.notifier)
            .fetchOrders(status: 'OPEN');
        uncontrolledContainer
            .read(positionListProvider.notifier)
            .fetchPositions();
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'POSITION_CLOSED':
        debugPrint('[WS] >>> POSITION_CLOSED: fetching positions + balance');
        uncontrolledContainer
            .read(positionListProvider.notifier)
            .fetchPositions();
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'POSITION_LIQUIDATED':
        debugPrint(
            '[WS] >>> POSITION_LIQUIDATED: fetching positions + balance');
        // 청산 알림 표시
        _showLiquidationNotification(src);
        // 데이터 갱신
        uncontrolledContainer
            .read(positionListProvider.notifier)
            .fetchPositions();
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'BALANCE_UPDATE':
        debugPrint('[WS] >>> BALANCE_UPDATE: fetching balance');
        uncontrolledContainer.read(balanceProvider.notifier).fetchBalance();
        break;

      case 'POSITIONS_STATUS':
        debugPrint(
            '[WS] >>> POSITIONS_STATUS: updating positions realtime data');
        _handlePositionsStatus(src);
        break;

      default:
        debugPrint('[WS] Unknown DEX event type: $eventType');
        break;
    }

    // notification도 전송 (다른 곳에서 필요할 수 있음)
    sendNotification('dex_notif', src);
  }

  /// 청산 알림 표시
  void _showLiquidationNotification(Map<String, dynamic> src) {
    final symbol = src['symbol'] ?? '';
    final side = src['side'] == 'LONG' ? '롱' : '숏';
    final quantity = src['quantity'] ?? '0';
    final entryPrice = src['entryPrice'] ?? '0';
    final liquidationPrice = src['liquidationPrice'] ?? '0';
    final realizedPnl = src['realizedPnl'] ?? '0';

    final message = '$symbol $side 포지션이 청산되었습니다.\n'
        '수량: $quantity\n'
        '진입가: $entryPrice\n'
        '청산가: $liquidationPrice\n'
        '실현손익: $realizedPnl USDT';

    Util.showAlert(message, title: '포지션 청산');
  }

  /// 포지션 실시간 상태 업데이트 (markPrice, unrealizedPnl, equity, liqPrice)
  void _handlePositionsStatus(Map<String, dynamic> src) {
    try {
      final positions = src['positions'] as List<dynamic>?;
      final positionNotifier =
          uncontrolledContainer.read(positionListProvider.notifier);
      final balanceNotifier =
          uncontrolledContainer.read(balanceProvider.notifier);

      // 포지션이 없으면 미실현 손익을 0으로 초기화
      if (positions == null || positions.isEmpty) {
        balanceNotifier.updateRealtimeBalance(
          totalUnrealizedPnl: 0.0,
        );
        return;
      }

      double totalUnrealizedPnl = 0.0;
      double totalMargin = 0.0;
      double? latestEquity;

      for (final pos in positions) {
        final symbol = pos['symbol'] as String?;
        final side = pos['side'] as String?;
        final markPrice = parseDouble(pos['markPrice']?.toString() ?? '');
        final unrealizedPnl =
            parseDouble(pos['unrealizedPnl']?.toString() ?? '');
        final equity = parseDouble(pos['equity']?.toString() ?? '');
        final liqPrice = parseDouble(pos['liqPrice']?.toString() ?? '');
        final margin = parseDouble(pos['margin']?.toString() ?? '');

        totalMargin += margin;

        if (symbol != null && markPrice != 0) {
          // 포지션의 markPrice 업데이트 (side로 구분)
          positionNotifier.updateMarkPriceBySide(symbol, side, markPrice);
        }

        if (symbol != null && liqPrice != 0) {
          // 청산가 업데이트 (side로 구분)
          positionNotifier.updateLiquidationPriceBySide(symbol, side, liqPrice);
        }

        if (symbol != null && unrealizedPnl != 0) {
          // 포지션별 미실현 손익 업데이트 (side로 구분)
          positionNotifier.updateUnrealizedPnlBySide(
              symbol, side, unrealizedPnl);
          totalUnrealizedPnl += unrealizedPnl;
        }

        // equity는 계정 전체 값이므로 마지막 값 사용
        if (pos['equity'] != null) {
          latestEquity = equity;
        }
      }

      // 잔고 상태 업데이트 (equity, totalUnrealizedPnl)
      balanceNotifier.updateRealtimeBalance(
        equity: latestEquity,
        totalUnrealizedPnl: totalUnrealizedPnl,
        totalMargin: totalMargin,
      );
    } catch (e, s) {
      debugPrint('[WS] _handlePositionsStatus error: $e');
      debugPrint('[WS] Stack trace: $s');
    }
  }

  bool sendData(String type, dynamic data) {
    return send({'type': type, 'data': data});
  }

  bool send(Map<String, dynamic> json) {
    if (_socket == null) {
      debugPrint('[websocket] send: no socket. data: ${jsonEncode(json)}');
      return false;
    }

    _socket?.sink.add(utf8.encode(
      jsonEncode(json),
    ));

    return true;
  }

  void disconnect() {
    debugPrint(
        'WebSocket.disconnect: current state ${connState}, has socket ${_socket != null}');

    if (connState != WSConnectState.Connected) {
      connState = WSConnectState.NotConnected;
      _autoConnectWsOnDisconnect = false;
    }

    if (_socket != null) {
      _closeSocket();
      debugPrint('[websocket] disconnect!');
    }

    // stop timers
    _stopPingPong();
    _stopReconnect();
  }
}
