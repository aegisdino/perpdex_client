import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

import '../widgets/wallet_detector.dart';
import '../core/ethereum_wallet.dart';

/// Phantom 지갑 Ethereum 구현 (Web 전용)
/// Phantom은 Solana와 Ethereum 모두 지원하지만
/// 여기서는 Ethereum 기능만 구현
class PhantomEthereumWallet extends EthereumWallet {
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

  PhantomEthereumWallet() {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    if (!_isPhantomInstalled()) return;

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) return;

      // accountsChanged 이벤트
      ethereum.callMethod('on'.toJS, 'accountsChanged'.toJS,
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
      ethereum.callMethod('on'.toJS, 'chainChanged'.toJS,
          ((JSString chainId) {
        final chain = chainId.toDart;
        setChainId(chain);
        if (!_chainChangedController.isClosed) {
          _chainChangedController.add(chain);
        }
      }).toJS);

      // disconnect 이벤트
      ethereum.callMethod('on'.toJS, 'disconnect'.toJS, ((JSAny? error) {
        setConnectedAddress(null);
        setChainId(null);
        if (!_disconnectController.isClosed) {
          _disconnectController.add(null);
        }
      }).toJS);
    } catch (e) {
      debugPrint('[PhantomEthereum] Event listener setup error: $e');
    }
  }

  bool _isPhantomInstalled() {
    return _getPhantomEthereum() != null;
  }

  JSObject? _getPhantomEthereum() {
    final provider = WalletDetector.findAndMarkProvider(
      walletType: 'phantom',
      cachedProvider: _cachedProvider,
    );

    if (provider != null) {
      _cachedProvider = provider as JSObject;
    }

    return provider as JSObject?;
  }

  @override
  Future<String?> connect() async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
      }

      debugPrint('[PhantomEthereum] Requesting accounts...');

      // eth_requestAccounts 요청
      final result = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'eth_requestAccounts'.toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final accounts = result as JSArray;
      final accountList = accounts.toDart;

      if (accountList.isEmpty) {
        throw Exception('No accounts returned from Phantom');
      }

      final address = accountList[0] as String;
      setConnectedAddress(address);

      // 현재 체인 ID 가져오기
      final chainIdResult = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'eth_chainId'.toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final chainId = chainIdResult as String;
      setChainId(chainId);

      debugPrint('[PhantomEthereum] Connected: $address on chain $chainId');
      return address;
    } catch (e) {
      debugPrint('[PhantomEthereum] Connection error: $e');
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    setConnectedAddress(null);
    setChainId(null);
    _disconnectController.add(null);
    debugPrint('[PhantomEthereum] Disconnected');
  }

  @override
  Future<BigInt> getBalance(String address) async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
      }

      final result = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'eth_getBalance'.toJS,
          'params': [address.toJS, 'latest'.toJS].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final balanceHex = result as String;
      // 0x 제거하고 BigInt로 변환
      final balance = BigInt.parse(
        balanceHex.startsWith('0x') ? balanceHex.substring(2) : balanceHex,
        radix: 16,
      );

      return balance;
    } catch (e) {
      debugPrint('[PhantomEthereum] Get balance error: $e');
      rethrow;
    }
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required BigInt value,
    Uint8List? data,
  }) async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
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

      final result = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'eth_sendTransaction'.toJS,
          'params': [params.jsify()].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final txHash = result as String;
      debugPrint('[PhantomEthereum] Transaction sent: $txHash');
      return txHash;
    } catch (e) {
      debugPrint('[PhantomEthereum] Send transaction error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signMessage(String message) async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
      }

      debugPrint('[PhantomEthereum] Signing message...');

      // personal_sign 요청
      final result = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'personal_sign'.toJS,
          'params': [
            // Phantom expects message first, then address
            message.toJS,
            connectedAddress!.toJS,
          ].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final signature = result as String;
      debugPrint(
          '[PhantomEthereum] Message signed: ${signature.substring(0, 20)}...');
      return signature;
    } catch (e) {
      debugPrint('[PhantomEthereum] Sign message error: $e');
      rethrow;
    }
  }

  @override
  Future<String> signTypedData(String typedData) async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
      }

      // eth_signTypedData_v4 요청
      final result = await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'eth_signTypedData_v4'.toJS,
          'params': [
            connectedAddress!.toJS,
            typedData.toJS,
          ].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      final signature = result as String;
      return signature;
    } catch (e) {
      debugPrint('[PhantomEthereum] Sign typed data error: $e');
      rethrow;
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
      }

      await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'wallet_switchEthereumChain'.toJS,
          'params': [
            {'chainId': chainId.toJS}.jsify()
          ].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      setChainId(chainId);
      debugPrint('[PhantomEthereum] Switched to chain: $chainId');
    } catch (e) {
      debugPrint('[PhantomEthereum] Switch chain error: $e');
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
    if (!_isPhantomInstalled()) {
      throw Exception('Phantom wallet is not installed');
    }

    try {
      final ethereum = _getPhantomEthereum();
      if (ethereum == null) {
        throw Exception('Failed to get Phantom ethereum provider');
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

      await (ethereum.callMethod(
        'request'.toJS,
        {
          'method': 'wallet_addEthereumChain'.toJS,
          'params': [params.jsify()].toJS,
        }.jsify(),
      ) as JSPromise)
          .toDart;

      debugPrint('[PhantomEthereum] Network added: $chainName');
    } catch (e) {
      debugPrint('[PhantomEthereum] Add network error: $e');
      rethrow;
    }
  }

  void dispose() {
    _accountsChangedController.close();
    _chainChangedController.close();
    _disconnectController.close();
  }
}
