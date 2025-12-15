import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 주문 데이터 모델
class FuturesOrder {
  final int id;
  final String symbol;
  final String side; // 'BUY' or 'SELL'
  final String type; // 'LIMIT' or 'MARKET'
  final double price;
  final double quantity;
  final double filledQuantity;
  final String status; // 'OPEN', 'FILLED', 'CANCELLED'
  final DateTime createdAt;

  FuturesOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.price,
    required this.quantity,
    required this.filledQuantity,
    required this.status,
    required this.createdAt,
  });

  factory FuturesOrder.fromJson(Map<String, dynamic> json) {
    return FuturesOrder(
      id: _parseInt(json['id']),
      symbol: json['symbol'] ?? '',
      side: json['side'] ?? '',
      type: json['type'] ?? '',
      price: _parseDouble(json['price']),
      quantity: _parseDouble(json['quantity']),
      filledQuantity: _parseDouble(json['filledQuantity'] ?? json['filled_quantity']),
      status: json['status'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
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

  // 미체결 수량
  double get remainingQuantity => quantity - filledQuantity;
}

/// 주문 목록 상태
class OrderListState {
  final List<FuturesOrder> orders;
  final bool isLoading;
  final String? error;

  OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  OrderListState copyWith({
    List<FuturesOrder>? orders,
    bool? isLoading,
    String? error,
  }) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 주문 목록 Provider
class OrderListNotifier extends Notifier<OrderListState> {
  @override
  OrderListState build() {
    return OrderListState();
  }

  /// 주문 목록 조회
  Future<void> fetchOrders({String? symbol, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ServerAPI().getFuturesOrders(symbol: symbol, status: status);

      if (result != null && result['result'] == 0) {
        final List<dynamic> ordersJson = result['orders'] ?? [];
        final orders = ordersJson.map((e) => FuturesOrder.fromJson(e)).toList();
        state = state.copyWith(orders: orders, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result?['message'] ?? result?['error'] ?? '주문 조회 실패',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 주문 취소
  Future<bool> cancelOrder(int orderId) async {
    try {
      final result = await ServerAPI().cancelFuturesOrder(orderId);
      if (result != null && result['result'] == 0) {
        // 취소된 주문을 로컬 상태에서 즉시 제거
        state = state.copyWith(
          orders: state.orders.where((order) => order.id != orderId).toList(),
        );
        return true;
      }
    } catch (e) {
      print('Cancel order error: $e');
    }
    return false;
  }

  /// 주문 추가 (로컬)
  void addOrder(FuturesOrder order) {
    state = state.copyWith(orders: [order, ...state.orders]);
  }
}

final orderListProvider = NotifierProvider<OrderListNotifier, OrderListState>(() {
  return OrderListNotifier();
});

/// 주문 가격 상태를 관리하는 Provider
/// 오더북에서 클릭한 가격을 주문 패널로 전달
class OrderPriceNotifier extends Notifier<double?> {
  @override
  double? build() {
    return null;
  }

  /// 오더북에서 클릭한 가격 설정
  void setPrice(double price) {
    state = price;
  }

  /// 가격 초기화
  void clearPrice() {
    state = null;
  }
}

/// 주문 가격 Provider
final orderPriceProvider = NotifierProvider<OrderPriceNotifier, double?>(() {
  return OrderPriceNotifier();
});
