import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// NEAR Protocol JavaScript 상호운용 유틸리티
/// NEAR Wallet Selector Modal을 통한 지갑 통합 관리
class NearJsInterop {
  /// NEAR Wallet Modal 초기화 및 설정
  static Future<bool> initWalletModal({
    String networkId = 'mainnet',
    String? contractId,
  }) async {
    try {
      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) {
        debugPrint('[NearJsInterop] NearWalletAPI not found');
        return false;
      }

      final apiObj = api as JSObject;

      // Configure first
      final configureMethod = apiObj.getProperty('configure'.toJS);
      if (configureMethod != null) {
        final config = {
          'networkId': networkId,
          if (contractId != null) 'contractId': contractId,
        }.jsify();

        (configureMethod as JSFunction).callAsFunction(
          apiObj,
          config,
        );
      }

      // Then initialize
      final initMethod = apiObj.getProperty('init'.toJS);

      if (initMethod == null) {
        debugPrint('[NearJsInterop] init method not found');
        return false;
      }

      final promise = (initMethod as JSFunction).callAsFunction(
        apiObj,
      ) as JSPromise;

      final result = await promise.toDart;

      // Check result
      if (result is JSObject) {
        final success = result.getProperty('success'.toJS);
        if (success is JSBoolean) {
          final isSuccess = success.toDart;
          debugPrint('[NearJsInterop] Wallet Modal initialized: $isSuccess');
          return isSuccess;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[NearJsInterop] Wallet Modal init error: $e');
      return false;
    }
  }

  /// 모달 다이얼로그를 표시하여 지갑 선택 및 연결
  static Future<String?> showWalletModal() async {
    try {
      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) {
        throw Exception('NearWalletAPI not initialized');
      }

      final apiObj = api as JSObject;
      final showModalMethod = apiObj.getProperty('showModal'.toJS);

      if (showModalMethod == null) {
        throw Exception('showModal method not found');
      }

      debugPrint('[NearJsInterop] Showing wallet modal...');

      final promise = (showModalMethod as JSFunction).callAsFunction(
        apiObj,
      ) as JSPromise;

      final result = await promise.toDart;

      // JavaScript returns { success: true, accountId: '...' } or { success: false, error: '...' }
      if (result is JSObject) {
        final success = result.getProperty('success'.toJS);
        if (success is JSBoolean && success.toDart) {
          final accountId = result.getProperty('accountId'.toJS);
          if (accountId is JSString) {
            final account = accountId.toDart;
            debugPrint('[NearJsInterop] Modal connection completed: $account');
            return account;
          }
        } else {
          // Error or cancelled
          final error = result.getProperty('error'.toJS);
          if (error is JSString) {
            debugPrint('[NearJsInterop] Modal cancelled: ${error.toDart}');
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[NearJsInterop] Show modal error: $e');
      rethrow;
    }
  }

  /// 현재 연결된 계정 정보 가져오기
  static Future<String?> getCurrentAccount() async {
    try {
      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) return null;

      final apiObj = api as JSObject;
      final getAccountMethod = apiObj.getProperty('getAccount'.toJS);

      if (getAccountMethod == null) return null;

      final result = (getAccountMethod as JSFunction).callAsFunction(
        apiObj,
      );

      if (result is JSObject) {
        final connected = result.getProperty('connected'.toJS);
        if (connected is JSBoolean && connected.toDart) {
          final accountId = result.getProperty('accountId'.toJS);
          if (accountId is JSString) {
            return accountId.toDart;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[NearJsInterop] Get account error: $e');
      return null;
    }
  }

  /// NEAR 지갑 연결 (Modal 사용 - 모든 NEAR 지갑 통합)
  /// Meteor, MyNearWallet, HERE Wallet 등을 모달에서 선택
  static Future<String?> connectNearWallet({String? contractId}) async {
    try {
      debugPrint('[NearJsInterop] Opening NEAR Wallet Modal...');

      // Modal 초기화
      await initWalletModal(
        contractId: contractId ?? 'perpdex.near', // 기본 컨트랙트 ID
      );

      // Modal 표시 - 사용자가 지갑 선택
      final accountId = await showWalletModal();

      if (accountId != null) {
        debugPrint('[NearJsInterop] NEAR Wallet connected: $accountId');
        return accountId;
      }

      debugPrint('[NearJsInterop] NEAR Wallet connection cancelled or failed');
      return null;
    } catch (e) {
      debugPrint('[NearJsInterop] NEAR Wallet connection error: $e');
      rethrow;
    }
  }

  /// Meteor Wallet 연결 (Modal 사용)
  static Future<String?> connectMeteorWallet({String? contractId}) async {
    return connectNearWallet(contractId: contractId);
  }

  /// MyNearWallet 연결 (Modal 사용)
  static Future<String?> connectMyNearWallet({String? contractId}) async {
    return connectNearWallet(contractId: contractId);
  }

  /// HERE Wallet 연결 (Modal 사용)
  static Future<String?> connectHereWallet({String? contractId}) async {
    return connectNearWallet(contractId: contractId);
  }

  /// NEAR 지갑 연결 해제 (Modal API 사용)
  static Future<void> disconnectNearWallet() async {
    try {
      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) return;

      final apiObj = api as JSObject;
      final disconnectMethod = apiObj.getProperty('disconnect'.toJS);

      if (disconnectMethod == null) return;

      debugPrint('[NearJsInterop] Disconnecting NEAR Wallet...');

      final promise = (disconnectMethod as JSFunction).callAsFunction(
        apiObj,
      ) as JSPromise;

      await promise.toDart;
      debugPrint('[NearJsInterop] NEAR Wallet disconnected');
    } catch (e) {
      debugPrint('[NearJsInterop] NEAR Wallet disconnect error: $e');
      rethrow;
    }
  }

  /// Meteor Wallet 연결 해제 (Modal API 사용)
  static Future<void> disconnectMeteorWallet() async {
    return disconnectNearWallet();
  }

  /// MyNearWallet 연결 해제 (Modal API 사용)
  static Future<void> disconnectMyNearWallet() async {
    return disconnectNearWallet();
  }

  /// HERE Wallet 연결 해제 (Modal API 사용)
  static Future<void> disconnectHereWallet() async {
    return disconnectNearWallet();
  }

  /// NEAR 잔액 조회 (yoctoNEAR 단위)
  static Future<BigInt> getBalance(String accountId) async {
    try {
      debugPrint('[NearJsInterop] Getting balance for: $accountId');

      // NEAR RPC를 통해 잔액 조회
      final response = await _callNearRpc({
        'jsonrpc': '2.0',
        'id': 'dontcare',
        'method': 'query',
        'params': {
          'request_type': 'view_account',
          'finality': 'final',
          'account_id': accountId,
        }
      });

      if (response is JSObject) {
        final result = response.getProperty('result'.toJS);
        if (result is JSObject) {
          final amount = result.getProperty('amount'.toJS);
          if (amount is JSString) {
            final balance = BigInt.parse(amount.toDart);
            debugPrint('[NearJsInterop] Balance: $balance yoctoNEAR');
            return balance;
          }
        }
      }

      return BigInt.zero;
    } catch (e) {
      debugPrint('[NearJsInterop] Get balance error: $e');
      rethrow;
    }
  }

  /// 트랜잭션 전송 (Modal API 사용)
  static Future<String> sendTransaction({
    required String receiverId,
    required List<Map<String, dynamic>> actions,
    required String walletType,
  }) async {
    try {
      debugPrint('[NearJsInterop] Sending transaction via Modal API...');

      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) {
        throw Exception('NearWalletAPI not initialized');
      }

      final apiObj = api as JSObject;
      final sendTxMethod = apiObj.getProperty('sendTransaction'.toJS);

      if (sendTxMethod == null) {
        throw Exception('sendTransaction method not found');
      }

      final promise = (sendTxMethod as JSFunction).callAsFunction(
        apiObj,
        receiverId.toJS,
        actions.jsify(),
      ) as JSPromise;

      final result = await promise.toDart;

      // JavaScript returns { success: true, transactionHash: '...' }
      if (result is JSObject) {
        final success = result.getProperty('success'.toJS);
        if (success is JSBoolean && success.toDart) {
          final txHash = result.getProperty('transactionHash'.toJS);
          if (txHash is JSString) {
            final txHashStr = txHash.toDart;
            debugPrint('[NearJsInterop] Transaction sent: $txHashStr');
            return txHashStr;
          }
        } else {
          // Error case
          final error = result.getProperty('error'.toJS);
          if (error is JSString) {
            throw Exception(error.toDart);
          }
        }
      }

      throw Exception('Failed to extract transaction hash');
    } catch (e) {
      debugPrint('[NearJsInterop] Send transaction error: $e');
      rethrow;
    }
  }

  /// 메시지 서명 (Modal API 사용 - NEP-413 표준)
  /// https://github.com/near/NEPs/blob/master/neps/nep-0413.md
  static Future<Map<String, String>> signMessage({
    required String message,
    String? recipient,
    List<int>? nonce,
  }) async {
    try {
      debugPrint('[NearJsInterop] Signing message via Modal API...');

      final window = web.window as JSObject;
      final api = window.getProperty('NearWalletAPI'.toJS);

      if (api == null) {
        throw Exception('NearWalletAPI not initialized');
      }

      final apiObj = api as JSObject;
      final signMethod = apiObj.getProperty('signMessage'.toJS);

      if (signMethod == null) {
        throw Exception('signMessage method not supported by Modal API');
      }

      final promise = (signMethod as JSFunction).callAsFunction(
        apiObj,
        message.toJS,
        recipient?.toJS,
        nonce?.jsify(),
      ) as JSPromise;

      final result = await promise.toDart;

      // JavaScript returns { success: true, signature: '...', publicKey: '...' }
      if (result is JSObject) {
        final success = result.getProperty('success'.toJS);
        if (success is JSBoolean && success.toDart) {
          final signature = result.getProperty('signature'.toJS);
          final publicKey = result.getProperty('publicKey'.toJS);

          if (signature is JSString && publicKey is JSString) {
            final sig = signature.toDart;
            final pubKey = publicKey.toDart;
            debugPrint('[NearJsInterop] Message signed successfully');
            return {
              'signature': sig,
              'publicKey': pubKey,
            };
          }
        } else {
          // Error case
          final error = result.getProperty('error'.toJS);
          if (error is JSString) {
            throw Exception(error.toDart);
          }
        }
      }

      throw Exception('Failed to extract signature');
    } catch (e) {
      debugPrint('[NearJsInterop] Sign message error: $e');
      rethrow;
    }
  }

  /// NEAR RPC 호출
  static Future<JSAny?> _callNearRpc(Map<String, dynamic> params) async {
    try {
      const rpcUrl = 'https://rpc.mainnet.near.org';

      final responsePromise = web.window.fetch(
        rpcUrl.toJS,
        web.RequestInit(
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          }.jsify() as JSObject,
          body: params.toString().toJS,
        ),
      );

      final response = await responsePromise.toDart;

      if (!response.ok) {
        throw Exception('RPC request failed: ${response.status}');
      }

      final jsonPromise = response.json();
      return await jsonPromise.toDart;
    } catch (e) {
      debugPrint('[NearJsInterop] RPC call error: $e');
      rethrow;
    }
  }
}
