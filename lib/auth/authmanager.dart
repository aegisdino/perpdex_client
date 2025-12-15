import 'dart:async';

import 'package:flutter/material.dart';

import '/game/websocket_client.dart';
import '/data/providers.dart';
import '/data/account.dart';
import '/common/util.dart';

import '/api/netclient.dart';
import '/config/server_config.dart';

class AuthManager {
  factory AuthManager() => _singleton;
  AuthManager._internal();

  static final AuthManager _singleton = AuthManager._internal();

  final _acctMgr = AccountManager();
  final _wsClient = WebsocketClient();

  bool get isLoginOK => uncontrolledContainer.read(loginStateProvider);

  void setLoginOK(bool v) {
    uncontrolledContainer.read(loginStateProvider.notifier).state = v;

    if (v) {
      armAccessTokenRefreshTimer();
    }
  }

  Future<int?> login(String memberId, String passwd) async {
    try {
      debugPrint('AuthManager::login: try ${memberId} login');

      // 먼저 websocket disconnect
      _wsClient.disconnect();

      final result = await ServerAPI().login({
        'memberId': memberId,
        'nickname': memberId,
        'passwd': passwd,
        'clientId': ServerConfig.clientId,
      });

      if (result != null) {
        if (result['result'] == 0) {
          AccountManager().onLoginSuccess(result['user']);
          setLoginOK(true);

          debugPrint('AuthManager::login: connected.');
          return 0;
        } else {
          return parseInt(result['result']);
        }
      } else {
        debugPrint('AuthManager::login: result is null');
        return null;
      }
    } finally {
      // 모든 경우에 웹소켓 오픈 또는 인증해줌

      debugPrint('AuthManager::login: authenticate in finally');
      _wsClient.authenticate();
    }
  }

  int? _lastAutologinTime;

  Future<bool> autoLogin() async {
    try {
      if (isLoginOK) {
        debugPrint('AuthManager::autoLogin: already login');
        return true;
      }

      if (_lastAutologinTime != null) {
        double elapsed =
            (DateTime.now().microsecondsSinceEpoch - _lastAutologinTime!) /
                1000;
        if (elapsed < 5) {
          debugPrint(
              'AuthManager::autoLogin: duplicated request [${elapsed.toStringAsFixed(2)} sec]');
          return true;
        }
      }

      _lastAutologinTime = DateTime.now().millisecondsSinceEpoch;

      // 액세스토큰이 유효한 경우에 한 해 자동 로그인 시도
      if (_acctMgr.acct.userkey != null && _acctMgr.isTokenLoginPossible()) {
        debugPrint(
            'AuthManager::autoLogin: try ${_acctMgr.acct.memberId} with tokens');

        _wsClient.disconnect();

        final result = await ServerAPI().login({
          'memberId': _acctMgr.acct.memberId,
          'clientId': ServerConfig.clientId,
        });

        if (result != null && result['result'] == 0) {
          AccountManager().onLoginSuccess(result['user']);
          setLoginOK(true);

          debugPrint('AuthManager::autoLogin: login OK');
          return true;
        } else {
          debugPrint('AuthManager::autoLogin: login FAIL');
        }
      } else {
        debugPrint(
            'AuthManager::autoLogin: no userkey (${_acctMgr.acct.userkey}) or invalid tokens (access ${_acctMgr.isAccessTokenValid()}, refresh ${_acctMgr.isRefreshTokenValid()})');
      }

      return false;
    } finally {
      // 모든 경우에 웹소켓 오픈 또는 인증해줌
      debugPrint('AuthManager::autoLogin: authenticate in finally');
      _wsClient.authenticate();
    }
  }

  bool _isRefreshing = false;
  DateTime? _lastRefreshAttempt;

  Future<bool> refreshAccessToken({bool forceUpdate = false}) async {
    debugPrint('refreshAccessToken: force ${forceUpdate}');

    // 이미 refresh 중이면 중복 요청 방지
    if (_isRefreshing) {
      debugPrint(
          'refreshAccessToken: already refreshing, skip duplicate request');
      return false;
    }

    if (!_acctMgr.isRefreshTokenValid()) {
      debugPrint('refreshAccessToken: refresh token is invalid');
      return false;
    }

    if (!forceUpdate) {
      // 최근 refresh 시도가 10초 이내면 건너뛰기
      if (_lastRefreshAttempt != null &&
          DateTime.now().difference(_lastRefreshAttempt!).inSeconds < 10) {
        debugPrint('refreshAccessToken: too frequent refresh attempt, skip');
        return false;
      }
    }

    try {
      _isRefreshing = true;
      _lastRefreshAttempt = DateTime.now();

      final result = await ServerAPI().refreshtoken();
      if (result != null && result['result'] == 0) {
        debugPrint('refreshAccessToken: token refreshed successfully');

        // 연결 됐음을 알려주고
        setLoginOK(true);
        _wsClient.authenticate();

        return true;
      } else {
        debugPrint(
            'refreshAccessToken: token refresh failed - ${result?['error']}');

        // refresh token이 실패하면 재로그인 필요
        if (result?['error'] == 'invalid_token' ||
            result?['error'] == 'expired_token') {
          // 로그아웃 처리
          _acctMgr.doLogout();
          setLoginOK(false);
        }

        return false;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> checkAccessToken() async {
    if (_acctMgr.acct.accesstoken.isNotNullEmptyOrWhitespace &&
        !_acctMgr.isAccessTokenValid()) {
      return await refreshAccessToken();
    }
    return true;
  }

  Timer? _accessTokenRefreshTimer;

  void armAccessTokenRefreshTimer() {
    if (!_acctMgr.isAccessTokenExists) {
      debugPrint('armAccessTokenRefreshTimer: empty token');
      return;
    }

    int remainTime = _acctMgr.accessTokenExpireTime;
    if (remainTime > 0) {
      _accessTokenRefreshTimer?.cancel();

      debugPrint(
          'armAccessTokenRefreshTimer: token refresh after ${remainTime} seconds');

      _accessTokenRefreshTimer =
          Timer(Duration(seconds: remainTime - 5 * 60), onRefreshAccessToken);
    } else {
      debugPrint('armAccessTokenRefreshTimer: token is not valid');
    }
  }

  void onRefreshAccessToken() async {
    if (!_acctMgr.isAccessTokenExists) return;

    final remainTime = _acctMgr.accessTokenExpireTime;
    // 이미 refresh가 되어 충분히 시간이 많이 남은 경우
    if (remainTime <= 5 * 60) {
      debugPrint('onRefreshAccessToken: short time ${remainTime}. refresh it');

      await refreshAccessToken();
    } else {
      debugPrint(
          'onRefreshAccessToken: remainTime is enough (${remainTime} sec). skip');
    }

    if ((_accessTokenRefreshTimer?.isActive ?? false) == false) {
      armAccessTokenRefreshTimer();
    }
  }

  Future<void> logout({bool notifyToServer = false}) async {
    // 유저가 logout을 명시적으로 한 경우만 서버에 로그아웃 요청
    if (notifyToServer) {
      await ServerAPI().logout();
    }

    _acctMgr.doLogout();
    setLoginOK(false);

    // Note: 웹소켓 접속 관련.
    // logout시키면 서버에서 연결되어 있는 websocket을 끊어버림.
    // 클라이언트는 웹소켓에서 'logout' 메시지를 받은후 재접속을 시도하면 됨.
  }

  Future<bool> openLoginPopup(BuildContext context) async {
    //return await openLoginDialog(context: context);
    return false;
  }

  Future<bool> checkAuthenticated(BuildContext context) async {
    if (!isLoginOK) {
      debugPrint('checkAuthenticated: not logged in. open Login popup');

      if (_acctMgr.isRefreshTokenValid()) {
        if (await refreshAccessToken(forceUpdate: true)) return true;
      }

      if (await openLoginPopup(context) == false) {
        return false;
      }
    } else if (await checkAccessToken() == false) {
      debugPrint(
          'checkAuthenticated: invalid access token or fail to refresh token.  open Login popup');
      Util.toastError('Fail to refresh token');
      if (await openLoginPopup(context) == false) {
        return false;
      }
    } else {
      debugPrint('checkAuthenticated: in authenticated state');
    }
    return true;
  }

  Timer? _pauseTimer;
  bool _isPauseFired = false;

  void pause() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(Duration(seconds: 60), () {
      _isPauseFired = true;
      if (!isLoginOK) {
        debugPrint('AuthManager.pause: disconnect!');
        _wsClient.disconnect();
      } else {
        debugPrint('AuthManager.pause: send PAUSE message');
      }
    });

    debugPrint('AuthManager.pause: timer armed');
  }

  DateTime? _lastResumeTime;

  Future resume() async {
    if (_wsClient.isConnected &&
        _lastResumeTime != null &&
        DateTime.now().difference(_lastResumeTime!).inSeconds < 60) {
      debugPrint(
          'AuthManager.resume: too short request in ${DateTime.now().difference(_lastResumeTime!).inSeconds} sec');
      return;
    }

    _lastResumeTime = DateTime.now();

    _pauseTimer?.cancel();
    _pauseTimer = null;

    // 토큰이 만료됐을 수 있어서 체크
    await checkAccessToken();

    // 소켓이 끊겨 있으면 재접속
    await _wsClient.authenticate();

    if (_isPauseFired) {
      _isPauseFired = false;

      // 서버에게 RESUME 보내줄 것
    }

    debugPrint('AuthManager.resume: done');
  }

  //
  // 중복 로그인으로 인해 토큰이 무효화 된 상황
  // - accesstoken 클리어 해줌
  // - accesstoken 갱신 타이머 설정된 거 캔슬
  // - 로그인 된거 꺼줌
  void invalidateAccessToken() {
    _acctMgr.clearAccessToken();
    setLoginOK(false);
    _accessTokenRefreshTimer?.cancel();
  }
}
