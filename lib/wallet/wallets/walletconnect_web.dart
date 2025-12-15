import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wagmi_web/wagmi_web.dart' as wagmi;
import 'package:web/web.dart' as web;

import '../../common/util.dart';
import '../core/ethereum_wallet.dart';

// 전역 초기화 플래그 (여러 인스턴스가 생성되어도 한 번만 초기화)
bool _globalWagmiInitialized = false;

/// WalletConnect Web 구현 (wagmi_web 사용)
/// 모바일 지갑을 QR 코드로 연결
class WalletConnectWallet extends EthereumWallet {
  final _accountsChangedController = StreamController<String?>.broadcast();
  final _chainChangedController = StreamController<String?>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  Future<void Function()>? _accountUnsubscribe;
  Future<void Function()>? _chainUnsubscribe;

  @override
  Stream<String?> get onAccountsChanged => _accountsChangedController.stream;

  @override
  Stream<String?> get onChainChanged => _chainChangedController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  /// Context 설정 (Web에서는 사용하지 않음)
  /// JavaScript 모달을 사용하므로 Flutter BuildContext 불필요
  void setContext(BuildContext context) {
    // Web implementation doesn't need context
    // Modal is shown via JavaScript, not Flutter widget
  }

  /// JavaScript에서 Wagmi/AppKit이 이미 초기화되었는지 확인 (hot reload 대응)
  bool _checkIfWagmiInitialized() {
    try {
      // wagmi.Core의 connector 정보를 확인
      // 초기화되지 않았으면 getConnections()가 에러를 던짐
      final connections = wagmi.Core.getConnections();

      // connections를 성공적으로 가져왔으면 초기화됨
      debugPrint('[WalletConnect Web] wagmi/AppKit is already initialized (connections: ${connections.length})');
      return true;
    } catch (e) {
      debugPrint('[WalletConnect Web] wagmi/AppKit not initialized yet: $e');
      return false;
    }
  }

  /// Wagmi 초기화
  Future<void> _initializeWagmi() async {
    // Hot reload를 감지하기 위해 JavaScript에서 초기화 여부 확인
    final isAlreadyInitialized = _checkIfWagmiInitialized();

    if (_globalWagmiInitialized || isAlreadyInitialized) {
      debugPrint('[WalletConnect Web] Wagmi already initialized (globalFlag: $_globalWagmiInitialized, jsCheck: $isAlreadyInitialized)');

      // 이미 초기화되었어도 이벤트 리스너는 재설정 (hot reload 대응)
      try {
        _setupEventListeners();
        debugPrint('[WalletConnect Web] Event listeners re-attached');
      } catch (e) {
        debugPrint('[WalletConnect Web] Error re-attaching listeners: $e');
      }

      // 플래그도 true로 설정
      _globalWagmiInitialized = true;
      return;
    }

    try {
      debugPrint('[WalletConnect Web] Initializing Wagmi...');

      // Wagmi 라이브러리 로드 (타임아웃 설정)
      try {
        await wagmi.init().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
                '[WalletConnect Web] wagmi.init() timeout - continuing anyway');
          },
        );
        debugPrint('[WalletConnect Web] wagmi.init() completed');
      } catch (e) {
        debugPrint(
            '[WalletConnect Web] wagmi.init() error: $e - continuing anyway');
      }

      hideLoading();

      // AppKit 초기화 (Reown AppKit - WalletConnect v2)
      // 현재 접속 중인 URL 가져오기
      final currentUrl = web.window.location.origin;
      final isLocalhost =
          currentUrl.contains('localhost') || currentUrl.contains('127.0.0.1');

      // localhost면 localhost URL 사용, 아니면 프로덕션 URL 사용
      final appUrl = isLocalhost ? currentUrl : 'https://game.ateon.io/perpdex';
      final iconUrl = isLocalhost
          ? '$currentUrl/icons/Icon-192.png'
          : 'https://game.ateon.io/perpdex/logo.png';

      debugPrint('[WalletConnect Web] Current URL: $currentUrl');
      debugPrint('[WalletConnect Web] Is localhost: $isLocalhost');
      debugPrint('[WalletConnect Web] App URL: $appUrl');
      debugPrint('[WalletConnect Web] Icon URL: $iconUrl');

      try {
        wagmi.AppKit.init(
          projectId: '0952178d7b6c31cc00e6a4e82483f9da',
          chains: [
            wagmi.Chain.mainnet.id, // Ethereum (1)
            wagmi.Chain.sepolia.id, // Sepolia testnet (11155111)
          ],
          enableAnalytics: true,
          enableOnRamp: false,
          email: false,
          showWallets: true,
          walletFeatures: true,
          // excludeWalletIds 제거 - WalletConnect QR 코드가 표시되도록 함
          // 사용자가 모바일 지갑 앱에서 QR 코드를 스캔하여 연결
          metadata: wagmi.AppKitMetadata(
            name: 'PerpDex',
            description: 'Decentralized Perpetual Exchange',
            url: appUrl,
            icons: [iconUrl],
          ),
        );
        debugPrint('[WalletConnect Web] AppKit.init() completed');
      } catch (e) {
        debugPrint('[WalletConnect Web] AppKit.init() error: $e');
        rethrow;
      }

      _setupEventListeners();
      _globalWagmiInitialized = true;
      debugPrint('[WalletConnect Web] Wagmi initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[WalletConnect Web] Initialization error: $e');
      debugPrint('[WalletConnect Web] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 이벤트 리스너 정리 (hot reload 대응)
  Future<void> _cleanupEventListeners() async {
    try {
      if (_accountUnsubscribe != null) {
        final unsubscribe = await _accountUnsubscribe!;
        unsubscribe();
        _accountUnsubscribe = null;
        debugPrint('[WalletConnect Web] Account listener cleaned up');
      }
      if (_chainUnsubscribe != null) {
        final unsubscribe = await _chainUnsubscribe!;
        unsubscribe();
        _chainUnsubscribe = null;
        debugPrint('[WalletConnect Web] Chain listener cleaned up');
      }
    } catch (e) {
      debugPrint('[WalletConnect Web] Error cleaning up listeners: $e');
    }
  }

  void _setupEventListeners() {
    // 기존 리스너가 있으면 먼저 정리 (hot reload 대응)
    // async 메서드지만 fire-and-forget으로 실행
    _cleanupEventListeners();

    // 계정 변경 감지
    _accountUnsubscribe = wagmi.Core.watchAccount(
      wagmi.WatchAccountParameters(
        onChange: (account, prevAccount) {
          debugPrint('[WalletConnect Web] Account changed: ${account.address}');

          if (account.address != null) {
            setConnectedAddress(account.address);
            if (!_accountsChangedController.isClosed) {
              _accountsChangedController.add(account.address);
            }
          } else {
            // 연결 해제됨
            setConnectedAddress(null);
            setChainId(null);
            if (!_disconnectController.isClosed) {
              _disconnectController.add(null);
            }
          }
        },
      ),
    );

    // 체인 변경 감지
    _chainUnsubscribe = wagmi.Core.watchChainId(
      wagmi.WatchChainIdParameters(
        onChange: (chainId, prevChainId) {
          final chainIdHex = '0x${chainId.toRadixString(16)}';
          debugPrint('[WalletConnect Web] Chain changed: $chainIdHex');

          setChainId(chainIdHex);
          if (!_chainChangedController.isClosed) {
            _chainChangedController.add(chainIdHex);
          }
        },
      ),
    );
  }

  @override
  Future<String?> connect() async {
    await _initializeWagmi();

    try {
      // 항상 먼저 disconnect를 호출하여 깨끗한 상태로 시작
      debugPrint('[WalletConnect Web] Ensuring clean state...');
      await disconnect();

      // 짧은 대기
      await Future.delayed(const Duration(milliseconds: 500));

      // 먼저 이미 연결되어 있는지 확인
      debugPrint('[WalletConnect Web] Checking existing connection...');
      final currentAccount = await wagmi.Core.getAccount();

      debugPrint(
          '[WalletConnect Web] Current account - isConnected: ${currentAccount.isConnected}, address: ${currentAccount.address}, connector: ${currentAccount.connector?.id}');

      if (currentAccount.isConnected && currentAccount.address != null) {
        final address = currentAccount.address!;
        debugPrint('[WalletConnect Web] ✅ Already connected: $address');

        setConnectedAddress(address);

        // Chain ID도 설정
        try {
          final chainId = await wagmi.Core.getChainId();
          final chainIdHex = '0x${chainId.toRadixString(16)}';
          setChainId(chainIdHex);
          debugPrint('[WalletConnect Web] Chain ID: $chainIdHex');
        } catch (e) {
          debugPrint('[WalletConnect Web] Error getting chain ID: $e');
        }

        return address;
      }

      // 이전 세션이 있으면 완전히 정리
      debugPrint(
          '[WalletConnect Web] No active connection, cleaning up any stale sessions...');
      if (currentAccount.connector != null) {
        debugPrint(
            '[WalletConnect Web] Found stale connector: ${currentAccount.connector!.id}, disconnecting...');
        try {
          await wagmi.Core.disconnect(
            wagmi.DisconnectParameters(connector: currentAccount.connector!),
          );
          debugPrint('[WalletConnect Web] ✅ Stale session cleared');

          // 세션 정리 후 충분한 대기
          await Future.delayed(const Duration(milliseconds: 100));

          // 정리 후 다시 확인
          final checkAccount = await wagmi.Core.getAccount();
          debugPrint(
              '[WalletConnect Web] After cleanup - isConnected: ${checkAccount.isConnected}, connector: ${checkAccount.connector?.id}');
        } catch (e) {
          debugPrint('[WalletConnect Web] ⚠️ Error clearing stale session: $e');
          // 에러가 나더라도 계속 진행
        }
      }

      debugPrint('[WalletConnect Web] Opening AppKit modal...');

      // AppKit 모달 열기 (QR 코드 표시)
      try {
        wagmi.AppKit.open();
        debugPrint('[WalletConnect Web] ✅ AppKit.open() called successfully');
        debugPrint(
            '[WalletConnect Web] 💡 Please check browser for modal visibility');
        debugPrint(
            '[WalletConnect Web] 💡 Open browser DevTools (F12) and check:');
        debugPrint('[WalletConnect Web]    1. Console for JavaScript errors');
        debugPrint(
            '[WalletConnect Web]    2. Elements tab for wcm-modal or w3m-modal');
        debugPrint('[WalletConnect Web]    3. Network tab for failed requests');
      } catch (e) {
        debugPrint('[WalletConnect Web] ❌ AppKit.open() error: $e');
        throw Exception('Failed to open WalletConnect modal: $e');
      }

      // 짧은 딜레이
      await Future.delayed(const Duration(milliseconds: 100));

      // 연결 완료 또는 모달 닫힘 대기
      final completer = Completer<String?>();
      int attempts = 0;
      const maxAttempts = 120; // 120초 타임아웃

      // AppKit 모달 상태 감지
      StreamSubscription? modalStateSubscription;

      try {
        modalStateSubscription = wagmi.AppKit.state.listen((state) {
          debugPrint(
              '[WalletConnect Web] Modal state changed - open: ${state.open}');

          // 모달이 닫혔는데 연결되지 않았으면 취소
          if (!state.open && !completer.isCompleted) {
            debugPrint('[WalletConnect Web] Modal closed without connection');
            completer.completeError(Exception('User cancelled connection'));
          }
        });
      } catch (e) {
        debugPrint('[WalletConnect Web] Could not listen to modal state: $e');
      }

      final timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        attempts++;

        try {
          final account = await wagmi.Core.getAccount();

          if (account.isConnected && account.address != null) {
            timer.cancel();
            modalStateSubscription?.cancel();

            final address = account.address!;

            debugPrint('[WalletConnect Web] Connected: $address');

            setConnectedAddress(address);

            // Chain ID도 설정
            try {
              final chainId = await wagmi.Core.getChainId();
              final chainIdHex = '0x${chainId.toRadixString(16)}';
              setChainId(chainIdHex);
            } catch (e) {
              debugPrint('[WalletConnect Web] Error getting chain ID: $e');
            }

            if (!completer.isCompleted) {
              completer.complete(address);
            }
          }
        } catch (e) {
          debugPrint('[WalletConnect Web] Error checking connection: $e');
        }

        // 매 10초마다 상태 로그
        if (attempts % 10 == 0) {
          debugPrint(
              '[WalletConnect Web] Still waiting for connection... ($attempts seconds)');
        }

        if (attempts >= maxAttempts) {
          timer.cancel();
          modalStateSubscription?.cancel();
          if (!completer.isCompleted) {
            debugPrint(
                '[WalletConnect Web] Connection timeout after $maxAttempts seconds');
            completer.completeError(Exception('Connection timeout'));
          }
        }
      });

      try {
        return await completer.future;
      } finally {
        timer.cancel();
        modalStateSubscription?.cancel();
      }
    } catch (e) {
      debugPrint('[WalletConnect Web] Connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      debugPrint('[WalletConnect Web] Disconnecting...');

      final account = await wagmi.Core.getAccount();
      debugPrint(
          '[WalletConnect Web] Current account before disconnect - connector: ${account.connector?.id}');

      if (account.connector != null) {
        try {
          await wagmi.Core.disconnect(
            wagmi.DisconnectParameters(connector: account.connector!),
          );
          debugPrint(
              '[WalletConnect Web] ✅ Connector disconnected: ${account.connector!.id}');
        } catch (e) {
          debugPrint('[WalletConnect Web] Error disconnecting connector: $e');
        }
      }

      // localStorage에서 WalletConnect/AppKit 관련 데이터 제거
      _clearWalletConnectStorage();

      setConnectedAddress(null);
      setChainId(null);

      if (!_disconnectController.isClosed) {
        _disconnectController.add(null);
      }

      debugPrint('[WalletConnect Web] Disconnected');
    } catch (e) {
      debugPrint('[WalletConnect Web] Disconnect error: $e');
      // 에러가 나도 일단 상태는 정리
      setConnectedAddress(null);
      setChainId(null);
    }
  }

  /// localStorage에서 WalletConnect/AppKit 관련 데이터 정리
  void _clearWalletConnectStorage() {
    try {
      final storage = web.window.localStorage;
      final keysToRemove = <String>[];

      // localStorage에서 WalletConnect 관련 키들 찾기
      for (var i = 0; i < storage.length; i++) {
        final key = storage.key(i);
        if (key != null &&
            (key.startsWith('wc@2:') ||
                key.startsWith('wagmi.') ||
                key.contains('walletconnect') ||
                key.contains('appkit') ||
                key.contains('WALLETCONNECT') ||
                key.contains('W3M'))) {
          keysToRemove.add(key);
        }
      }

      // 찾은 키들 제거
      for (final key in keysToRemove) {
        debugPrint('[WalletConnect Web] Removing localStorage key: $key');
        storage.removeItem(key);
      }

      debugPrint(
          '[WalletConnect Web] Cleared ${keysToRemove.length} localStorage items');
    } catch (e) {
      debugPrint('[WalletConnect Web] Error clearing localStorage: $e');
    }
  }

  @override
  Future<BigInt> getBalance(String address) async {
    try {
      final balance = await wagmi.Core.getBalance(
        wagmi.GetBalanceParameters(address: address),
      );

      return BigInt.parse(balance.value.toString());
    } catch (e) {
      debugPrint('[WalletConnect Web] Get balance error: $e');
      rethrow;
    }
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required BigInt value,
    Uint8List? data,
  }) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final txHash = await wagmi.Core.sendTransaction(
        wagmi.SendTransactionParameters.legacy(
          to: to,
          account: connectedAddress!,
          value: value,
          feeValues: wagmi.FeeValuesLegacy(
            gasPrice: BigInt.from(20000000000), // 20 Gwei
          ),
          data: data != null
              ? '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}'
              : null,
        ),
      );

      debugPrint('[WalletConnect Web] Transaction sent: $txHash');
      return txHash;
    } catch (e) {
      if (e.toString().contains('User rejected')) {
        throw Exception('User rejected transaction');
      }
      debugPrint('[WalletConnect Web] Send transaction error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signMessage(String message) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      debugPrint('[WalletConnect Web] Signing message...');

      final signature = await wagmi.Core.signMessage(
        wagmi.SignMessageParameters(
          account: connectedAddress!,
          message: wagmi.MessageToSign.stringMessage(message: message),
        ),
      );

      debugPrint(
          '[WalletConnect Web] Message signed: ${signature.substring(0, 20)}...');
      return signature;
    } catch (e) {
      if (e.toString().contains('User rejected')) {
        throw Exception('User rejected signature');
      }
      debugPrint('[WalletConnect Web] Sign message error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signTypedData(String typedData) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      // wagmi_web의 signTypedData는 복잡한 구조를 요구함
      // 일단 간단한 구현으로 처리
      throw UnimplementedError(
          'signTypedData not yet implemented for wagmi_web');
    } catch (e) {
      debugPrint('[WalletConnect Web] Sign typed data error: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    try {
      // chainId를 10진수로 변환
      final chainIdInt = int.parse(
        chainId.startsWith('0x') ? chainId.substring(2) : chainId,
        radix: chainId.startsWith('0x') ? 16 : 10,
      );

      await wagmi.Core.switchChain(
        wagmi.SwitchChainParameters(chainId: chainIdInt),
      );

      setChainId(chainId);
      debugPrint('[WalletConnect Web] Switched to chain: $chainId');
    } catch (e) {
      if (e.toString().contains('User rejected')) {
        throw Exception('User rejected chain switch');
      }
      debugPrint('[WalletConnect Web] Switch chain error: $e');
      rethrow;
    }
  }

  @override
  Future<void> addNetwork({
    required String chainId,
    required String chainName,
    required String rpcUrl,
    required String currencyName,
    required String currencySymbol,
    required int currencyDecimals,
    String? blockExplorerUrl,
  }) async {
    try {
      // wagmi_web에서 addChain은 제한적이므로
      // 일단 switchChain으로 시도하고 실패하면 에러
      await switchChain(chainId);
      debugPrint('[WalletConnect Web] Network switched to: $chainName');
    } catch (e) {
      debugPrint('[WalletConnect Web] Add network error: $e');
      throw Exception(
          'Network not supported. Please add it manually in your wallet.');
    }
  }

  void dispose() async {
    // 이벤트 리스너 정리
    await _cleanupEventListeners();

    // 스트림 컨트롤러 정리
    _accountsChangedController.close();
    _chainChangedController.close();
    _disconnectController.close();
  }
}
