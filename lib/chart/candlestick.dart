import 'package:intl/intl.dart';

/// 캔들스틱(K라인) 데이터 모델 클래스
class Candlestick {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;
  final double quoteAssetVolume;
  final int numberOfTrades;
  final double takerBuyBaseAssetVolume;
  final double takerBuyQuoteAssetVolume;

  int get periodInMillis =>
      closeTime.millisecondsSinceEpoch - openTime.millisecondsSinceEpoch;
  Candlestick({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
    required this.quoteAssetVolume,
    required this.numberOfTrades,
    required this.takerBuyBaseAssetVolume,
    required this.takerBuyQuoteAssetVolume,
  });

  factory Candlestick.fromJson(List<dynamic> json) {
    return Candlestick(
      openTime: DateTime.fromMillisecondsSinceEpoch(_toInt(json[0])),
      open: double.parse(json[1].toString()),
      high: double.parse(json[2].toString()),
      low: double.parse(json[3].toString()),
      close: double.parse(json[4].toString()),
      volume: double.parse(json[5].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(_toInt(json[6])),
      quoteAssetVolume: double.parse(json[7].toString()),
      numberOfTrades: _toInt(json[8]),
      takerBuyBaseAssetVolume: double.parse(json[9].toString()),
      takerBuyQuoteAssetVolume: double.parse(json[10].toString()),
    );
  }

  /// 안전하게 int로 변환 (double이나 큰 숫자 처리)
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  String toString() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return '시간: ${dateFormat.format(openTime)}, 시가: $open, 고가: $high, 저가: $low, 종가: $close, 거래량: $volume';
  }
}

class CandlestickEx extends Candlestick {
  final double x; // X 좌표 (차트 인덱스)
  final DateTime date;

  CandlestickEx({
    required this.x,
    required this.date,
    required double open,
    required double high,
    required double low,
    required double close,
    required DateTime closeTime,
    double volume = 0,
  }) : super(
          openTime: date,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          closeTime: closeTime,
          quoteAssetVolume: 0,
          numberOfTrades: 0,
          takerBuyBaseAssetVolume: 0,
          takerBuyQuoteAssetVolume: 0,
        );

  // 바이낸스 API 응답에서 생성
  factory CandlestickEx.fromBinanceData(List<dynamic> kline, int index) {
    return CandlestickEx(
      x: index.toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(Candlestick._toInt(kline[0])),
      closeTime: DateTime.fromMillisecondsSinceEpoch(Candlestick._toInt(kline[6])),
      open: double.parse(kline[1].toString()),
      high: double.parse(kline[2].toString()),
      low: double.parse(kline[3].toString()),
      close: double.parse(kline[4].toString()),
      volume: double.parse(kline[5].toString()),
    );
  }
}

/// 개별 거래 Tick 데이터 모델
class TickData {
  final int id;
  final double price;
  final double qty;
  final double quoteQty;
  final DateTime time;
  final bool isBuyerMaker;

  TickData({
    required this.id,
    required this.price,
    required this.qty,
    required this.quoteQty,
    required this.time,
    required this.isBuyerMaker,
  });

  factory TickData.fromJson(Map<String, dynamic> json) {
    return TickData(
      id: json['id'],
      price: double.parse(json['price']),
      qty: double.parse(json['qty']),
      quoteQty: double.parse(json['quoteQty']),
      time: DateTime.fromMillisecondsSinceEpoch(json['time']),
      isBuyerMaker: json['isBuyerMaker'],
    );
  }

  @override
  String toString() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    return '시간: ${dateFormat.format(time)}, 가격: $price, 수량: $qty, 매수자 주문: ${!isBuyerMaker ? "매수" : "매도"}';
  }
}

/// 집계된 거래 Tick 데이터 모델
class AggregatedTickData {
  final int aggregateTradeId;
  final double price;
  final double quantity;
  final int firstTradeId;
  final int lastTradeId;
  final DateTime timestamp;
  final bool isBuyerMaker;

  AggregatedTickData({
    required this.aggregateTradeId,
    required this.price,
    required this.quantity,
    required this.firstTradeId,
    required this.lastTradeId,
    required this.timestamp,
    required this.isBuyerMaker,
  });

  factory AggregatedTickData.fromJson(Map<String, dynamic> json) {
    return AggregatedTickData(
      aggregateTradeId: json['a'],
      price: double.parse(json['p']),
      quantity: double.parse(json['q']),
      firstTradeId: json['f'],
      lastTradeId: json['l'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['T']),
      isBuyerMaker: json['m'],
    );
  }

  @override
  String toString() {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    return '시간: ${dateFormat.format(timestamp)}, 가격: $price, 수량: $quantity, 거래 ID: $aggregateTradeId';
  }
}

/// 호가창 데이터 모델
class OrderBookData {
  final int lastUpdateId;
  final List<OrderBookEntry> bids;
  final List<OrderBookEntry> asks;

  OrderBookData({
    required this.lastUpdateId,
    required this.bids,
    required this.asks,
  });

  factory OrderBookData.fromJson(Map<String, dynamic> json) {
    return OrderBookData(
      lastUpdateId: json['lastUpdateId'],
      bids: (json['bids'] as List)
          .map((bid) => OrderBookEntry.fromJson(bid))
          .toList(),
      asks: (json['asks'] as List)
          .map((ask) => OrderBookEntry.fromJson(ask))
          .toList(),
    );
  }
}

/// 호가창 개별 항목 모델
class OrderBookEntry {
  final double price;
  final double quantity;

  OrderBookEntry({
    required this.price,
    required this.quantity,
  });

  factory OrderBookEntry.fromJson(List<dynamic> json) {
    return OrderBookEntry(
      price: double.parse(json[0]),
      quantity: double.parse(json[1]),
    );
  }

  @override
  String toString() {
    return '가격: $price, 수량: $quantity';
  }
}
