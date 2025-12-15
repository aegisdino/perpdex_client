import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 주문 이력 데이터 모델
class OrderHistory {
  final int id;
  final String symbol;
  final String side;
  final String type;
  final double quantity;
  final double price;
  final double filledQuantity;
  final double averagePrice;
  final String status;
  final double leverage;
  final double margin;
  final String marginMode;
  final String timeInForce;
  final bool reduceOnly;
  final bool isIceberg;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? filledAt;

  OrderHistory({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    required this.price,
    required this.filledQuantity,
    required this.averagePrice,
    required this.status,
    required this.leverage,
    required this.margin,
    required this.marginMode,
    required this.timeInForce,
    required this.reduceOnly,
    required this.isIceberg,
    required this.isHidden,
    required this.createdAt,
    this.updatedAt,
    this.filledAt,
  });

  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    return OrderHistory(
      id: _parseInt(json['id']),
      symbol: json['symbol'] ?? '',
      side: json['side'] ?? '',
      type: json['type'] ?? '',
      quantity: _parseDouble(json['quantity']),
      price: _parseDouble(json['price']),
      filledQuantity: _parseDouble(json['filled_quantity'] ?? json['filledQuantity']),
      averagePrice: _parseDouble(json['average_price'] ?? json['averagePrice']),
      status: json['status'] ?? '',
      leverage: _parseDouble(json['leverage']),
      margin: _parseDouble(json['margin']),
      marginMode: json['margin_mode'] ?? json['marginMode'] ?? '',
      timeInForce: json['time_in_force'] ?? json['timeInForce'] ?? '',
      reduceOnly: json['reduce_only'] ?? json['reduceOnly'] ?? false,
      isIceberg: json['is_iceberg'] ?? json['isIceberg'] ?? false,
      isHidden: json['is_hidden'] ?? json['isHidden'] ?? false,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTimeNullable(json['updated_at'] ?? json['updatedAt']),
      filledAt: _parseDateTimeNullable(json['filled_at'] ?? json['filledAt']),
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

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // 주문 금액 (quantity * price)
  double get orderAmount => quantity * price;

  // 체결 금액 (filledQuantity * averagePrice)
  double get filledAmount => filledQuantity * averagePrice;

  // 주문 유형 표시 텍스트
  String get typeText {
    switch (type) {
      case 'LIMIT':
        return '지정가';
      case 'MARKET':
        return '시장가';
      case 'STOP_LIMIT':
        return '스탑 지정가';
      case 'STOP_MARKET':
        return '스탑 시장가';
      case 'TAKE_PROFIT':
        return '이익실현';
      case 'STOP_LOSS':
        return '손절';
      default:
        return type;
    }
  }

  // 상태 표시 텍스트
  String get statusText {
    switch (status) {
      case 'FILLED':
        return '체결';
      case 'CANCELLED':
        return '취소';
      case 'REJECTED':
        return '거부';
      case 'PARTIALLY_FILLED':
        return '부분체결';
      case 'EXPIRED':
        return '만료';
      default:
        return status;
    }
  }
}

/// 주문 이력 상태
class OrderHistoryState {
  final List<OrderHistory> orders;
  final bool isLoading;
  final String? error;
  final int total;
  final bool hasMore;

  OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.hasMore = false,
  });

  OrderHistoryState copyWith({
    List<OrderHistory>? orders,
    bool? isLoading,
    String? error,
    int? total,
    bool? hasMore,
  }) {
    return OrderHistoryState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 주문 이력 Provider
class OrderHistoryNotifier extends Notifier<OrderHistoryState> {
  @override
  OrderHistoryState build() {
    return OrderHistoryState();
  }

  /// 주문 이력 조회
  Future<void> fetchOrderHistory({
    String? symbol,
    String? status,
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
      final result = await ServerAPI().getFuturesOrderHistory(
        symbol: symbol,
        status: status,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        offset: offset,
      );

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final List<dynamic> ordersJson = result['orders'] ?? result['data'] ?? [];
        final orders = ordersJson.map((e) => OrderHistory.fromJson(e)).toList();
        final pagination = result['pagination'] ?? {};

        state = state.copyWith(
          orders: append ? [...state.orders, ...orders] : orders,
          isLoading: false,
          total: pagination['total'] ?? orders.length,
          hasMore: pagination['hasMore'] ?? false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result?['message'] ?? result?['error'] ?? '주문 이력 조회 실패',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 더 불러오기
  Future<void> loadMore({String? symbol, String? status}) async {
    if (state.isLoading || !state.hasMore) return;

    await fetchOrderHistory(
      symbol: symbol,
      status: status,
      offset: state.orders.length,
      append: true,
    );
  }
}

final orderHistoryProvider = NotifierProvider<OrderHistoryNotifier, OrderHistoryState>(() {
  return OrderHistoryNotifier();
});
