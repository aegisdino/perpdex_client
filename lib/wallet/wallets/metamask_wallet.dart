import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../widgets/wallet_detector.dart';
import '../core/ethereum_wallet.dart';

/// MetaMask 지갑 구현 (Web 전용)
class MetaMaskWallet extends EthereumWallet {
  final _accountsChangedController = StreamController<String?>.broadcast();
  final _chainChangedController = StreamController<String?>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  // Provider 캐싱
  JSObject? _cachedProvider;

  @override
  Stream<String?> get onAccountsChanged => _accountsChangedController.stream;

  @override
  Stream<String?> get onChainChanged => _chainChangedController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  MetaMaskWallet() {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    if (!_isMetaMaskInstalled()) return;

    try {
      final ethereum = _getEthereum();
      if (ethereum == null) return;

      // accountsChanged 이벤트
      ethereum.callMethod(
          'on'.toJS,
          'accountsChanged'.toJS,
          ((JSArray accounts) {
            final accountList = accounts.toDart;
            if (accountList.isEmpty) {
              setConnectedAddress(null);
              if (!_accountsChangedController.isClosed) {
                _accountsChangedController.add(null);
              }
            } else {
              final address = accountList[0] as String;
              setConnectedAddress(address);
              if (!_accountsChangedController.isClosed) {
                _accountsChangedController.add(address);
              }
            }
          }).toJS);

      // chainChanged 이벤트
      ethereum.callMethod(
          'on'.toJS,
          'chainChanged'.toJS,
          ((JSString chainId) {
            final chain = chainId.toDart;
            setChainId(chain);
            if (!_chainChangedController.isClosed) {
              _chainChangedController.add(chain);
            }
          }).toJS);

      // disconnect 이벤트
      ethereum.callMethod(
          'on'.toJS,
          'disconnect'.toJS,
          ((JSAny? error) {
            setConnectedAddress(null);
            setChainId(null);
            if (!_disconnectController.isClosed) {
              _disconnectController.add(null);
            }
          }).toJS);
    } catch (e) {
      debugPrint('MetaMask event listener setup error: $e');
    }
  }

  bool _isMetaMaskInstalled() {
    return _getEthereum() != null;
  }

  JSObject? _getEthereum() {
    final provider = WalletDetector.findAndMarkProvider(
      walletType: 'metamask',
      cachedProvider: _cachedProvider,
    );

    if (provider != null) {
      _cachedProvider = provider as JSObject;
    }

    return provider as JSObject?;
  }

  @override
  Future<String?> connect() async {
    if (!_isMetaMaskInstalled()) {
      web.window.open('https://metamask.io/download/', '_blank');
      throw Exception('MetaMask is not installed');
    }

    try {
      final ethereum = _getEthereum();
      if (ethereum == null) {
        throw Exception('Ethereum provider not found');
      }

      // 무조건 eth_requestAccounts 호출 (사용자 연결 확인)
      debugPrint('[MetaMask] Calling eth_requestAccounts...');
      final requestParams = {'method': 'eth_requestAccounts'}.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, requestParams);
      debugPrint('[MetaMask] Waiting for user approval...');

      final jsAccounts = await promise.toDart as JSArray;
      final accounts = jsAccounts.toDart;
      debugPrint('[MetaMask] Accounts received: $accounts');

      if (accounts.isNotEmpty) {
        final address = accounts[0] as String;
        setConnectedAddress(address);

        // 현재 체인 ID 가져오기
        final chainIdParams = {'method': 'eth_chainId'}.jsify();
        final chainIdPromise =
            ethereum.callMethod<JSPromise>('request'.toJS, chainIdParams);
        final chainIdResult = await chainIdPromise.toDart;
        setChainId((chainIdResult as JSString).toDart);

        debugPrint('[MetaMask] ✅ Connected: $address, Chain: ${chainId}');
        return address;
      }
    } catch (e, stackTrace) {
      debugPrint('MetaMask connect error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');

      // JS 에러 객체의 메시지 추출 시도
      try {
        if (e is JSObject) {
          final message = e.getProperty('message'.toJS);
          if (message != null) {
            debugPrint('JS Error message: ${(message as JSString).toDart}');
          }
        }
      } catch (_) {}

      rethrow;
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    // 앱 내부 상태만 초기화
    // MetaMask의 승인 상태는 유지됨 (사용자가 MetaMask에서 직접 관리)
    try {
      setConnectedAddress(null);
      setChainId(null);
      _disconnectController.add(null);
      debugPrint('[MetaMask] Disconnected from app');
    } catch (e) {
      debugPrint('[MetaMask] disconnect. exception ${e.toString()}');
    }
  }

  @override
  Future<BigInt> getBalance(String address) async {
    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
      final balanceParams = {
        'method': 'eth_getBalance',
        'params': [address, 'latest']
      }.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, balanceParams);

      final result = await promise.toDart;
      final balanceHex = (result as JSString).toDart;

      // 0x 접두사 제거하고 BigInt로 변환
      return BigInt.parse(balanceHex.replaceFirst('0x', ''), radix: 16);
    } catch (e) {
      debugPrint('Get balance error: $e');
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

    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
      final params = {
        'from': connectedAddress!,
        'to': to,
        'value': '0x${value.toRadixString(16)}',
      };

      if (data != null) {
        params['data'] =
            '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      }

      final txParams = {
        'method': 'eth_sendTransaction',
        'params': [params]
      }.jsify();
      final promise = ethereum.callMethod<JSPromise>('request'.toJS, txParams);

      final result = await promise.toDart;
      return (result as JSString).toDart;
    } catch (e) {
      debugPrint('Send transaction error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signMessage(String message) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
      // UTF-8 메시지를 hex로 변환
      final messageBytes = utf8.encode(message);
      final messageHex =
          '0x${messageBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      final messagePreview =
          message.length > 50 ? '${message.substring(0, 50)}...' : message;
      final hexPreview = messageHex.length > 50
          ? '${messageHex.substring(0, 50)}...'
          : messageHex;

      debugPrint('[MetaMask] Signing message: $messagePreview');
      debugPrint('[MetaMask] Message hex: $hexPreview');

      final signParams = {
        'method': 'personal_sign',
        'params': [messageHex, connectedAddress!]
      }.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, signParams);

      final result = await promise.toDart;
      return (result as JSString).toDart;
    } catch (e, stackTrace) {
      debugPrint('Sign message error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');

      // JS 에러 객체의 상세 정보 추출
      String errorMessage = e.toString();
      try {
        if (e is JSObject) {
          final message = e.getProperty('message'.toJS);
          final code = e.getProperty('code'.toJS);
          if (message != null) {
            errorMessage = (message as JSString).toDart;
            debugPrint('JS Error message: $errorMessage');
          }
          if (code != null) {
            debugPrint('JS Error code: $code');
          }
        }
      } catch (parseError) {
        debugPrint('Error parsing JS error: $parseError');
      }

      throw Exception('MetaMask sign message failed: $errorMessage');
    }
  }

  // signAuthMessage()는 부모 클래스 EthereumWallet에서 상속받음
  // 모든 지갑에서 공통으로 사용 가능

  @override
  Future<String> signTypedData(String typedData) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
      final typedDataParams = {
        'method': 'eth_signTypedData_v4',
        'params': [connectedAddress!, typedData]
      }.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, typedDataParams);

      final result = await promise.toDart;
      return (result as JSString).toDart;
    } catch (e) {
      debugPrint('Sign typed data error: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
      final switchParams = {
        'method': 'wallet_switchEthereumChain',
        'params': [
          {'chainId': chainId}
        ]
      }.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, switchParams);

      await promise.toDart;
      setChainId(chainId);
    } catch (e) {
      debugPrint('Switch chain error: $e');
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
    final ethereum = _getEthereum();
    if (ethereum == null) {
      throw Exception('MetaMask not found');
    }

    try {
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

      final addNetworkParams = {
        'method': 'wallet_addEthereumChain',
        'params': [params]
      }.jsify();
      final promise =
          ethereum.callMethod<JSPromise>('request'.toJS, addNetworkParams);

      await promise.toDart;
    } catch (e) {
      debugPrint('Add network error: $e');
      rethrow;
    }
  }

  void dispose() {
    _accountsChangedController.close();
    _chainChangedController.close();
    _disconnectController.close();
  }
}
