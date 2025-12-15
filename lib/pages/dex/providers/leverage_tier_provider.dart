import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';
import '/models/leverage_tier.dart';

/// 심볼별 레버리지 티어 상태
class LeverageTierState {
  final Map<String, List<LeverageTier>> tiersBySymbol;
  final bool isLoading;
  final String? error;

  LeverageTierState({
    this.tiersBySymbol = const {},
    this.isLoading = false,
    this.error,
  });

  LeverageTierState copyWith({
    Map<String, List<LeverageTier>>? tiersBySymbol,
    bool? isLoading,
    String? error,
  }) {
    return LeverageTierState(
      tiersBySymbol: tiersBySymbol ?? this.tiersBySymbol,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 심볼의 티어 리스트 가져오기 (없으면 기본값)
  List<LeverageTier> getTiers(String symbol) {
    return tiersBySymbol[symbol] ?? LeverageTier.getDefaultBTCTiers();
  }
}

/// 레버리지 티어 Provider
class LeverageTierNotifier extends Notifier<LeverageTierState> {
  @override
  LeverageTierState build() {
    return LeverageTierState();
  }

  /// 심볼의 레버리지 티어 조회
  Future<void> fetchTiers(String symbol) async {
    // 이미 로드된 경우 스킵
    if (state.tiersBySymbol.containsKey(symbol)) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ServerAPI().getLeverageTiers(symbol);
      print('[LeverageTier] API response for $symbol: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final List<dynamic> tiersJson = result['tiers'] ?? [];

        if (tiersJson.isNotEmpty) {
          final tiers = LeverageTier.fromJsonList(tiersJson);
          final newTiersBySymbol = Map<String, List<LeverageTier>>.from(state.tiersBySymbol);
          newTiersBySymbol[symbol] = tiers;

          state = state.copyWith(
            tiersBySymbol: newTiersBySymbol,
            isLoading: false,
          );
          print('[LeverageTier] Loaded ${tiers.length} tiers for $symbol');
        } else {
          // 빈 응답이면 기본값 사용
          state = state.copyWith(isLoading: false);
          print('[LeverageTier] Empty tiers, using default for $symbol');
        }
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '레버리지 티어 조회 실패';
        print('[LeverageTier] Error: $errorMsg');
        state = state.copyWith(isLoading: false, error: errorMsg);
      }
    } catch (e) {
      print('[LeverageTier] Exception: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 심볼의 티어 리스트 가져오기
  List<LeverageTier> getTiers(String symbol) {
    return state.getTiers(symbol);
  }

  /// 최대 오픈 가능 수량 계산 (서버 티어 사용)
  double calculateMaxQuantity({
    required String symbol,
    required double availableBalance,
    required int leverage,
    required double price,
  }) {
    final tiers = getTiers(symbol);
    return LeverageTier.calculateMaxQuantity(
      availableBalance: availableBalance,
      leverage: leverage,
      price: price,
      tiers: tiers,
    );
  }

  /// 레버리지에 따른 최대 명목가치 (서버 티어 사용)
  double getMaxNotionalForLeverage(String symbol, int leverage) {
    final tiers = getTiers(symbol);
    return LeverageTier.getMaxNotionalForLeverage(leverage, tiers: tiers);
  }
}

final leverageTierProvider = NotifierProvider<LeverageTierNotifier, LeverageTierState>(() {
  return LeverageTierNotifier();
});
