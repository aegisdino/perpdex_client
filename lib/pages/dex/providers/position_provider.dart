import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 포지션 데이터 모델
class FuturesPosition {
  final String id; // 포지션 ID
  final String symbol;
  final String side; // 'LONG' or 'SHORT'
  final double size; // 포지션 크기 (수량)
  final double entryPrice; // 진입가
  double markPrice; // 현재가 (마크 프라이스) - 업데이트 가능하도록 mutable
  double liquidationPrice; // 청산가 - 실시간 업데이트 가능
  double _unrealizedPnl = 0.0; // 서버에서 받은 미실현 손익
  final double margin; // 증거금 (개시 마진)
  final double maintenanceMargin; // 유지 마진
  final double leverage; // 레버리지
  final DateTime createdAt;

  FuturesPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.size,
    required this.entryPrice,
    required this.markPrice,
    required this.liquidationPrice,
    required this.margin,
    this.maintenanceMargin = 0.0,
    required this.leverage,
    required this.createdAt,
  });

  factory FuturesPosition.fromJson(Map<String, dynamic> json) {
    // ID 필드 파싱 시도 (여러 가능한 필드명 체크)
    String positionId = '';

    // 먼저 모든 가능한 ID 필드를 체크
    final possibleIdFields = ['id', 'positionId', '_id', 'position_id'];
    for (final field in possibleIdFields) {
      if (json[field] != null) {
        positionId = json[field].toString();
        print('[Position] Found ID in field "$field": $positionId');
        break;
      }
    }

    // ID를 찾지 못한 경우 전체 JSON 출력
    if (positionId.isEmpty) {
      print('[Position] WARNING: No ID found! JSON keys: ${json.keys.toList()}');
    }

    return FuturesPosition(
      id: positionId,
      symbol: json['symbol'] ?? '',
      side: json['side'] ?? '',
      size: _parseDouble(json['quantity'] ?? json['size']),
      entryPrice: _parseDouble(json['entryPrice'] ?? json['entry_price']),
      markPrice: _parseDouble(json['markPrice'] ?? json['mark_price']),
      liquidationPrice:
          _parseDouble(json['liquidationPrice'] ?? json['liquidation_price']),
      margin: _parseDouble(json['margin']),
      maintenanceMargin: _parseDouble(json['maintenanceMargin'] ?? json['maintenance_margin']),
      leverage: _parseDouble(json['leverage']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : (json['updatedAt'] != null
                  ? DateTime.parse(json['updatedAt'])
                  : DateTime.now())),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // 미실현 손익 (서버에서 제공하는 값 사용, 없으면 클라이언트 계산)
  double get unrealizedPnl {
    if (_unrealizedPnl != 0.0) return _unrealizedPnl;
    if (size == 0) return 0.0;
    // LONG: (현재가 - 진입가) × 수량
    // SHORT: (진입가 - 현재가) × 수량
    if (side == 'LONG') {
      return (markPrice - entryPrice) * size.abs();
    } else {
      return (entryPrice - markPrice) * size.abs();
    }
  }

  // 수익률 계산 (ROE = 손익 / 증거금 × 100)
  double get roe {
    if (margin == 0) return 0.0;
    return (unrealizedPnl / margin) * 100;
  }

  // 현재가 업데이트 (외부에서 호출)
  void updateMarkPrice(double newPrice) {
    markPrice = newPrice;
  }

  // 청산가 업데이트
  void updateLiquidationPrice(double newPrice) {
    liquidationPrice = newPrice;
  }

  // 미실현 손익 업데이트 (서버에서 받은 값)
  void updateUnrealizedPnl(double pnl) {
    _unrealizedPnl = pnl;
  }
}

/// 포지션 목록 상태
class PositionListState {
  final List<FuturesPosition> positions;
  final bool isLoading;
  final String? error;

  PositionListState({
    this.positions = const [],
    this.isLoading = false,
    this.error,
  });

  /// 총 유지 마진 (모든 포지션의 maintenanceMargin 합계)
  double get totalMaintenanceMargin {
    return positions.fold(0.0, (sum, pos) => sum + pos.maintenanceMargin);
  }

  /// 총 미실현 손익 (모든 포지션의 unrealizedPnl 합계)
  double get totalUnrealizedPnl {
    return positions.fold(0.0, (sum, pos) => sum + pos.unrealizedPnl);
  }

  PositionListState copyWith({
    List<FuturesPosition>? positions,
    bool? isLoading,
    String? error,
  }) {
    return PositionListState(
      positions: positions ?? this.positions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 포지션 목록 Provider
class PositionListNotifier extends Notifier<PositionListState> {
  @override
  PositionListState build() {
    return PositionListState();
  }

  /// 포지션 목록 조회
  Future<void> fetchPositions({String? symbol}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ServerAPI().getFuturesPositions(symbol: symbol);

      print(result);

      if (result != null && result['result'] == 0) {
        final List<dynamic> positionsJson = result['positions'] ?? [];
        print('[Position] positionsJson count: ${positionsJson.length}');
        final positions =
            positionsJson.map((e) {
              final jsonMap = e as Map<String, dynamic>;
              print('[Position] Raw JSON: $jsonMap');
              print('[Position] JSON keys: ${jsonMap.keys.toList()}');
              final position = FuturesPosition.fromJson(jsonMap);
              print('[Position] Parsed position - ID: "${position.id}", Symbol: ${position.symbol}, Side: ${position.side}');
              return position;
            }).toList();
        state = state.copyWith(positions: positions, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result?['message'] ?? result?['error'] ?? '포지션 조회 실패',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 포지션 추가 (로컬)
  void addPosition(FuturesPosition position) {
    state = state.copyWith(positions: [position, ...state.positions]);
  }

  /// 특정 심볼의 현재가 업데이트 (실시간 가격 업데이트용)
  void updateMarkPrice(String symbol, double newPrice) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol) {
        position.updateMarkPrice(newPrice);
      }
      return position;
    }).toList();

    // 상태 업데이트 (UI 재렌더링 트리거)
    state = state.copyWith(positions: updatedPositions);
  }

  /// 여러 심볼의 현재가 일괄 업데이트
  void updateMarkPrices(Map<String, double> priceMap) {
    final updatedPositions = state.positions.map((position) {
      final newPrice = priceMap[position.symbol];
      if (newPrice != null) {
        position.updateMarkPrice(newPrice);
      }
      return position;
    }).toList();

    // 상태 업데이트 (UI 재렌더링 트리거)
    state = state.copyWith(positions: updatedPositions);
  }

  /// 특정 심볼의 청산가 업데이트
  void updateLiquidationPrice(String symbol, double newPrice) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol) {
        position.updateLiquidationPrice(newPrice);
      }
      return position;
    }).toList();
    state = state.copyWith(positions: updatedPositions);
  }

  /// 특정 심볼의 미실현 손익 업데이트
  void updateUnrealizedPnl(String symbol, double pnl) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol) {
        position.updateUnrealizedPnl(pnl);
      }
      return position;
    }).toList();
    state = state.copyWith(positions: updatedPositions);
  }

  /// 특정 심볼+side의 현재가 업데이트 (헤지 모드 지원)
  void updateMarkPriceBySide(String symbol, String? side, double newPrice) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol && (side == null || position.side == side)) {
        position.updateMarkPrice(newPrice);
      }
      return position;
    }).toList();
    state = state.copyWith(positions: updatedPositions);
  }

  /// 특정 심볼+side의 청산가 업데이트 (헤지 모드 지원)
  void updateLiquidationPriceBySide(String symbol, String? side, double newPrice) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol && (side == null || position.side == side)) {
        position.updateLiquidationPrice(newPrice);
      }
      return position;
    }).toList();
    state = state.copyWith(positions: updatedPositions);
  }

  /// 특정 심볼+side의 미실현 손익 업데이트 (헤지 모드 지원)
  void updateUnrealizedPnlBySide(String symbol, String? side, double pnl) {
    final updatedPositions = state.positions.map((position) {
      if (position.symbol == symbol && (side == null || position.side == side)) {
        position.updateUnrealizedPnl(pnl);
      }
      return position;
    }).toList();
    state = state.copyWith(positions: updatedPositions);
  }

  /// 포지션 종료
  /// [positionId] 포지션 ID
  /// [quantity] 청산할 수량 (null이면 전체 청산, 값이 있으면 부분 청산)
  Future<bool> closePosition(String positionId, {String? quantity}) async {
    try {
      final result = await ServerAPI().closeFuturesPosition(positionId, quantity: quantity);
      if (result != null && result['result'] == 0) {
        if (quantity == null) {
          // 전체 청산: 포지션을 로컬 상태에서 즉시 제거
          state = state.copyWith(
            positions: state.positions.where((position) => position.id != positionId).toList(),
          );
        } else {
          // 부분 청산: 서버에서 최신 데이터를 다시 가져옴
          await fetchPositions();
        }
        return true;
      }
    } catch (e) {
      print('Close position error: $e');
    }
    return false;
  }
}

final positionListProvider =
    NotifierProvider<PositionListNotifier, PositionListState>(() {
  return PositionListNotifier();
});
