import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 선물 잔고 데이터 모델
class FuturesBalance {
  final double totalBalance; // 총 지갑 잔액
  final double availableBalance; // 사용 가능 잔액
  final double lockedBalance; // 미체결 주문에 잠긴 금액
  final double totalUnrealizedPnl; // 총 미실현 손익
  final double totalMaintenanceMargin; // 총 유지 마진
  final double equity; // 자산 (wallet + unrealizedPnl)
  final double marginRatio; // 마진 비율

  FuturesBalance({
    this.totalBalance = 0.0,
    this.availableBalance = 0.0,
    this.lockedBalance = 0.0,
    this.totalUnrealizedPnl = 0.0,
    this.totalMaintenanceMargin = 0.0,
    this.equity = 0.0,
    this.marginRatio = 0.0,
  });

  factory FuturesBalance.fromJson(Map<String, dynamic> json) {
    return FuturesBalance(
      totalBalance: _parseDouble(json['totalBalance']),
      availableBalance: _parseDouble(json['availableBalance']),
      lockedBalance: _parseDouble(json['lockedBalance']),
      totalUnrealizedPnl: _parseDouble(json['totalUnrealizedPnl']),
      totalMaintenanceMargin: _parseDouble(json['totalMaintenanceMargin']),
      equity: _parseDouble(json['equity']),
      marginRatio: _parseDouble(json['marginRatio']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// 잔고 상태
class BalanceState {
  final FuturesBalance balance;
  final bool isLoading;
  final String? error;

  BalanceState({
    FuturesBalance? balance,
    this.isLoading = false,
    this.error,
  }) : balance = balance ?? FuturesBalance();

  BalanceState copyWith({
    FuturesBalance? balance,
    bool? isLoading,
    String? error,
  }) {
    return BalanceState(
      balance: balance ?? this.balance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 잔고 Provider
class BalanceNotifier extends Notifier<BalanceState> {
  @override
  BalanceState build() {
    return BalanceState();
  }

  /// 잔고 조회
  Future<void> fetchBalance() async {
    print('[Balance] fetchBalance() called');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ServerAPI().getFuturesBalance();
      print('[Balance] API response received');

      print('[Balance] Raw result: $result');
      print('[Balance] Result type: ${result.runtimeType}');
      if (result is Map) {
        print('[Balance] Result keys: ${result.keys.toList()}');
      }

      if (result != null && result['result'] == 0) {
        // 서버 응답에서 balance 데이터 추출
        Map<String, dynamic> balanceJson;
        if (result['balance'] != null) {
          balanceJson = result['balance'] as Map<String, dynamic>;
        } else {
          // balance 키가 없으면 result 자체에서 추출 (result 키 제외)
          balanceJson = Map<String, dynamic>.from(result);
          balanceJson.remove('result');
        }

        print('[Balance] Balance JSON: $balanceJson');

        final balance = FuturesBalance.fromJson(balanceJson);
        print('[Balance] Parsed:');
        print('[Balance]   totalBalance: ${balance.totalBalance}');
        print('[Balance]   availableBalance: ${balance.availableBalance}');
        print('[Balance]   lockedBalance: ${balance.lockedBalance}');
        print('[Balance]   equity: ${balance.equity}');
        print('[Balance]   totalUnrealizedPnl: ${balance.totalUnrealizedPnl}');
        state = state.copyWith(balance: balance, isLoading: false);
      } else {
        // 서버 접속 실패 시 잔고 초기화
        final errorMsg = result?['message'] ?? result?['error'] ?? '잔고 조회 실패';
        print('[Balance] Error response: $errorMsg - resetting balance');
        state = state.copyWith(
          balance: FuturesBalance(), // 잔고 초기화
          isLoading: false,
          error: errorMsg,
        );
      }
    } catch (e, stackTrace) {
      // 예외 발생 시 잔고 초기화
      print('[Balance] Exception: $e - resetting balance');
      print('[Balance] StackTrace: $stackTrace');
      state = state.copyWith(
        balance: FuturesBalance(), // 잔고 초기화
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 실시간 잔고 업데이트 (WebSocket POSITIONS_STATUS에서 호출)
  void updateRealtimeBalance(
      {double? equity, double? totalUnrealizedPnl, double? totalMargin}) {
    final currentBalance = state.balance;
    final updatedBalance = FuturesBalance(
      totalBalance: currentBalance.totalBalance,
      availableBalance: currentBalance.availableBalance,
      lockedBalance: currentBalance.lockedBalance,
      totalUnrealizedPnl:
          totalUnrealizedPnl ?? currentBalance.totalUnrealizedPnl,
      totalMaintenanceMargin:
          totalMargin ?? currentBalance.totalMaintenanceMargin,
      equity: equity ?? currentBalance.equity,
      marginRatio: currentBalance.marginRatio,
    );
    state = state.copyWith(balance: updatedBalance);
  }
}

final balanceProvider = NotifierProvider<BalanceNotifier, BalanceState>(() {
  return BalanceNotifier();
});
