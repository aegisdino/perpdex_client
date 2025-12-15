import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../core/ethereum_wallet.dart';

/// WalletConnect (Reown AppKit) 구현 (Mobile 전용)
/// Web에서는 Cookie Manager 미지원으로 사용 불가
class WalletConnectWallet extends EthereumWallet {
  final _accountsChangedController = StreamController<String?>.broadcast();
  final _chainChangedController = StreamController<String?>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  ReownAppKitModal? _appKitModal;
  BuildContext? _context;

  @override
  Stream<String?> get onAccountsChanged => _accountsChangedController.stream;

  @override
  Stream<String?> get onChainChanged => _chainChangedController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  /// Context 설정 (connect 호출 전 필수)
  void setContext(BuildContext context) {
    _context = context;
  }

  Future<void> _initializeAppKit(BuildContext context) async {
    if (_appKitModal != null) return;

    try {
      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: '0952178d7b6c31cc00e6a4e82483f9da',
        metadata: const PairingMetadata(
          name: 'PerpDex',
          description: 'Decentralized Perpetual Exchange',
          url: 'https://game.ateon.io/perpdex',
          icons: ['https://game.ateon.io/perpdex/logo.png'],
          redirect: Redirect(
            native: 'perpdex://',
            universal: 'https://game.ateon.io/perpdex',
            linkMode: true,
          ),
        ),
        enableAnalytics: true,
      );

      // 이벤트 리스너 설정
      _setupEventListeners();

      await _appKitModal!.init();
      debugPrint('[WalletConnect] AppKit initialized');
    } catch (e) {
      debugPrint('[WalletConnect] Initialization error: $e');
      rethrow;
    }
  }

  void _setupEventListeners() {
    if (_appKitModal == null) return;

    // 모달 연결 이벤트
    _appKitModal!.onModalConnect.subscribe((ModalConnect? event) {
      if (event != null) {
        _updateConnectionState();
      }
    });

    // 모달 연결 해제 이벤트
    _appKitModal!.onModalDisconnect.subscribe((ModalDisconnect? event) {
      debugPrint('[WalletConnect] Disconnected');
      setConnectedAddress(null);
      setChainId(null);
      if (!_disconnectController.isClosed) {
        _disconnectController.add(null);
      }
    });

    // 네트워크 변경 이벤트
    _appKitModal!.onModalNetworkChange.subscribe((ModalNetworkChange? event) {
      if (event != null) {
        _updateConnectionState();
      }
    });

    // 모달 업데이트 이벤트
    _appKitModal!.onModalUpdate.subscribe((ModalConnect? event) {
      if (event != null) {
        _updateConnectionState();
      }
    });
  }

  void _updateConnectionState() {
    try {
      final session = _appKitModal?.session;
      final selectedChain = _appKitModal?.selectedChain;

      if (session != null) {
        // 세션에서 주소 추출
        final namespaces = session.namespaces;
        String? address;

        // EIP155 (EVM) 네임스페이스에서 주소 가져오기
        if (namespaces != null) {
          final eip155Namespace = namespaces['eip155'];
          if (eip155Namespace != null) {
            final accounts = eip155Namespace.accounts;
            if (accounts.isNotEmpty) {
              // 형식: "eip155:1:0xabc..." -> "0xabc..."
              final parts = accounts.first.split(':');
              if (parts.length >= 3) {
                address = parts[2];
              }
            }
          }
        }

        if (address != null) {
          debugPrint('[WalletConnect] Address: $address');
          setConnectedAddress(address);

          if (!_accountsChangedController.isClosed) {
            _accountsChangedController.add(address);
          }
        }
      }

      if (selectedChain != null) {
        final chainId = selectedChain.chainId;
        // chainId는 이미 String 형식
        debugPrint('[WalletConnect] Chain: $chainId');
        setChainId(chainId);

        if (!_chainChangedController.isClosed) {
          _chainChangedController.add(chainId);
        }
      }
    } catch (e) {
      debugPrint('[WalletConnect] Failed to update connection state: $e');
    }
  }

  @override
  Future<String?> connect() async {
    if (_context == null) {
      throw Exception(
          'Context not set. Call setContext(context) before connect()');
    }

    await _initializeAppKit(_context!);

    if (_appKitModal == null) {
      throw Exception('Failed to initialize AppKit');
    }

    try {
      debugPrint('[WalletConnect] Opening modal...');

      // 모달 열기 (사용자가 지갑 선택)
      await _appKitModal!.openModalView();

      // 연결 완료 대기
      final completer = Completer<String?>();

      // subscribe는 void를 반환하므로 직접 리스너 추가
      _appKitModal!.onModalConnect.subscribe((event) {
        if (event != null && !completer.isCompleted) {
          _updateConnectionState();

          final address = connectedAddress;
          if (address != null) {
            debugPrint('[WalletConnect] Connected: $address');
            completer.complete(address);
          }
        }
      });

      // 타임아웃 설정 (60초)
      Future.delayed(const Duration(seconds: 60), () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Connection timeout'));
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('[WalletConnect] Connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_appKitModal != null && _appKitModal!.isConnected) {
        await _appKitModal!.disconnect();
      }
      setConnectedAddress(null);
      setChainId(null);
      if (!_disconnectController.isClosed) {
        _disconnectController.add(null);
      }
      debugPrint('[WalletConnect] Disconnected');
    } catch (e) {
      debugPrint('[WalletConnect] Disconnect error: $e');
      rethrow;
    }
  }

  @override
  Future<BigInt> getBalance(String address) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    try {
      final session = _appKitModal!.session;
      final chainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || chainId == null) {
        throw Exception('Session or chain not available');
      }

      final result = await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_getBalance',
          params: [address, 'latest'],
        ),
      );

      final balanceHex = result.toString();
      final balance = BigInt.parse(
        balanceHex.startsWith('0x') ? balanceHex.substring(2) : balanceHex,
        radix: 16,
      );

      return balance;
    } catch (e) {
      debugPrint('[WalletConnect] Get balance error: $e');
      rethrow;
    }
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required BigInt value,
    Uint8List? data,
  }) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final session = _appKitModal!.session;
      final chainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || chainId == null) {
        throw Exception('Session or chain not available');
      }

      final params = <String, dynamic>{
        'from': connectedAddress!,
        'to': to,
        'value': '0x${value.toRadixString(16)}',
      };

      if (data != null && data.isNotEmpty) {
        params['data'] =
            '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      }

      final result = await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [params],
        ),
      );

      final txHash = result.toString();
      debugPrint('[WalletConnect] Transaction sent: $txHash');
      return txHash;
    } catch (e) {
      debugPrint('[WalletConnect] Send transaction error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signMessage(String message) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      debugPrint('[WalletConnect] Signing message...');

      final session = _appKitModal!.session;
      final chainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || chainId == null) {
        throw Exception('Session or chain not available');
      }

      final result = await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, connectedAddress!],
        ),
      );

      final signature = result.toString();
      debugPrint(
          '[WalletConnect] Message signed: ${signature.substring(0, 20)}...');
      return signature;
    } catch (e) {
      debugPrint('[WalletConnect] Sign message error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signTypedData(String typedData) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final session = _appKitModal!.session;
      final chainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || chainId == null) {
        throw Exception('Session or chain not available');
      }

      final result = await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_signTypedData_v4',
          params: [connectedAddress!, typedData],
        ),
      );

      final signature = result.toString();
      return signature;
    } catch (e) {
      debugPrint('[WalletConnect] Sign typed data error: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    try {
      final session = _appKitModal!.session;
      final currentChainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || currentChainId == null) {
        throw Exception('Session or chain not available');
      }

      await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$currentChainId',
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': chainId}
          ],
        ),
      );

      setChainId(chainId);
      debugPrint('[WalletConnect] Switched to chain: $chainId');
    } catch (e) {
      debugPrint('[WalletConnect] Switch chain error: $e');
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
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('WalletConnect not connected');
    }

    try {
      final session = _appKitModal!.session;
      final currentChainId = _appKitModal!.selectedChain?.chainId;

      if (session == null || currentChainId == null) {
        throw Exception('Session or chain not available');
      }

      final params = {
        'chainId': chainId,
        'chainName': chainName,
        'rpcUrls': [rpcUrl],
        'nativeCurrency': {
          'name': currencyName,
          'symbol': currencySymbol,
          'decimals': currencyDecimals,
        },
      };

      if (blockExplorerUrl != null) {
        params['blockExplorerUrls'] = [blockExplorerUrl];
      }

      await _appKitModal!.request(
        topic: session.topic,
        chainId: 'eip155:$currentChainId',
        request: SessionRequestParams(
          method: 'wallet_addEthereumChain',
          params: [params],
        ),
      );

      debugPrint('[WalletConnect] Network added: $chainName');
    } catch (e) {
      debugPrint('[WalletConnect] Add network error: $e');
      rethrow;
    }
  }

  void dispose() {
    _accountsChangedController.close();
    _chainChangedController.close();
    _disconnectController.close();
  }
}
