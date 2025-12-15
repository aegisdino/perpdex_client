import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

import '/platform/platform.dart';
import '../core/ethereum_wallet.dart';

/// MetaMask 모바일 딥링크 구현
/// Web에서는 metamask_wallet.dart가 사용되고,
/// 모바일에서는 이 파일이 conditional import로 사용됨
class MetaMaskWallet extends EthereumWallet {
  final _accountsChangedController = StreamController<String?>.broadcast();
  final _chainChangedController = StreamController<String?>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Completer<Map<String, dynamic>>? _pendingRequest;

  @override
  Stream<String?> get onAccountsChanged => _accountsChangedController.stream;

  @override
  Stream<String?> get onChainChanged => _chainChangedController.stream;

  @override
  Stream<void> get onDisconnect => _disconnectController.stream;

  MetaMaskWallet() {
    _setupDeepLinkListener();
  }

  Future<void> _setupDeepLinkListener() async {
    _appLinks = AppLinks();

    // 앱이 열려있을 때 딥링크 수신
    _linkSubscription = _appLinks?.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    });

    // 앱이 닫혀있을 때 받은 딥링크 처리
    final uri = await _appLinks?.getInitialLink();
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('MetaMask deeplink received: $uri');

    if (uri.path.contains('/metamask/callback')) {
      final params = uri.queryParameters;

      // 에러 처리
      if (params.containsKey('error')) {
        final error = params['error'];
        debugPrint('MetaMask error: $error');
        if (_pendingRequest != null && !_pendingRequest!.isCompleted) {
          _pendingRequest!.completeError(Exception(error));
        }
        return;
      }

      // 성공 응답 처리
      if (_pendingRequest != null && !_pendingRequest!.isCompleted) {
        _pendingRequest!.complete(params);
      }
    }
  }

  /// MetaMask 딥링크 URL 생성
  String _createDeepLink({
    required String method,
    Map<String, dynamic>? params,
  }) {
    // 앱 리턴 URL (딥링크 콜백)
    final returnUrl = kIsWeb
        ? Uri.base.toString()
        : 'bitupdownapp://metamask/callback';

    final queryParams = <String, String>{
      'redirect': returnUrl,
    };

    // 메서드별 파라미터 추가
    switch (method) {
      case 'connect':
        // 연결 요청은 추가 파라미터 없음
        break;

      case 'sendTransaction':
        if (params != null) {
          queryParams['to'] = params['to'];
          queryParams['value'] = params['value'];
          if (params['data'] != null) {
            queryParams['data'] = params['data'];
          }
        }
        break;

      case 'signMessage':
        if (params != null) {
          queryParams['message'] = params['message'];
        }
        break;

      case 'signTypedData':
        if (params != null) {
          queryParams['data'] = params['data'];
        }
        break;
    }

    // MetaMask 딥링크 스키마
    // metamask://connect?redirect=...
    // metamask://send?to=...&value=...&redirect=...
    final uri = Uri(
      scheme: 'metamask',
      host: method == 'connect' ? 'connect' : method,
      queryParameters: queryParams,
    );

    return uri.toString();
  }

  @override
  Future<String?> connect() async {
    try {
      final deepLink = _createDeepLink(method: 'connect');
      debugPrint('Opening MetaMask: $deepLink');

      _pendingRequest = Completer<Map<String, dynamic>>();

      await openUrl(deepLink);

      // 30초 타임아웃
      final result = await _pendingRequest!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );

      // 주소 추출
      final address = result['address'] ?? result['account'];
      if (address != null) {
        setConnectedAddress(address);

        // 체인 ID도 받았다면 설정
        final chainId = result['chainId'];
        if (chainId != null) {
          setChainId(chainId);
        }

        return address;
      }
    } catch (e) {
      debugPrint('MetaMask connect error: $e');

      // MetaMask가 설치되지 않은 경우 앱스토어로 이동
      if (e.toString().contains('No application found')) {
        await openUrl(
          'https://metamask.app.link/skAH3BaF99',
          target: '_blank',
        );
      }
      rethrow;
    } finally {
      _pendingRequest = null;
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    setConnectedAddress(null);
    setChainId(null);
    _disconnectController.add(null);
  }

  @override
  Future<BigInt> getBalance(String address) async {
    // 모바일에서는 RPC를 통해 직접 조회해야 함
    // web3dart를 사용하여 RPC 호출
    throw UnimplementedError(
      'Balance query not implemented yet for mobile. '
      'Use Web3Client with RPC endpoint instead.',
    );
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
      final params = {
        'to': to,
        'value': '0x${value.toRadixString(16)}',
      };

      if (data != null) {
        params['data'] = '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      }

      final deepLink = _createDeepLink(
        method: 'sendTransaction',
        params: params,
      );

      _pendingRequest = Completer<Map<String, dynamic>>();

      await openUrl(deepLink);

      final result = await _pendingRequest!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Transaction timeout');
        },
      );

      final txHash = result['hash'] ?? result['transactionHash'];
      if (txHash == null) {
        throw Exception('Transaction hash not received');
      }

      return txHash;
    } catch (e) {
      debugPrint('Send transaction error: $e');
      rethrow;
    } finally {
      _pendingRequest = null;
    }
  }

  @override
  Future<String> signMessage(String message) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      // UTF-8 메시지를 hex로 변환
      final messageBytes = utf8.encode(message);
      final messageHex = '0x${messageBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      final deepLink = _createDeepLink(
        method: 'signMessage',
        params: {'message': messageHex},
      );

      _pendingRequest = Completer<Map<String, dynamic>>();

      await openUrl(deepLink);

      final result = await _pendingRequest!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Sign message timeout');
        },
      );

      final signature = result['signature'];
      if (signature == null) {
        throw Exception('Signature not received');
      }

      return signature;
    } catch (e) {
      debugPrint('Sign message error: $e');
      rethrow;
    } finally {
      _pendingRequest = null;
    }
  }

  @override
  Future<String> signTypedData(String typedData) async {
    if (connectedAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final deepLink = _createDeepLink(
        method: 'signTypedData',
        params: {'data': typedData},
      );

      _pendingRequest = Completer<Map<String, dynamic>>();

      await openUrl(deepLink);

      final result = await _pendingRequest!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Sign typed data timeout');
        },
      );

      final signature = result['signature'];
      if (signature == null) {
        throw Exception('Signature not received');
      }

      return signature;
    } catch (e) {
      debugPrint('Sign typed data error: $e');
      rethrow;
    } finally {
      _pendingRequest = null;
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    // 딥링크로는 체인 전환 지원이 제한적
    // 사용자가 MetaMask 앱에서 직접 변경해야 함
    throw UnimplementedError(
      'Chain switching not supported via deeplink. '
      'Please switch network in MetaMask app.',
    );
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
    // 딥링크로는 네트워크 추가 지원이 제한적
    throw UnimplementedError(
      'Adding network not supported via deeplink. '
      'Please add network in MetaMask app.',
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
    _accountsChangedController.close();
    _chainChangedController.close();
    _disconnectController.close();
  }
}
