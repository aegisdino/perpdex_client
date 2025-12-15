import '../common/util.dart';

class LeverageTier {
  final int tier;
  final double minNotional;
  final double maxNotional;
  final double maintenanceMarginRate; // mmr
  final double initialMarginRate; // imr
  final double mmAmount;
  final int maxLeverage;

  LeverageTier({
    required this.tier,
    required this.minNotional,
    required this.maxNotional,
    required this.maintenanceMarginRate,
    this.initialMarginRate = 0.0,
    this.mmAmount = 0.0,
    required this.maxLeverage,
  });

  /// 서버 JSON에서 생성
  /// 새 API 응답: { "tier": 1, "maxNotional": 50000, "maxLeverage": 125, "mmr": 0.004, "imr": 0.008 }
  factory LeverageTier.fromJson(
      Map<String, dynamic> json, int tierIndex, double prevMaxNotional) {
    final maxNotional = parseDouble(json['maxNotional']);
    // tier 필드가 있으면 사용, 없으면 인덱스 기반
    final tierNum =
        json['tier'] != null ? parseInt(json['tier']) : tierIndex + 1;
    return LeverageTier(
      tier: tierNum,
      minNotional: prevMaxNotional,
      maxNotional: maxNotional,
      maintenanceMarginRate: parseDouble(json['mmr']),
      initialMarginRate: parseDouble(json['imr']),
      mmAmount: parseDouble(json['mmAmount']),
      maxLeverage: parseInt(json['maxLeverage']),
    );
  }

  /// 서버 응답에서 티어 리스트 생성
  static List<LeverageTier> fromJsonList(List<dynamic> jsonList) {
    final tiers = <LeverageTier>[];
    double prevMaxNotional = 0;

    for (int i = 0; i < jsonList.length; i++) {
      print('[LeverageTier] Raw tier[$i]: ${jsonList[i]}');
      final tier = LeverageTier.fromJson(jsonList[i], i, prevMaxNotional);
      print(
          '[LeverageTier] Parsed tier[$i]: tier=${tier.tier}, maxLeverage=${tier.maxLeverage}, maxNotional=${tier.maxNotional}');
      tiers.add(tier);
      prevMaxNotional = tier.maxNotional;
    }

    // tier 번호 오름차순 정렬 (tier1, tier2, tier3...)
    tiers.sort((a, b) => a.tier.compareTo(b.tier));
    print(
        '[LeverageTier] Tiers: ${tiers.map((t) => 'tier${t.tier}:${t.maxLeverage}').toList()}');
    return tiers;
  }

  /// 기본 BTC 티어 (서버 연결 전 또는 실패 시 폴백)
  /*
    tier 번호: 오름차순 (1, 2, 3, 4...)
    maxLeverage: 내림차순 (125, 100, 50, 20...)
    maxNotional: 오름차순 (50,000 → 250,000 → 1,000,000...)
  */
  static List<LeverageTier> getDefaultBTCTiers() {
    return [
      LeverageTier(
        tier: 1,
        minNotional: 0,
        maxNotional: 50000,
        maintenanceMarginRate: 0.004,
        mmAmount: 0,
        maxLeverage: 125,
      ),
      LeverageTier(
        tier: 2,
        minNotional: 50000,
        maxNotional: 250000,
        maintenanceMarginRate: 0.005,
        mmAmount: 50,
        maxLeverage: 100,
      ),
      LeverageTier(
        tier: 3,
        minNotional: 250000,
        maxNotional: 1000000,
        maintenanceMarginRate: 0.01,
        mmAmount: 300,
        maxLeverage: 50,
      ),
      LeverageTier(
        tier: 4,
        minNotional: 1000000,
        maxNotional: 5000000,
        maintenanceMarginRate: 0.025,
        mmAmount: 2000,
        maxLeverage: 20,
      ),
      LeverageTier(
        tier: 5,
        minNotional: 5000000,
        maxNotional: 10000000,
        maintenanceMarginRate: 0.05,
        mmAmount: 10000,
        maxLeverage: 10,
      ),
      LeverageTier(
        tier: 6,
        minNotional: 10000000,
        maxNotional: 20000000,
        maintenanceMarginRate: 0.10,
        mmAmount: 50000,
        maxLeverage: 5,
      ),
    ];
  }

  /// getBTCTiers는 getDefaultBTCTiers로 대체 (호환성 유지)
  static List<LeverageTier> getBTCTiers() => getDefaultBTCTiers();

  static LeverageTier getTierForNotional(double notional,
      {List<LeverageTier>? tiers}) {
    tiers ??= getDefaultBTCTiers();
    for (final tier in tiers) {
      if (notional >= tier.minNotional && notional <= tier.maxNotional) {
        return tier;
      }
    }
    return tiers.last;
  }

  /// 레버리지에 해당하는 티어 찾기
  /// 해당 레버리지를 사용할 수 있는 가장 높은 maxNotional을 가진 티어 반환
  /// 조건: leverage <= tier.maxLeverage인 티어 중 가장 큰 maxNotional
  /// 예: leverage=125 → tier1 (maxNotional=50,000, maxLeverage=125)
  /// 예: leverage=100 → tier2 (maxNotional=250,000, maxLeverage=100)
  /// 예: leverage=50 → tier3 (maxNotional=1,000,000, maxLeverage=50)
  static LeverageTier getTierForLeverage(int leverage,
      {List<LeverageTier>? tiers}) {
    tiers ??= getDefaultBTCTiers();

    // leverage <= maxLeverage 조건을 만족하는 티어 중 가장 큰 maxNotional 찾기
    // tiers는 maxLeverage의 내림차순 소팅이라서 reverse로 해서 역으로 찾음
    LeverageTier? matchingTier;
    for (final tier in tiers.reversed) {
      if (leverage <= tier.maxLeverage) {
        // 더 큰 maxNotional을 가진 티어로 업데이트
        if (matchingTier == null ||
            tier.maxNotional > matchingTier.maxNotional) {
          matchingTier = tier;
        }
        break;
      }
    }

    if (matchingTier == null)
      print(
          'getTierForLeverage: ${leverage} no matching tier. 1st tier will be used');

    // 매칭되는 티어가 없으면 (레버리지가 너무 높으면) 첫 번째 티어 반환
    return matchingTier ?? tiers.first;
  }

  /// 레버리지에 따른 최대 명목가치 반환
  static double getMaxNotionalForLeverage(int leverage,
      {List<LeverageTier>? tiers}) {
    return getTierForLeverage(leverage, tiers: tiers).maxNotional;
  }

  /// 최대 오픈 가능 수량 계산
  /// [availableBalance] 사용 가능 잔액
  /// [leverage] 레버리지
  /// [price] 현재가 또는 주문가
  /// [tiers] 서버에서 받은 티어 리스트 (없으면 기본값 사용)
  /// Returns: 최대 오픈 가능 수량 (BTC 등 기초자산 단위)
  static double calculateMaxQuantity({
    required double availableBalance,
    required int leverage,
    required double price,
    List<LeverageTier>? tiers,
  }) {
    if (price <= 0) return 0;

    // 잔고 기준 최대 명목가치
    final balanceBasedNotional = availableBalance * leverage;

    // 레버리지 티어 기준 최대 명목가치
    final tierMaxNotional = getMaxNotionalForLeverage(leverage, tiers: tiers);

    // 둘 중 작은 값 사용
    final effectiveMaxNotional = balanceBasedNotional < tierMaxNotional
        ? balanceBasedNotional
        : tierMaxNotional;

    // 수량으로 변환
    return effectiveMaxNotional / price;
  }
}
