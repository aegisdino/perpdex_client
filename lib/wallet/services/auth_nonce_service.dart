import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:uuid/uuid.dart';

/// Nonce 기반 지갑 인증 서비스
/// - UUID nonce 생성 및 관리
/// - SessionStorage를 이용한 nonce 재사용 방지
/// - 서명 메시지 생성 및 검증
class AuthNonceService {
  static const _uuid = Uuid();
  static const _storageKey = 'wallet_auth_nonces';

  /// 새로운 nonce 생성
  /// 브라우저 세션 동안 유효한 UUID 반환
  static String generateNonce() {
    final nonce = _uuid.v4();
    _storeNonce(nonce);
    return nonce;
  }

  /// 서명용 메시지 생성
  /// EIP-191 표준 형식을 따르는 간단한 메시지
  /// Aster DEX 스타일: "You are signing into [Platform] [Nonce]"
  static String createSignatureMessage({
    required String walletAddress,
    required String nonce,
  }) {
    // nonce의 마지막 6자리를 숫자로 사용 (Aster DEX 스타일)
    final nonceNumber = nonce.replaceAll('-', '').substring(0, 6);

    return 'You are signing into DEX Trading Platform $nonceNumber';
  }

  /// Nonce가 유효한지 확인 (아직 사용되지 않았는지)
  /// @param nonce 검증할 nonce
  /// @return true if valid (not used), false if already used or not found
  static bool isNonceValid(String nonce) {
    final usedNonces = _getUsedNonces();
    return !usedNonces.contains(nonce);
  }

  /// Nonce를 사용된 것으로 표시
  /// 재사용 공격 방지를 위해 사용된 nonce 기록
  static void markNonceAsUsed(String nonce) {
    final usedNonces = _getUsedNonces();
    if (!usedNonces.contains(nonce)) {
      usedNonces.add(nonce);
      _saveUsedNonces(usedNonces);
    }
  }

  /// SessionStorage에서 사용된 nonce 목록 가져오기
  static Set<String> _getUsedNonces() {
    try {
      final stored = web.window.sessionStorage.getItem(_storageKey);
      if (stored == null || stored.isEmpty) {
        return <String>{};
      }
      final List<dynamic> list = jsonDecode(stored);
      return Set<String>.from(list);
    } catch (e) {
      return <String>{};
    }
  }

  /// SessionStorage에 사용된 nonce 저장
  static void _saveUsedNonces(Set<String> nonces) {
    try {
      final json = jsonEncode(nonces.toList());
      web.window.sessionStorage.setItem(_storageKey, json);
    } catch (e) {
      // SessionStorage 사용 불가 시 무시 (모바일 등)
    }
  }

  /// Nonce를 pending 상태로 저장 (생성 시점)
  static void _storeNonce(String nonce) {
    // 생성된 nonce를 별도 키로 저장하여 나중에 검증 가능하게 함
    try {
      web.window.sessionStorage.setItem('pending_nonce_$nonce', DateTime.now().toIso8601String());
    } catch (e) {
      // SessionStorage 사용 불가 시 무시
    }
  }

  /// Pending nonce가 존재하는지 확인
  static bool isPendingNonceExists(String nonce) {
    try {
      final value = web.window.sessionStorage.getItem('pending_nonce_$nonce');
      return value != null;
    } catch (e) {
      return false;
    }
  }

  /// Pending nonce 제거
  static void removePendingNonce(String nonce) {
    try {
      web.window.sessionStorage.removeItem('pending_nonce_$nonce');
    } catch (e) {
      // 무시
    }
  }

  /// 모든 인증 데이터 초기화 (로그아웃 시)
  static void clearAll() {
    try {
      web.window.sessionStorage.removeItem(_storageKey);

      // pending nonce들도 모두 제거
      final storage = web.window.sessionStorage;
      final keysToRemove = <String>[];

      for (var i = 0; i < storage.length; i++) {
        final key = storage.key(i);
        if (key != null && key.startsWith('pending_nonce_')) {
          keysToRemove.add(key);
        }
      }

      for (final key in keysToRemove) {
        storage.removeItem(key);
      }
    } catch (e) {
      // 무시
    }
  }
}
