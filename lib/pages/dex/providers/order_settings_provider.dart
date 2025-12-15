import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _orderSettingsStorageKey = 'dex_order_settings';

/// 주문 타입
enum OrderType {
  market('MARKET', '시장가'),
  limit('LIMIT', '지정가');

  final String value;
  final String label;
  const OrderType(this.value, this.label);

  static OrderType fromString(String? value) {
    if (value == 'LIMIT') return OrderType.limit;
    return OrderType.market; // 기본값
  }
}

/// 심볼별 주문 설정 (로컬 저장)
class SymbolOrderSettings {
  final String symbol;
  final OrderType orderType;
  final String? lastQuantity;
  final bool tpSlEnabled;
  final String? takeProfitPrice;
  final String? stopLossPrice;

  SymbolOrderSettings({
    required this.symbol,
    this.orderType = OrderType.market,
    this.lastQuantity,
    this.tpSlEnabled = false,
    this.takeProfitPrice,
    this.stopLossPrice,
  });

  factory SymbolOrderSettings.fromJson(String symbol, Map<String, dynamic> json) {
    return SymbolOrderSettings(
      symbol: symbol,
      orderType: OrderType.fromString(json['orderType']),
      lastQuantity: json['lastQuantity'],
      tpSlEnabled: json['tpSlEnabled'] ?? false,
      takeProfitPrice: json['takeProfitPrice'],
      stopLossPrice: json['stopLossPrice'],
    );
  }

  Map<String, dynamic> toJson() => {
    'orderType': orderType.value,
    'lastQuantity': lastQuantity,
    'tpSlEnabled': tpSlEnabled,
    'takeProfitPrice': takeProfitPrice,
    'stopLossPrice': stopLossPrice,
  };

  SymbolOrderSettings copyWith({
    OrderType? orderType,
    String? lastQuantity,
    bool? tpSlEnabled,
    String? takeProfitPrice,
    String? stopLossPrice,
  }) {
    return SymbolOrderSettings(
      symbol: symbol,
      orderType: orderType ?? this.orderType,
      lastQuantity: lastQuantity ?? this.lastQuantity,
      tpSlEnabled: tpSlEnabled ?? this.tpSlEnabled,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
    );
  }
}

/// 주문 설정 Provider (로컬 저장소)
class OrderSettingsNotifier extends Notifier<Map<String, SymbolOrderSettings>> {
  @override
  Map<String, SymbolOrderSettings> build() {
    _loadFromStorage();
    return {};
  }

  /// 저장소에서 설정 로드
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_orderSettingsStorageKey);
      if (data != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        final Map<String, SymbolOrderSettings> settingsMap = {};
        jsonMap.forEach((symbol, value) {
          settingsMap[symbol] = SymbolOrderSettings.fromJson(
            symbol,
            value as Map<String, dynamic>,
          );
        });
        state = settingsMap;
        print('[OrderSettings] Loaded ${settingsMap.length} symbol settings');
      }
    } catch (e) {
      print('[OrderSettings] Error loading from storage: $e');
    }
  }

  /// 저장소에 설정 저장
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> jsonMap = {};
      state.forEach((symbol, settings) {
        jsonMap[symbol] = settings.toJson();
      });
      await prefs.setString(_orderSettingsStorageKey, jsonEncode(jsonMap));
    } catch (e) {
      print('[OrderSettings] Error saving to storage: $e');
    }
  }

  /// 심볼의 설정 가져오기 (없으면 기본값)
  SymbolOrderSettings getSettings(String symbol) {
    return state[symbol] ?? SymbolOrderSettings(symbol: symbol);
  }

  /// 주문 타입 설정
  void setOrderType(String symbol, OrderType orderType) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(orderType: orderType),
    };
    _saveToStorage();
  }

  /// 마지막 주문 수량 저장
  void setLastQuantity(String symbol, String quantity) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(lastQuantity: quantity),
    };
    _saveToStorage();
  }

  /// TP/SL 설정 활성화/비활성화
  void setTpSlEnabled(String symbol, bool enabled) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(tpSlEnabled: enabled),
    };
    _saveToStorage();
  }

  /// TP 가격 설정
  void setTakeProfitPrice(String symbol, String? price) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(takeProfitPrice: price),
    };
    _saveToStorage();
  }

  /// SL 가격 설정
  void setStopLossPrice(String symbol, String? price) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(stopLossPrice: price),
    };
    _saveToStorage();
  }

  /// 전체 TP/SL 설정 한번에 업데이트
  void updateTpSlSettings(
    String symbol, {
    bool? enabled,
    String? takeProfitPrice,
    String? stopLossPrice,
  }) {
    final settings = getSettings(symbol);
    state = {
      ...state,
      symbol: settings.copyWith(
        tpSlEnabled: enabled,
        takeProfitPrice: takeProfitPrice,
        stopLossPrice: stopLossPrice,
      ),
    };
    _saveToStorage();
  }
}

final orderSettingsProvider =
    NotifierProvider<OrderSettingsNotifier, Map<String, SymbolOrderSettings>>(() {
  return OrderSettingsNotifier();
});
