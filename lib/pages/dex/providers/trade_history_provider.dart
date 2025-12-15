import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 거래(체결) 내역 데이터 모델
class TradeHistory {
  final int id;
  final int orderId;
  final int positionId;
  final String symbol;
  final String side;
  final double price;
  final double quantity;
  final double fee;
  final String role; // MAKER / TAKER
  final double realizedPnl;
  final String tradeId;
  final DateTime createdAt;

  TradeHistory({
    required this.id,
    required this.orderId,
    required this.positionId,
    required this.symbol,
    required this.side,
    required this.price,
    required this.quantity,
    required this.fee,
    required this.role,
    required this.realizedPnl,
    required this.tradeId,
    required this.createdAt,
  });

  factory TradeHistory.fromJson(Map<String, dynamic> json) {
    return TradeHistory(
      id: _parseInt(json['id']),
      orderId: _parseInt(json['order_id'] ?? json['orderId']),
      positionId: _parseInt(json['position_id'] ?? json['positionId']),
      symbol: json['symbol'] ?? '',
      side: json['side'] ?? '',
      price: _parseDouble(json['price']),
      quantity: _parseDouble(json['quantity']),
      fee: _parseDouble(json['fee']),
      role: json['role'] ?? '',
      realizedPnl: _parseDouble(json['realized_pnl'] ?? json['realizedPnl']),
      tradeId: json['trade_id']?.toString() ?? json['tradeId']?.toString() ?? '',
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // 거래 금액
  double get amount => price * quantity;

  // 역할 표시 텍스트
  String get roleText => role == 'MAKER' ? '메이커' : '테이커';
}

/// 거래 내역 상태
class TradeHistoryState {
  final List<TradeHistory> trades;
  final bool isLoading;
  final String? error;
  final int total;
  final bool hasMore;

  TradeHistoryState({
    this.trades = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.hasMore = false,
  });

  TradeHistoryState copyWith({
    List<TradeHistory>? trades,
    bool? isLoading,
    String? error,
    int? total,
    bool? hasMore,
  }) {
    return TradeHistoryState(
      trades: trades ?? this.trades,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 거래 내역 Provider
class TradeHistoryNotifier extends Notifier<TradeHistoryState> {
  @override
  TradeHistoryState build() {
    return TradeHistoryState();
  }

  /// 거래 내역 조회
  Future<void> fetchTradeHistory({
    String? symbol,
    String? startDate,
    String? endDate,
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
    if (!append) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final result = await ServerAPI().getFuturesMyTrades(
        symbol: symbol,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        offset: offset,
      );

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final List<dynamic> tradesJson = result['trades'] ?? result['data'] ?? [];
        final trades = tradesJson.map((e) => TradeHistory.fromJson(e)).toList();
        final pagination = result['pagination'] ?? {};

        state = state.copyWith(
          trades: append ? [...state.trades, ...trades] : trades,
          isLoading: false,
          total: pagination['total'] ?? trades.length,
          hasMore: pagination['hasMore'] ?? false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result?['message'] ?? result?['error'] ?? '거래 내역 조회 실패',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 더 불러오기
  Future<void> loadMore({String? symbol}) async {
    if (state.isLoading || !state.hasMore) return;

    await fetchTradeHistory(
      symbol: symbol,
      offset: state.trades.length,
      append: true,
    );
  }
}

final tradeHistoryProvider = NotifierProvider<TradeHistoryNotifier, TradeHistoryState>(() {
  return TradeHistoryNotifier();
});
