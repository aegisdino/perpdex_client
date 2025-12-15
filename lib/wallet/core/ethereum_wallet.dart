import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';

import '../services/auth_service.dart';

/// Ethereum 지갑 추상 클래스
/// MetaMask, WalletConnect 등의 구현체가 이를 상속
abstract class EthereumWallet {
  String? _connectedAddress;
  String? _chainId;

  String? get connectedAddress => _connectedAddress;
  String? get chainId => _chainId;

  bool get isConnected => _connectedAddress != null;

  /// 지갑 연결
  Future<String?> connect();

  /// 지갑 연결 해제
  Future<void> disconnect();

  /// ETH 잔액 조회 (Wei 단위)
  Future<BigInt> getBalance(String address);

  /// 트랜잭션 전송
  Future<String> sendTransaction({
    required String to,
    required BigInt value, // Wei 단위
    Uint8List? data,
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
      namespace: 'evm',
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
      namespace: 'evm',
      address: connectedAddress!,
      signature: signature,
      nonce: nonce,
      chainId: chainId,
    );
  }

  /// 타입화된 데이터 서명 (EIP-712)
  Future<String> signTypedData(String typedData);

  /// 체인 변경
  Future<void> switchChain(String chainId);

  /// 네트워크 추가
  Future<void> addNetwork({
    required String chainId,
    required String chainName,
    required String rpcUrl,
    required String currencyName,
    required String currencySymbol,
    required int currencyDecimals,
    String? blockExplorerUrl,
  });

  /// 계정 변경 리스너
  Stream<String?> get onAccountsChanged;

  /// 체인 변경 리스너
  Stream<String?> get onChainChanged;

  /// 연결 해제 리스너
  Stream<void> get onDisconnect;

  void setConnectedAddress(String? address) {
    _connectedAddress = address;
  }

  void setChainId(String? chainId) {
    _chainId = chainId;
  }
}

/// Ethereum 네트워크 정보
class EthereumNetwork {
  final String chainId;
  final String chainName;
  final String rpcUrl;
  final String currencyName;
  final String currencySymbol;
  final int currencyDecimals;
  final String? blockExplorerUrl;

  const EthereumNetwork({
    required this.chainId,
    required this.chainName,
    required this.rpcUrl,
    required this.currencyName,
    required this.currencySymbol,
    required this.currencyDecimals,
    this.blockExplorerUrl,
  });

  /// 주요 네트워크 상수
  static const mainnet = EthereumNetwork(
    chainId: '0x1',
    chainName: 'Ethereum Mainnet',
    rpcUrl: 'https://ethereum.publicnode.com',
    currencyName: 'Ethereum',
    currencySymbol: 'ETH',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://etherscan.io',
  );

  static const sepolia = EthereumNetwork(
    chainId: '0xaa36a7',
    chainName: 'Sepolia Testnet',
    rpcUrl: 'https://ethereum-sepolia.publicnode.com',
    currencyName: 'Sepolia ETH',
    currencySymbol: 'ETH',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://sepolia.etherscan.io',
  );

  static const arbitrum = EthereumNetwork(
    chainId: '0xa4b1',
    chainName: 'Arbitrum One',
    rpcUrl: 'https://arbitrum-one.publicnode.com',
    currencyName: 'Ethereum',
    currencySymbol: 'ETH',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://arbiscan.io',
  );

  static const optimism = EthereumNetwork(
    chainId: '0xa',
    chainName: 'Optimism',
    rpcUrl: 'https://optimism.publicnode.com',
    currencyName: 'Ethereum',
    currencySymbol: 'ETH',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://optimistic.etherscan.io',
  );

  static const polygon = EthereumNetwork(
    chainId: '0x89',
    chainName: 'Polygon',
    rpcUrl: 'https://polygon-bor.publicnode.com',
    currencyName: 'MATIC',
    currencySymbol: 'MATIC',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://polygonscan.com',
  );

  static const base = EthereumNetwork(
    chainId: '0x2105',
    chainName: 'Base',
    rpcUrl: 'https://base.publicnode.com',
    currencyName: 'Ethereum',
    currencySymbol: 'ETH',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://basescan.org',
  );
}
