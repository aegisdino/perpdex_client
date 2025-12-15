import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// NEAR 지갑 추상 클래스
/// Meteor Wallet, NEAR Wallet 등의 구현체가 이를 상속
abstract class NearWallet {
  String? _connectedAddress;
  String? _networkId; // 'mainnet' or 'testnet'

  String? get connectedAddress => _connectedAddress;
  String? get networkId => _networkId;

  bool get isConnected => _connectedAddress != null;

  /// 지갑 연결
  Future<String?> connect();

  /// 지갑 연결 해제
  Future<void> disconnect();

  /// NEAR 잔액 조회 (yoctoNEAR 단위, 1 NEAR = 10^24 yoctoNEAR)
  Future<BigInt> getBalance(String accountId);

  /// 트랜잭션 전송
  Future<String> sendTransaction({
    required String receiverId,
    required List<Map<String, dynamic>> actions,
  });

  /// 메시지 서명
  Future<String> signMessage(String message);

  /// Nonce 기반 인증 서명 수행
  /// 모든 지갑에서 공통으로 사용 가능
  /// @return (signature, nonce, message) 튜플
  Future<(String signature, String nonce, String message)> signAuthMessage() async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    // 서버 또는 클라이언트에서 Nonce 요청
    final nonceData = await AuthService.requestNonce(
      namespace: 'near',
      address: connectedAddress!,
    );

    final nonce = nonceData['nonce']!;
    final message = nonceData['message']!;

    debugPrint('[${runtimeType}] Nonce received: $nonce');
    debugPrint('[${runtimeType}] Signing message...');

    try {
      // 서명 요청
      final signature = await signMessage(message);
      debugPrint('[${runtimeType}] Signature received: ${signature.substring(0, 20)}...');

      return (signature, nonce, message);
    } catch (e) {
      debugPrint('[${runtimeType}] Signature failed: $e');
      rethrow;
    }
  }

  /// 서명 검증 및 서버 인증
  /// @return AuthVerifyResult (서버 모드) 또는 null (클라이언트 모드)
  Future<AuthVerifyResult?> verifyAuthSignature({
    required String signature,
    required String nonce,
  }) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    return await AuthService.verifySignature(
      namespace: 'near',
      address: connectedAddress!,
      signature: signature,
      nonce: nonce,
      chainId: networkId,
    );
  }

  /// 계정 변경 리스너
  Stream<String?> get onAccountsChanged;

  /// 네트워크 변경 리스너
  Stream<String?> get onNetworkChanged;

  /// 연결 해제 리스너
  Stream<void> get onDisconnect;

  void setConnectedAddress(String? address) {
    _connectedAddress = address;
  }

  void setNetworkId(String? networkId) {
    _networkId = networkId;
  }
}

/// NEAR 네트워크 정보
class NearNetwork {
  final String networkId;
  final String nodeUrl;
  final String walletUrl;
  final String helperUrl;
  final String explorerUrl;

  const NearNetwork({
    required this.networkId,
    required this.nodeUrl,
    required this.walletUrl,
    required this.helperUrl,
    required this.explorerUrl,
  });

  /// 주요 네트워크 상수
  static const mainnet = NearNetwork(
    networkId: 'mainnet',
    nodeUrl: 'https://rpc.mainnet.near.org',
    walletUrl: 'https://wallet.near.org',
    helperUrl: 'https://helper.mainnet.near.org',
    explorerUrl: 'https://explorer.near.org',
  );

  static const testnet = NearNetwork(
    networkId: 'testnet',
    nodeUrl: 'https://rpc.testnet.near.org',
    walletUrl: 'https://wallet.testnet.near.org',
    helperUrl: 'https://helper.testnet.near.org',
    explorerUrl: 'https://explorer.testnet.near.org',
  );
}
