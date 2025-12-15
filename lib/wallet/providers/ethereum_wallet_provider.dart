import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/notice.dart';
import '../core/ethereum_wallet.dart';
import '../services/auth_service.dart';
import '../wallets/metamask_wallet.dart'
    if (dart.library.io) '../wallets/metamask_mobile.dart';
import '../wallets/phantom_ethereum_wallet.dart'
    if (dart.library.io) '../wallets/phantom_mobile.dart';
import '../wallets/coinbase_wallet.dart'
    if (dart.library.io) '../wallets/coinbase_mobile.dart';
import '../wallets/trust_wallet.dart'
    if (dart.library.io) '../wallets/trust_mobile.dart';
import '../wallets/walletconnect_wallet.dart'
    if (dart.library.io) '../wallets/walletconnect_mobile.dart';
import '../../data/account.dart';
import '../../auth/authmanager.dart';
import '../../common/util.dart';

/// Ethereum 지갑 연결 상태
class EthereumWalletState {
  final String? address;
  final String? chainId;
  final BigInt? balance;
  final String? walletType; // 'metamask', 'walletconnect'
  final bool isConnecting;
  final bool isAuthenticating; // 서명 인증 중
  final bool isAuthenticated; // 서명 인증 완료
  final String? error;

  const EthereumWalletState({
    this.address,
    this.chainId,
    this.balance,
    this.walletType,
    this.isConnecting = false,
    this.isAuthenticating = false,
    this.isAuthenticated = false,
    this.error,
  });

  // 지갑이 연결되었는지 (1단계: 주소만 획득)
  bool get isWalletConnected => address != null;

  // 완전히 연결되고 인증까지 완료되었는지 (2단계: 서명까지 완료)
  bool get isConnected => address != null && isAuthenticated;

  EthereumWalletState copyWith({
    String? address,
    String? chainId,
    BigInt? balance,
    String? walletType,
    bool? isConnecting,
    bool? isAuthenticating,
    bool? isAuthenticated,
    String? error,
  }) {
    return EthereumWalletState(
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      balance: balance ?? this.balance,
      walletType: walletType ?? this.walletType,
      isConnecting: isConnecting ?? this.isConnecting,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error ?? this.error,
    );
  }

  EthereumWalletState clearError() {
    return copyWith(error: null);
  }

  @override
  String toString() {
    return 'EthereumWalletState(address: $address, chainId: $chainId, balance: $balance, walletType: $walletType, isConnecting: $isConnecting, isAuthenticating: $isAuthenticating, isAuthenticated: $isAuthenticated, error: $error)';
  }
}

/// Ethereum 지갑 Notifier
class EthereumWalletNotifier extends Notifier<EthereumWalletState> {
  EthereumWallet? _wallet;

  @override
  EthereumWalletState build() {
    // 초기 상태
    return const EthereumWalletState();
  }

  /// MetaMask 연결
  ///
  /// [autoAuthenticate] - true: 연결 후 자동으로 서명 인증 (기본값)
  ///                     false: 연결만 하고 인증은 나중에 authenticate() 호출
  ///
  /// Returns: 연결 성공 여부
  Future<bool> connectMetaMask({bool autoAuthenticate = true}) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      // conditional import로 Web에서는 metamask_wallet.dart,
      // 모바일에서는 metamask_mobile.dart의 MetaMaskWallet이 사용됨
      final wallet = MetaMaskWallet();
      _wallet = wallet;

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 1단계: 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: 'metamask',
          isConnecting: false,
        );

        // 2단계: 서명 인증 (옵션)
        if (autoAuthenticate) {
          await _authenticateWallet();

          // 인증 성공 후 잔액 조회
          if (state.isAuthenticated) {
            await updateBalance();
          }
        }

        return true; // 연결 성공
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to connect MetaMask',
        );
        return false; // 연결 실패
      }
    } catch (e, stackTrace) {
      debugPrint('MetaMask connection error: $e');
      debugPrint('Stack trace: $stackTrace');

      // JS 에러 객체 처리
      String errorMessage = 'Failed to connect MetaMask';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false; // 연결 실패
    }
  }

  /// 수동 서명 인증 (2단계)
  /// 지갑 연결 후 autoAuthenticate=false로 연결한 경우,
  /// 이 메서드를 호출하여 서명 인증을 수행합니다.
  Future<void> authenticate() async {
    if (state.address == null) {
      throw Exception('Wallet not connected. Please connect wallet first.');
    }

    if (state.isAuthenticated) {
      debugPrint('[Auth] Already authenticated');
      return;
    }

    await _authenticateWallet();

    // 인증 성공 후 잔액 조회
    if (state.isAuthenticated) {
      await updateBalance();
    }
  }

  /// 자동 재연결 (토큰 로그인 후)
  ///
  /// 토큰 로그인 성공 후 저장된 지갑 정보를 바탕으로 지갑을 재연결합니다.
  /// 서명 없이 주소만 확인하여 연결 상태를 복원합니다.
  ///
  /// [expectedAddress] - 서버에 저장된 지갑 주소
  /// [walletType] - 지갑 타입 ('metamask', 'phantom', 'coinbase', 'trustwallet')
  ///
  /// Returns: 재연결 성공 여부
  Future<bool> autoReconnect({
    required String expectedAddress,
    String? walletType,
  }) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      debugPrint('[Wallet] Auto-reconnecting wallet...');
      debugPrint('[Wallet] Expected address: $expectedAddress');
      debugPrint('[Wallet] Wallet type: $walletType');

      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      // 지갑 타입에 따라 적절한 지갑 생성
      EthereumWallet? wallet;
      String effectiveWalletType = walletType ?? 'metamask';

      switch (effectiveWalletType.toLowerCase()) {
        case 'metamask':
          wallet = MetaMaskWallet();
          break;
        case 'phantom':
          wallet = PhantomEthereumWallet();
          break;
        case 'coinbase':
          wallet = CoinbaseWallet();
          break;
        case 'trustwallet':
          wallet = TrustWallet();
          break;
        case 'walletconnect':
          wallet = WalletConnectWallet();
          break;
        default:
          debugPrint(
              '[Wallet] Unknown wallet type: $effectiveWalletType, defaulting to MetaMask');
          wallet = MetaMaskWallet();
          effectiveWalletType = 'metamask';
      }

      _wallet = wallet;

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        // 주소 검증 (대소문자 구분 없이 비교)
        if (address.toLowerCase() != expectedAddress.toLowerCase()) {
          debugPrint('[Wallet] ⚠️ Address mismatch!');
          debugPrint('[Wallet] Expected: $expectedAddress');
          debugPrint('[Wallet] Connected: $address');

          // 주소 불일치 시 연결 해제
          await disconnect();

          state = state.copyWith(
            isConnecting: false,
            error:
                'Wallet address mismatch. Expected: $expectedAddress, Got: $address',
          );
          return false;
        }

        // 주소 일치 - 연결 성공 및 자동 인증 완료 상태로 설정
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: effectiveWalletType,
          isConnecting: false,
          isAuthenticated: true, // 토큰 인증이 이미 완료되었으므로 true
        );

        debugPrint('[Wallet] ✅ Auto-reconnect successful');
        debugPrint('[Wallet] Address: $address');
        debugPrint('[Wallet] Chain ID: ${wallet.chainId}');

        // 잔액 조회
        await updateBalance();

        return true;
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to auto-reconnect wallet',
        );
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[Wallet] Auto-reconnect error: $e');
      debugPrint('[Wallet] Stack trace: $stackTrace');

      String errorMessage = 'Failed to auto-reconnect wallet';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false;
    }
  }

  /// Phantom 연결
  ///
  /// [autoAuthenticate] - true: 연결 후 자동으로 서명 인증 (기본값)
  ///                     false: 연결만 하고 인증은 나중에 authenticate() 호출
  ///
  /// Returns: 연결 성공 여부
  Future<bool> connectPhantom({bool autoAuthenticate = true}) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      // conditional import로 Web에서는 phantom_ethereum_wallet.dart,
      // 모바일에서는 phantom_mobile.dart의 PhantomEthereumWallet이 사용됨
      final wallet = PhantomEthereumWallet();
      _wallet = wallet;

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 1단계: 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: 'phantom',
          isConnecting: false,
        );

        // 2단계: 서명 인증 (옵션)
        if (autoAuthenticate) {
          await _authenticateWallet();

          // 인증 성공 후 잔액 조회
          if (state.isAuthenticated) {
            await updateBalance();
          }
        }

        return true; // 연결 성공
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to connect Phantom',
        );
        return false; // 연결 실패
      }
    } catch (e, stackTrace) {
      debugPrint('Phantom connection error: $e');
      debugPrint('Stack trace: $stackTrace');

      // JS 에러 객체 처리
      String errorMessage = 'Failed to connect Phantom';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false; // 연결 실패
    }
  }

  /// Coinbase Wallet 연결
  ///
  /// [autoAuthenticate] - true: 연결 후 자동으로 서명 인증 (기본값)
  ///                     false: 연결만 하고 인증은 나중에 authenticate() 호출
  ///
  /// Returns: 연결 성공 여부
  Future<bool> connectCoinbase({bool autoAuthenticate = true}) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      final wallet = CoinbaseWallet();
      _wallet = wallet;

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 1단계: 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: 'coinbase',
          isConnecting: false,
        );

        // 2단계: 서명 인증 (옵션)
        if (autoAuthenticate) {
          await _authenticateWallet();

          // 인증 성공 후 잔액 조회
          if (state.isAuthenticated) {
            await updateBalance();
          }
        }

        return true; // 연결 성공
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to connect Coinbase Wallet',
        );
        return false; // 연결 실패
      }
    } catch (e, stackTrace) {
      debugPrint('Coinbase Wallet connection error: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Failed to connect Coinbase Wallet';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false; // 연결 실패
    }
  }

  /// Trust Wallet 연결
  ///
  /// [autoAuthenticate] - true: 연결 후 자동으로 서명 인증 (기본값)
  ///                     false: 연결만 하고 인증은 나중에 authenticate() 호출
  ///
  /// Returns: 연결 성공 여부
  Future<bool> connectTrustWallet({bool autoAuthenticate = true}) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      final wallet = TrustWallet();
      _wallet = wallet;

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 1단계: 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: 'trustwallet',
          isConnecting: false,
        );

        // 2단계: 서명 인증 (옵션)
        if (autoAuthenticate) {
          await _authenticateWallet();

          // 인증 성공 후 잔액 조회
          if (state.isAuthenticated) {
            await updateBalance();
          }
        }

        return true; // 연결 성공
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to connect Trust Wallet',
        );
        return false; // 연결 실패
      }
    } catch (e, stackTrace) {
      debugPrint('Trust Wallet connection error: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Failed to connect Trust Wallet';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false; // 연결 실패
    }
  }

  /// 지갑 서명 인증 과정 (Nonce 기반)
  /// DEX 사이트 연결을 위한 서명
  /// AuthService를 통해 클라이언트/서버 모드 모두 지원
  Future<void> _authenticateWallet() async {
    if (_wallet == null || state.address == null) {
      state = state.copyWith(error: 'Wallet not connected');
      return;
    }

    state = state.copyWith(isAuthenticating: true, error: null);

    try {
      debugPrint(
          '[Auth] Starting nonce-based authentication (${AuthService.mode} mode)');

      // 1. 서명 메시지 생성 및 서명 (EthereumWallet의 signAuthMessage 사용)
      final (signature, nonce, message) = await _wallet!.signAuthMessage();

      debugPrint('[Auth] Signature received: ${signature.substring(0, 20)}...');

      // 2. 서명 검증 및 서버 인증
      final authResult = await _wallet!.verifyAuthSignature(
        signature: signature,
        nonce: nonce,
      );

      if (authResult != null) {
        // 서버 모드: 토큰 저장
        debugPrint('[Auth] Server mode: Saving auth tokens');
        debugPrint('[Auth] User ID: ${authResult.userId}');
        debugPrint('[Auth] User Key: ${authResult.userKey}');
        debugPrint('[Auth] Is New User: ${authResult.isNewUser}');

        // AccountManager에 토큰 및 사용자 정보 저장
        final accountManager = AccountManager();
        await accountManager.saveAuthTokens(
          accessToken: authResult.accessToken,
          refreshToken: authResult.refreshToken,
          userId: authResult.userId,
          userKey: authResult.userKey,
          walletAddress: state.address,
          walletType: state.walletType, // 'metamask', 'phantom', etc.
        );

        debugPrint('[Auth] Tokens saved to AccountManager');
        debugPrint('[Auth] Wallet type: ${state.walletType}');
      } else {
        debugPrint('[Auth] Client mode: Local verification completed');
      }

      // 인증 완료
      state = state.copyWith(
        isAuthenticating: false,
        isAuthenticated: true,
      );

      debugPrint('[Auth] Wallet authentication completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[Auth] Wallet authentication error: $e');
      debugPrint('[Auth] Stack trace: $stackTrace');

      // 사용자 친화적인 에러 메시지 생성
      String userMessage = 'Authentication failed';
      final errorStr = e.toString();

      if (errorStr.contains('User rejected') ||
          errorStr.contains('rejected the request') ||
          errorStr.contains('User denied')) {
        userMessage = 'Signature request was rejected';
      } else if (errorStr.contains('timeout')) {
        userMessage = 'Authentication timeout';
      }

      // 사용자에게 토스트 알림 표시
      Util.toastNotice(
        userMessage,
        center: true,
        error: true,
      );

      // 우상단에 에러 알림 표시
      addNotice(message: userMessage, seconds: 5, error: true);

      // 연결 해제
      await disconnect();

      // 인증 실패 상태 설정 (disconnect 후에 설정해야 상태가 제대로 반영됨)
      state = state.copyWith(
        isConnecting: false,
        isAuthenticating: false,
        isAuthenticated: false,
        error: 'Authentication failed: ${e.toString()}',
      );
    }
  }

  /// WalletConnect 연결
  ///
  /// [autoAuthenticate] - true: 연결 후 자동으로 서명 인증 (기본값)
  ///                     false: 연결만 하고 인증은 나중에 authenticate() 호출
  /// [context] - Flutter BuildContext (WalletConnect 모달 표시에 필요)
  ///
  /// Returns: 연결 성공 여부
  Future<bool> connectWalletConnect({
    bool autoAuthenticate = true,
    required BuildContext context,
  }) async {
    if (state.isConnecting) return false;

    state = state.copyWith(isConnecting: true, error: null);

    try {
      // 기존 지갑이 있으면 정리
      _disposeCurrentWallet();

      final wallet = WalletConnectWallet();
      _wallet = wallet;

      // WalletConnect는 context 설정 필요
      wallet.setContext(context);

      // 이벤트 리스너 설정
      _setupWalletListeners(wallet);

      // 1단계: 지갑 연결 (주소 획득)
      final address = await wallet.connect();

      if (address != null) {
        state = state.copyWith(
          address: address,
          chainId: wallet.chainId,
          walletType: 'walletconnect',
          isConnecting: false,
        );

        // 2단계: 서명 인증 (옵션)
        if (autoAuthenticate) {
          await _authenticateWallet();

          // 인증 성공 후 잔액 조회
          if (state.isAuthenticated) {
            await updateBalance();
          }
        }

        return true; // 연결 성공
      } else {
        state = state.copyWith(
          isConnecting: false,
          error: 'Failed to connect WalletConnect',
        );
        return false; // 연결 실패
      }
    } catch (e, stackTrace) {
      debugPrint('WalletConnect connection error: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'Failed to connect WalletConnect';
      if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = e.toString();
      }

      state = state.copyWith(
        isConnecting: false,
        error: errorMessage,
      );
      return false; // 연결 실패
    }
  }

  /// 기존 지갑 정리
  void _disposeCurrentWallet() {
    if (_wallet == null) return;

    try {
      if (_wallet is MetaMaskWallet) {
        (_wallet as MetaMaskWallet).dispose();
      }
      // 향후 다른 지갑 타입도 여기에 추가
    } catch (e) {
      debugPrint('Dispose wallet error: $e');
    }
  }

  /// 지갑 연결 해제
  Future<void> disconnect() async {
    try {
      await _wallet?.disconnect();
      _disposeCurrentWallet();
      _wallet = null;
      state = const EthereumWalletState();

      // 서버에 로그아웃 알림 (토큰 무효화)
      AuthManager().logout(notifyToServer: true);
      debugPrint('Disconnect from server done');
    } catch (e) {
      debugPrint('Disconnect error: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// 잔액 업데이트
  Future<void> updateBalance() async {
    if (_wallet == null || state.address == null) return;

    try {
      final balance = await _wallet!.getBalance(state.address!);
      state = state.copyWith(balance: balance);
    } catch (e) {
      debugPrint('Get balance error: $e');
    }
  }

  /// 트랜잭션 전송
  Future<String?> sendTransaction({
    required String to,
    required BigInt value,
    Uint8List? data,
  }) async {
    if (_wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final txHash = await _wallet!.sendTransaction(
        to: to,
        value: value,
        data: data,
      );

      // 트랜잭션 후 잔액 업데이트 (5초 후)
      Future.delayed(const Duration(seconds: 5), () {
        updateBalance();
      });

      return txHash;
    } catch (e) {
      debugPrint('Send transaction error: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 메시지 서명
  Future<String?> signMessage(String message) async {
    if (_wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      return await _wallet!.signMessage(message);
    } catch (e) {
      debugPrint('Sign message error: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 타입화된 데이터 서명 (EIP-712)
  Future<String?> signTypedData(String typedData) async {
    if (_wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      return await _wallet!.signTypedData(typedData);
    } catch (e) {
      debugPrint('Sign typed data error: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 체인 전환
  Future<void> switchChain(String chainId) async {
    if (_wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      await _wallet!.switchChain(chainId);
      state = state.copyWith(chainId: chainId);
    } catch (e) {
      debugPrint('Switch chain error: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 네트워크 추가
  Future<void> addNetwork(EthereumNetwork network) async {
    if (_wallet == null) {
      throw Exception('Wallet not connected');
    }

    try {
      await _wallet!.addNetwork(
        chainId: network.chainId,
        chainName: network.chainName,
        rpcUrl: network.rpcUrl,
        currencyName: network.currencyName,
        currencySymbol: network.currencySymbol,
        currencyDecimals: network.currencyDecimals,
        blockExplorerUrl: network.blockExplorerUrl,
      );
    } catch (e) {
      debugPrint('Add network error: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// 에러 초기화
  void clearError() {
    state = state.clearError();
  }

  /// 지갑 이벤트 리스너 설정
  void _setupWalletListeners(EthereumWallet wallet) {
    // 계정 변경 리스너
    wallet.onAccountsChanged.listen((address) {
      if (address != null) {
        state = state.copyWith(address: address);
        updateBalance();
      } else {
        state = const EthereumWalletState();
      }
    });

    // 체인 변경 리스너
    wallet.onChainChanged.listen((chainId) {
      if (chainId != null) {
        state = state.copyWith(chainId: chainId);
        updateBalance();
      }
    });

    // 연결 해제 리스너
    wallet.onDisconnect.listen((_) {
      state = const EthereumWalletState();
    });
  }
}

/// Ethereum 지갑 Provider
final ethereumWalletProvider =
    NotifierProvider<EthereumWalletNotifier, EthereumWalletState>(
  () => EthereumWalletNotifier(),
);

/// 지갑 연결 여부 Provider
final isWalletConnectedProvider = Provider<bool>((ref) {
  final walletState = ref.watch(ethereumWalletProvider);
  return walletState.isConnected;
});

/// 지갑 주소 Provider
final walletAddressProvider = Provider<String?>((ref) {
  final walletState = ref.watch(ethereumWalletProvider);
  return walletState.address;
});

/// 지갑 잔액 Provider (ETH 단위)
final walletBalanceProvider = Provider<double?>((ref) {
  final walletState = ref.watch(ethereumWalletProvider);
  if (walletState.balance == null) return null;

  // Wei를 ETH로 변환 (1 ETH = 10^18 Wei)
  return walletState.balance!.toDouble() / 1e18;
});

/// 체인 ID Provider
final chainIdProvider = Provider<String?>((ref) {
  final walletState = ref.watch(ethereumWalletProvider);
  return walletState.chainId;
});
