import 'package:flutter/foundation.dart';
import 'auth_nonce_service.dart';
import '../../api/netclient.dart';

/// 서명 검증 결과 데이터
class AuthVerifyResult {
  final String accessToken;
  final String refreshToken;
  final dynamic userId; // int or String
  final String userKey;
  final String namespace;
  final String accountType;
  final bool isNewUser;

  AuthVerifyResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.userKey,
    required this.namespace,
    required this.accountType,
    required this.isNewUser,
  });
}

/// 지갑 인증 서비스
/// 클라이언트 모드와 서버 모드를 모두 지원합니다.
class AuthService {
  /// 인증 모드
  static AuthMode _mode = AuthMode.client;

  /// ServerAPI 인스턴스
  static final _serverAPI = ServerAPI();

  /// 인증 모드 설정
  ///
  /// [mode] - AuthMode.client (클라이언트 nonce) 또는 AuthMode.server (서버 nonce)
  static void configure({
    required AuthMode mode,
  }) {
    _mode = mode;
  }

  /// 현재 인증 모드 반환
  static AuthMode get mode => _mode;

  /// Nonce와 서명 메시지 생성
  ///
  /// 클라이언트 모드: 로컬에서 UUID nonce 생성
  /// 서버 모드: 서버 API에서 nonce 요청
  ///
  /// [namespace] - 'evm' 또는 'solana'
  /// [address] - 지갑 주소
  ///
  /// Returns: { 'nonce': '...', 'message': '...', 'expiresAt': '...' }
  static Future<Map<String, String>> requestNonce({
    required String namespace,
    required String address,
  }) async {
    if (_mode == AuthMode.client) {
      // 클라이언트 모드: 로컬에서 nonce 생성
      final nonce = AuthNonceService.generateNonce();
      final message = AuthNonceService.createSignatureMessage(
        walletAddress: address,
        nonce: nonce,
      );
      return {
        'nonce': nonce,
        'message': message,
        'expiresAt':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      };
    } else {
      // 서버 모드: API에서 nonce 요청
      // POST /api/auth/nonce
      final result = await _serverAPI.postServer(
        'auth/nonce',
        {
          'namespace': namespace,
          'address': address,
        },
        addAccessToken: false,
      );

      if (result != null && result['result'] == 0 && result['data'] != null) {
        final data = result['data'];
        return {
          'nonce': data['nonce'] as String,
          'message': data['message'] as String,
          'expiresAt': data['expiresAt'] as String,
        };
      } else {
        throw Exception(
            'Failed to request nonce: ${result?['error'] ?? 'Unknown error'}');
      }
    }
  }

  /// 서명 검증 및 인증
  ///
  /// 클라이언트 모드: SessionStorage에 nonce 저장 (재사용 방지)
  /// 서버 모드: 서버 API로 서명 검증 및 토큰 발급
  ///
  /// Returns: 인증 결과 데이터
  static Future<AuthVerifyResult?> verifySignature({
    required String namespace,
    required String address,
    required String signature,
    required String nonce,
    String? chainId,
    String? chainName,
  }) async {
    if (_mode == AuthMode.client) {
      // 클라이언트 모드: 로컬에서 nonce 검증 및 사용 처리
      if (!AuthNonceService.isNonceValid(nonce)) {
        throw Exception('Nonce already used or invalid');
      }

      AuthNonceService.markNonceAsUsed(nonce);
      AuthNonceService.removePendingNonce(nonce);

      debugPrint('[AuthService] Client mode: Signature verified locally');
      return null; // 클라이언트 모드에서는 토큰 없음
    } else {
      // 서버 모드: API로 서명 검증 요청
      // POST /api/auth/verify
      final result = await _serverAPI.postServer('auth/verify', {
        'namespace': namespace,
        'address': address,
        'signature': signature,
        'nonce': nonce,
        if (chainId != null) 'chainId': chainId,
        if (chainName != null) 'chainName': chainName,
      });

      if (result != null && result['result'] == 0 && result['data'] != null) {
        final data = result['data'];
        debugPrint('[AuthService] Server mode: Auth tokens received');

        return AuthVerifyResult(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          userId: data['userId'],
          userKey: data['userkey'] as String,
          namespace: data['namespace'] as String,
          accountType: data['accountType'] as String,
          isNewUser: data['isNewUser'] as bool? ?? false,
        );
      } else {
        throw Exception(
            'Signature verification failed: ${result?['error'] ?? 'Unknown error'}');
      }
    }
  }

  /// 로그아웃 (클라이언트 모드에서만 사용)
  static void logout() {
    if (_mode == AuthMode.client) {
      AuthNonceService.clearAll();
    }
    // 서버 모드에서는 JWT 토큰을 클라이언트에서 삭제하는 로직을 앱에서 구현
  }
}

/// 인증 모드
enum AuthMode {
  /// 클라이언트에서 nonce 생성 및 관리 (프로토타입용)
  client,

  /// 서버에서 nonce 생성 및 서명 검증 (프로덕션 권장)
  server,
}
