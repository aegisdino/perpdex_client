import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '/common/util.dart';
import '/data/data.dart';
import '/data/providers.dart';
import '/api/netclient.dart';
import 'candlestick.dart';

class MACDData {
  final double macdLine;
  final double signalLine;
  final double histogram;
  final bool bullishCross;
  final bool bearishCross;

  MACDData({
    required this.macdLine,
    required this.signalLine,
    required this.histogram,
    required this.bullishCross,
    required this.bearishCross,
  });
}

class BollingerData {
  final double upper;
  final double middle;
  final double lower;
  final double width;
  final bool breakoutUp;
  final bool breakoutDown;

  BollingerData({
    required this.upper,
    required this.middle,
    required this.lower,
    required this.width,
    required this.breakoutUp,
    required this.breakoutDown,
  });
}

class IndicatorData {
  final DateTime date;
  final int timestamp;

  // SMA 데이터
  final double? sma20, sma50;

  // EMA 데이터
  final double? ema12, ema26;
  final double? ema20, ema50;

  // RSI 데이터
  final double? rsiValue;
  final bool rsiOverbought, rsiOversold;

  // MACD 데이터
  final double? macdLine, macdSignal, macdHistogram;
  final bool macdBullishCross, macdBearishCross;

  // 볼린저 밴드
  final double? bbUpper, bbMiddle, bbLower, bbWidth;
  final bool bbBreakoutUp, bbBreakoutDown;

  // ATR 데이터
  final double? atrValue, atrVolatilityPercent;
  final bool atrHighVolatility;
  final double? atrSupport, atrResistance;

  // Momentum score
  final double? momentumScore;

  // Divergence
  final String? divergence_signal;
  final double? divergence_confidence;
  final double? divergence_strength;

  // Stochastic RSI
  final double? stochRsi;

  // Williams R
  final double? williamsR;

  // Hma
  final double? hma;

  //
  final bool? isOscillating;
  final bool? isWhipsaw;
  final bool? isChoppy;
  final bool? isBBTunnel;
  final String? bbReversal;
  final String? ema20Crossover;

  String get bbReversalColored => bbReversal == 'buy'
      ? '<green>$bbReversal</green>'
      : bbReversal == 'sell'
          ? '<red>$bbReversal</red>'
          : '${bbReversal}';

  bool get isMomentumUp => (momentumScore ?? 0) > 0.6;
  bool get isMomentumDown => (momentumScore ?? 0) < 0.42;

  bool get isMacdUp => (macdHistogram ?? 0) > 0;

  bool get isRsiUp => (rsiValue ?? 0) > 80;
  bool get isRsiDown => (rsiValue ?? 100) < 20;

  bool get isEmaUp => (ema12 ?? 0) > (ema26 ?? 0);
  bool get isEmaDown => (ema12 ?? 0) < (ema26 ?? 0);

  IndicatorData({
    required this.date,
    required this.timestamp,
    this.sma20,
    this.sma50,
    this.ema12,
    this.ema26,
    this.ema20,
    this.ema50,
    this.rsiValue,
    this.rsiOverbought = false,
    this.rsiOversold = false,
    this.macdLine,
    this.macdSignal,
    this.macdHistogram,
    this.macdBullishCross = false,
    this.macdBearishCross = false,
    this.bbUpper,
    this.bbMiddle,
    this.bbLower,
    this.bbWidth,
    this.bbBreakoutUp = false,
    this.bbBreakoutDown = false,
    this.atrValue,
    this.atrVolatilityPercent,
    this.atrHighVolatility = false,
    this.atrSupport,
    this.atrResistance,
    this.momentumScore,
    this.divergence_signal,
    this.divergence_confidence,
    this.divergence_strength,
    this.stochRsi,
    this.williamsR,
    this.hma,
    this.isOscillating,
    this.isWhipsaw,
    this.isBBTunnel,
    this.isChoppy,
    this.bbReversal,
    this.ema20Crossover,
  });

  factory IndicatorData.fromJson(Map<String, dynamic> json) {
    return IndicatorData(
      date: DateTime.parse(json['date']).toLocal(),
      timestamp: json['timestamp'],
      sma20: json['sma20']?.toDouble(),
      sma50: json['sma50']?.toDouble(),
      ema12: json['ema12']?.toDouble(),
      ema26: json['ema26']?.toDouble(),
      ema20: json['ema20']?.toDouble(),
      ema50: json['ema50']?.toDouble(),
      rsiValue: json['rsi_value']?.toDouble(),
      rsiOverbought: json['rsi_overbought'] ?? false,
      rsiOversold: json['rsi_oversold'] ?? false,
      macdLine: json['macd_line']?.toDouble(),
      macdSignal: json['macd_signal']?.toDouble(),
      macdHistogram: json['macd_histogram']?.toDouble(),
      macdBullishCross: json['macd_bullish_cross'] ?? false,
      macdBearishCross: json['macd_bearish_cross'] ?? false,
      bbUpper: json['bb_upper']?.toDouble(),
      bbMiddle: json['bb_middle']?.toDouble(),
      bbLower: json['bb_lower']?.toDouble(),
      bbWidth: json['bb_width']?.toDouble(),
      bbBreakoutUp: json['bb_breakout_up'] ?? false,
      bbBreakoutDown: json['bb_breakout_down'] ?? false,
      atrValue: json['atr_value']?.toDouble(),
      atrVolatilityPercent: json['atr_volatility_percent']?.toDouble(),
      atrHighVolatility: json['atr_high_volatility'] ?? false,
      atrSupport: json['atr_support']?.toDouble(),
      atrResistance: json['atr_resistance']?.toDouble(),
      momentumScore: json['momentumScore']?.toDouble(),
      stochRsi: json['stoch_rsi']?.toDouble(),
    );
  }

  factory IndicatorData.fromBacktestJson(
      int closeTime, Map<String, dynamic> json, Map<String, dynamic> summary) {
    return IndicatorData(
      date:
          DateTime.fromMillisecondsSinceEpoch(isUtc: true, parseInt(closeTime)),
      timestamp: parseInt(closeTime),
      sma20: parseDouble(json['sma20']?['value']),
      sma50: parseDouble(json['sma50']?['value']),
      ema12: parseDouble(json['ema12']?['value']),
      ema26: parseDouble(json['ema26']?['value']),
      ema20: parseDouble(json['ema20']?['value']),
      ema50: parseDouble(json['ema50']?['value']),
      rsiValue: parseDouble(json['rsi']?['value']),
      rsiOverbought: json['rsi']?['overbought'] ?? false,
      rsiOversold: json['rsi']?['oversold'] ?? false,
      macdLine: parseDouble(json['macd']?['macd']),
      macdSignal: parseDouble(json['macd']?['signal']),
      macdBullishCross: json['macd']?['bullish_cross'] ?? false,
      macdBearishCross: json['macd']?['bearish_cross'] ?? false,
      bbUpper: parseDouble(json['bollinger']?['upper']),
      bbMiddle: parseDouble(json['bollinger']?['middle']),
      bbLower: parseDouble(json['bollinger']?['lower']),
      bbWidth: parseDouble(json['bollinger']?['width']),
      bbBreakoutUp: json['bollinger']?['breakout_up'] ?? false,
      bbBreakoutDown: json['bollinger']?['breakout_down'] ?? false,
      atrValue: parseDouble(json['atr']?['value']),
      atrVolatilityPercent: parseDouble(json['atr']?['volatility_percent']),
      atrHighVolatility: json['atr']?['high_volatility'] ?? false,
      atrSupport: parseDouble(json['atr']?['support']),
      atrResistance: parseDouble(json['atr']?['resistance']),
      momentumScore: parseDouble(json['momentumScore']),
      divergence_signal: summary['divergence']['signal'],
      divergence_confidence: parseDouble(summary['divergence']['confidence']),
      divergence_strength: parseDouble(summary['divergence']['strength']),
      stochRsi: parseDouble(json['stochRsi']?['value']),
      williamsR: parseDouble(json['williamsR']?['value']),
      hma: parseDouble(json['hma']?['value']),
      isOscillating: summary['isOscillating'],
      isWhipsaw: summary['isWhipsaw'],
      isBBTunnel: summary['isBBTunnel'],
      isChoppy: summary['isChop'],
      bbReversal: summary['bbReversal'],
      ema20Crossover: summary['emaCrossover'],
    );
  }
}

class IndicatorStyle {
  final Color color;
  final double width;
  final List<double>? dashArray;
  final String description;

  const IndicatorStyle({
    required this.color,
    this.width = 1.5,
    this.dashArray,
    this.description = '',
  });
}

class IndicatorDataManager {
  static final IndicatorDataManager _instance =
      IndicatorDataManager._internal();
  factory IndicatorDataManager() => _instance;
  IndicatorDataManager._internal();

  Map<String, List<IndicatorData>> _cache = {};
  Map<String, bool> _hasMore = {};

  static const Map<String, IndicatorStyle> indicatorStyles = {
    'Volume': IndicatorStyle(
      color: Colors.blue,
      width: 1.0,
      description: 'Trading Volume',
    ),
    'SMA20': IndicatorStyle(
      color: Colors.orange,
      width: 1.5,
      description: 'Simple Moving Average (20)',
    ),
    'SMA50': IndicatorStyle(
      color: Colors.purple,
      width: 1.5,
      description: 'Simple Moving Average (50)',
    ),
    'EMA12': IndicatorStyle(
      color: Colors.cyan,
      width: 1.5,
      dashArray: [3, 3],
      description: 'Exponential Moving Average (12)',
    ),
    'EMA26': IndicatorStyle(
      color: Colors.pink,
      width: 1.5,
      dashArray: [3, 3],
      description: 'Exponential Moving Average (26)',
    ),
    'EMA20': IndicatorStyle(
      color: Color.fromARGB(255, 13, 108, 120),
      width: 2,
      dashArray: [5, 10],
      description: 'Exponential Moving Average (20)',
    ),
    'EMA50': IndicatorStyle(
      color: Color.fromARGB(255, 198, 76, 116),
      width: 2,
      dashArray: [5, 10],
      description: 'Exponential Moving Average (50)',
    ),
    'BB U': IndicatorStyle(
      color: Color.fromARGB(255, 198, 182, 1),
      width: 2.0,
      description: 'Bollinger Band Upper',
    ),
    'BB M': IndicatorStyle(
      color: Color.fromARGB(255, 198, 182, 1),
      width: 2.0,
      dashArray: [2, 2],
      description: 'Bollinger Band Middle',
    ),
    'BB L': IndicatorStyle(
      color: Color.fromARGB(255, 198, 182, 1),
      width: 2.0,
      description: 'Bollinger Band Lower',
    ),
    'ATR S': IndicatorStyle(
      color: Colors.green,
      width: 1.0,
      dashArray: [5, 5],
      description: 'ATR Support',
    ),
    'ATR R': IndicatorStyle(
      color: Colors.red,
      width: 1.0,
      dashArray: [5, 5],
      description: 'ATR Resistance',
    ),
    'MACD': IndicatorStyle(
      color: Colors.white,
      width: 1.0,
      description: 'MACD Indicator',
    ),
    'Momentum': IndicatorStyle(
      color: Colors.greenAccent,
      width: 1.0,
      dashArray: [5, 5],
      description: 'Momentum Score',
    ),
    'StochRsi': IndicatorStyle(
      color: Colors.yellow,
      width: 1.0,
      dashArray: [5, 5],
      description: 'Stochastic RSI',
    ),
    'WilliamsR': IndicatorStyle(
      color: Colors.deepOrange,
      width: 1.0,
      description: 'Williams %R',
    ),
    'HMA': IndicatorStyle(
      color: Colors.indigo,
      width: 2.0,
      dashArray: [3, 7],
      description: 'Hull Moving Average',
    ),
    'Heatmap': IndicatorStyle(
      color: Colors.blueGrey,
      width: 1.0,
      description: 'Price Heatmap',
    ),
  };

  final indicatorUpdateTimeProvider = StateProvider<DateTime?>((ref) => null);

  void setUpdated() {
    uncontrolledContainer.read(indicatorUpdateTimeProvider.notifier).state =
        DateTime.now();
  }

  // 서버에서 초기 인디케이터 데이터 로드
  Future<List<IndicatorData>> loadInitialData(
    String symbol,
    String timeframe, {
    int limit = 200,
  }) async {
    // TODO: 나중에 구현해라.
    return [];

    final cacheKey = '${symbol}_${timeframe}';

    try {
      final result = await ServerAPI().loadIndicatorData({
        'symbol': symbol,
        'timeframe': timeframe,
        'limit': limit,
      });

      if (result != null && result['data'] != null) {
        final data = result['data'];
        final List<dynamic> indicatorList = data['indicators'] ?? [];

        final indicators =
            indicatorList.map((item) => IndicatorData.fromJson(item)).toList();

        _cache[cacheKey] = indicators;
        _hasMore[cacheKey] = data['hasMore'] ?? false;

        setUpdated();

        print(
            '✅ Loaded ${indicators.length} indicators, hasMore: ${_hasMore[cacheKey]}');
        return indicators;
      }

      return [];
    } catch (e) {
      print('Error loading initial indicator data: $e');
      return [];
    }
  }

  // 과거 데이터 추가 로드 (페이징)
  Future<List<IndicatorData>> loadMoreData(String symbol, String timeframe,
      {int limit = 100}) async {
    final cacheKey = '${symbol}_${timeframe}';
    final existingData = _cache[cacheKey] ?? [];

    if (existingData.isEmpty) {
      return loadInitialData(symbol, timeframe, limit: limit);
    }

    // 기존 데이터의 가장 오래된 시간을 lasttime으로 사용
    final oldestTime = existingData.first.timestamp;

    try {
      final result = await ServerAPI().loadIndicatorData({
        'symbol': symbol,
        'timeframe': timeframe,
        'limit': limit,
        'lasttime': oldestTime,
      });

      if (result != null && result['data'] != null) {
        final data = result['data'];
        final List<dynamic> indicatorList = data['indicators'] ?? [];

        final newIndicators =
            indicatorList.map((item) => IndicatorData.fromJson(item)).toList();

        // 기존 데이터 앞쪽에 새 데이터 추가
        _cache[cacheKey] = [...newIndicators, ...existingData];
        _hasMore[cacheKey] = data['hasMore'] ?? false;

        setUpdated();

        print(
            '✅ Loaded ${newIndicators.length} more indicators, total: ${_cache[cacheKey]!.length}');
        return _cache[cacheKey]!;
      }

      return existingData;
    } catch (e) {
      print('Error loading more indicator data: $e');
      return existingData;
    }
  }

  // 더 로드할 데이터가 있는지 확인
  bool hasMoreData(String symbol, String timeframe) {
    final cacheKey = '${symbol}_${timeframe}';
    return _hasMore[cacheKey] ?? false;
  }

  // 캐시된 데이터 가져오기
  List<IndicatorData> getCachedData(String symbol, String timeframe) {
    final cacheKey = '${symbol}_${timeframe}';
    return _cache[cacheKey] ?? [];
  }

  void setCachedData(String symbol, String timeframe,
      List<IndicatorData> indicators, bool hasMore) {
    final cacheKey = '${symbol}_${timeframe}';
    _cache[cacheKey] = indicators;
    _hasMore[cacheKey] = hasMore;
  }

  //////////////////////////////////////////////////////////////////////////////
  // 클라이언트에서 인디케이터 데이터 계산 //
  //////////////////////////////////////////////////////////////////////////////
  List<CandlestickEx> getRecentCandles(
      List<CandlestickEx> allCandles, DateTime targetTime, int count) {
    // targetTime 이전의 캔들들을 최대 count개 반환
    final targetTimestamp = targetTime.millisecondsSinceEpoch;

    final beforeCandles = allCandles
        .where(
            (candle) => candle.date.millisecondsSinceEpoch <= targetTimestamp)
        .toList();

    if (beforeCandles.isEmpty) return [];

    // 시간순 정렬 후 최근 count개 반환
    beforeCandles.sort((a, b) => a.date.compareTo(b.date));

    final startIndex =
        beforeCandles.length > count ? beforeCandles.length - count : 0;

    return beforeCandles.sublist(startIndex);
  }

  List<IndicatorData>? calculateRealtime(String symbol, String timeframe,
      List<CandlestickEx> newCandles, List<CandlestickEx> allCandles) {
    if (newCandles.isEmpty) return null;

    var indicators = getCachedData(symbol, timeframe);

    // 마지막에 시간이 겹치는 것들을 삭제해줌
    while (indicators.length > 1 &&
        indicators.last.date.millisecondsSinceEpoch >=
            newCandles.first.date.millisecondsSinceEpoch) {
      indicators.removeLast();
    }

    List<IndicatorData> newValues = [];
    for (var newCandle in newCandles) {
      final recentCandles = getRecentCandles(allCandles, newCandle.date, 100);

      if (recentCandles.length < 50) return null;

      final closes = recentCandles.map((c) => c.close).toList();

      // 모든 인디케이터 계산
      final sma20 = _calculateSMA(closes, 20);
      final ema12 = _calculateEMA(closes, 12);
      final ema26 = _calculateEMA(closes, 26);
      final ema20 = _calculateEMA(closes, 20);
      final ema50 = _calculateEMA(closes, 50);
      final rsi = _calculateRSI(closes, 14);
      final sma50 = _calculateSMA(closes, 50);

      // MACD 계산 추가
      final macdData = _calculateMACD(closes, 12, 26, 9);

      // 볼린저 밴드 계산 추가
      final bollingerData = _calculateBollingerBands(closes, 20, 2.0);

      // ATR 계산
      final atr = _calculateATR(recentCandles, 14);

      newValues.add(IndicatorData(
        date: newCandle.date,
        timestamp: newCandle.date.millisecondsSinceEpoch,
        sma20: sma20,
        sma50: sma50,
        ema12: ema12,
        ema26: ema26,
        ema20: ema20,
        ema50: ema50,
        rsiValue: rsi,
        rsiOverbought: rsi != null && rsi > 70,
        rsiOversold: rsi != null && rsi < 30,

        // MACD 데이터
        macdLine: macdData?.macdLine,
        macdSignal: macdData?.signalLine,
        macdHistogram: macdData?.histogram,
        macdBullishCross: macdData?.bullishCross ?? false,
        macdBearishCross: macdData?.bearishCross ?? false,

        // 볼린저 밴드
        bbUpper: bollingerData?.upper,
        bbMiddle: bollingerData?.middle,
        bbLower: bollingerData?.lower,
        bbWidth: bollingerData?.width,
        bbBreakoutUp: bollingerData?.breakoutUp ?? false,
        bbBreakoutDown: bollingerData?.breakoutDown ?? false,

        // ATR
        atrValue: atr,
        atrVolatilityPercent:
            atr != null ? (atr / newCandle.close) * 100 : null,
        atrHighVolatility: atr != null ? (atr / newCandle.close) > 0.03 : false,
        atrSupport: atr != null ? newCandle.close - atr : null,
        atrResistance: atr != null ? newCandle.close + atr : null,
      ));

      indicators.add(newValues.last);
    }
    return newValues;
  }

  // MACD 계산 메서드 추가
  MACDData? _calculateMACD(
      List<double> prices, int fastPeriod, int slowPeriod, int signalPeriod) {
    if (prices.length < slowPeriod + signalPeriod) return null;

    final emaFast = _calculateEMA(prices, fastPeriod);
    final emaSlow = _calculateEMA(prices, slowPeriod);

    if (emaFast == null || emaSlow == null) return null;

    final macdLine = emaFast - emaSlow;

    // Signal line 계산 (MACD의 EMA)
    final macdHistory = <double>[macdLine]; // 실제로는 더 많은 히스토리 필요
    final signalLine = _calculateEMA(macdHistory, signalPeriod) ?? macdLine;

    final histogram = macdLine - signalLine;

    return MACDData(
      macdLine: macdLine,
      signalLine: signalLine,
      histogram: histogram,
      bullishCross: false, // 이전 값과 비교 필요
      bearishCross: false, // 이전 값과 비교 필요
    );
  }

  // 볼린저 밴드 계산 메서드 추가
  BollingerData? _calculateBollingerBands(
      List<double> prices, int period, double multiplier) {
    if (prices.length < period) return null;

    final sma = _calculateSMA(prices, period);
    if (sma == null) return null;

    final recentPrices = prices.skip(prices.length - period).toList();
    final variance = recentPrices
            .map((price) => math.pow(price - sma, 2))
            .reduce((a, b) => a + b) /
        period;
    final stdDev = math.sqrt(variance);

    final upper = sma + (stdDev * multiplier);
    final lower = sma - (stdDev * multiplier);
    final currentPrice = prices.last;

    return BollingerData(
      upper: upper,
      middle: sma,
      lower: lower,
      width: (upper - lower) / sma,
      breakoutUp: currentPrice > upper,
      breakoutDown: currentPrice < lower,
    );
  }

  // 기존 계산 메서드들은 그대로 유지
  double? _calculateSMA(List<double> prices, int period) {
    if (prices.length < period) return null;
    final recentPrices = prices.skip(prices.length - period);
    return recentPrices.reduce((a, b) => a + b) / period;
  }

  double? _calculateEMA(List<double> prices, int period) {
    if (prices.length < period) return null;

    final multiplier = 2.0 / (period + 1);
    double ema = _calculateSMA(prices.take(period).toList(), period) ?? 0;

    for (int i = period; i < prices.length; i++) {
      ema = (prices[i] - ema) * multiplier + ema;
    }

    return ema;
  }

  double? _calculateRSI(List<double> prices, int period) {
    if (prices.length < period + 1) return null;

    List<double> gains = [];
    List<double> losses = [];

    for (int i = 1; i < prices.length; i++) {
      final change = prices[i] - prices[i - 1];
      gains.add(change > 0 ? change : 0);
      losses.add(change < 0 ? -change : 0);
    }

    if (gains.length < period) return null;

    final avgGain =
        gains.skip(gains.length - period).reduce((a, b) => a + b) / period;
    final avgLoss =
        losses.skip(losses.length - period).reduce((a, b) => a + b) / period;

    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  double? _calculateATR(List<CandlestickEx> candles, int period) {
    if (candles.length < period + 1) return null;

    List<double> trueRanges = [];

    for (int i = 1; i < candles.length; i++) {
      final current = candles[i];
      final previous = candles[i - 1];

      final tr1 = current.high - current.low;
      final tr2 = (current.high - previous.close).abs();
      final tr3 = (current.low - previous.close).abs();

      trueRanges.add([tr1, tr2, tr3].reduce((a, b) => a > b ? a : b));
    }

    if (trueRanges.length < period) return null;

    final recentTR = trueRanges.skip(trueRanges.length - period);
    return recentTR.reduce((a, b) => a + b) / period;
  }

  bool isVisibleIndicator(String v) =>
      DataManager().selectedIndicators.contains(v);

  List<CartesianSeries> buildIndicatorSeries(
      List<IndicatorData> indicatorData) {
    return [
      // SMA 라인들
      if (isVisibleIndicator('SMA20'))
        LineSeries<IndicatorData, DateTime>(
          name: 'SMA20',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.sma20 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.sma20,
          color: indicatorStyles['SMA20']!.color,
          width: indicatorStyles['SMA20']!.width,
          dashArray: indicatorStyles['SMA20']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('SMA50'))
        LineSeries<IndicatorData, DateTime>(
          name: 'SMA50',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.sma50 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.sma50,
          color: indicatorStyles['SMA50']!.color,
          width: indicatorStyles['SMA50']!.width,
          dashArray: indicatorStyles['SMA50']!.dashArray,
          animationDuration: 0,
        ),

      // EMA 라인들
      if (isVisibleIndicator('EMA12'))
        LineSeries<IndicatorData, DateTime>(
          name: 'EMA12',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.ema12 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.ema12,
          color: indicatorStyles['EMA12']!.color,
          width: indicatorStyles['EMA12']!.width,
          dashArray: indicatorStyles['EMA12']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('EMA26'))
        LineSeries<IndicatorData, DateTime>(
          name: 'EMA26',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.ema26 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.ema26,
          color: indicatorStyles['EMA26']!.color,
          width: indicatorStyles['EMA26']!.width,
          dashArray: indicatorStyles['EMA26']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('EMA20'))
        LineSeries<IndicatorData, DateTime>(
          name: 'EMA20',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.ema20 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.ema20,
          color: indicatorStyles['EMA20']!.color,
          width: indicatorStyles['EMA20']!.width,
          dashArray: indicatorStyles['EMA20']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('EMA50'))
        LineSeries<IndicatorData, DateTime>(
          name: 'EMA50',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.ema50 != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.ema50,
          color: indicatorStyles['EMA50']!.color,
          width: indicatorStyles['EMA50']!.width,
          dashArray: indicatorStyles['EMA50']!.dashArray,
          animationDuration: 0,
        ),
      // 볼린저 밴드
      if (isVisibleIndicator('BB U'))
        LineSeries<IndicatorData, DateTime>(
          name: 'BB U',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.bbUpper != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.bbUpper,
          color: indicatorStyles['BB U']!.color.withValues(alpha: 0.6),
          width: indicatorStyles['BB U']!.width,
          dashArray: indicatorStyles['BB U']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('BB M'))
        LineSeries<IndicatorData, DateTime>(
          name: 'BB M',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.bbMiddle != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.bbMiddle,
          color: indicatorStyles['BB M']!.color.withValues(alpha: 0.4),
          width: indicatorStyles['BB M']!.width,
          dashArray: indicatorStyles['BB M']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('BB L'))
        LineSeries<IndicatorData, DateTime>(
          name: 'BB L',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.bbLower != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.bbLower,
          color: indicatorStyles['BB L']!.color.withValues(alpha: 0.6),
          width: indicatorStyles['BB L']!.width,
          dashArray: indicatorStyles['BB L']!.dashArray,
          animationDuration: 0,
        ),

      // ATR 지지/저항선 (옵션)
      if (isVisibleIndicator('ATR S'))
        LineSeries<IndicatorData, DateTime>(
          name: 'ATR S',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.atrSupport != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.atrSupport,
          color: indicatorStyles['ATR S']!.color.withValues(alpha: 0.5),
          width: indicatorStyles['ATR S']!.width,
          dashArray: indicatorStyles['ATR S']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('ATR S'))
        LineSeries<IndicatorData, DateTime>(
          name: 'ATR S',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource:
              indicatorData.where((d) => d.atrResistance != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.atrResistance,
          color: indicatorStyles['ATR S']!.color.withValues(alpha: 0.5),
          width: indicatorStyles['ATR S']!.width,
          dashArray: indicatorStyles['ATR S']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('MACD')) ...getMacdSeries(indicatorData),

      if (isVisibleIndicator('Momentum'))
        LineSeries<IndicatorData, DateTime>(
          name: 'Momentum',
          xAxisName: 'xAxis',
          yAxisName: 'momentumAxis',
          dataSource:
              indicatorData.where((d) => d.momentumScore != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.momentumScore,
          color: indicatorStyles['Momentum']!.color.withValues(alpha: 0.5),
          width: indicatorStyles['Momentum']!.width,
          dashArray: indicatorStyles['Momentum']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('StochRsi'))
        LineSeries<IndicatorData, DateTime>(
          name: 'StochRsi',
          xAxisName: 'xAxis',
          yAxisName: 'stochRsiAxis',
          dataSource: indicatorData.where((d) => d.stochRsi != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.stochRsi,
          color: indicatorStyles['StochRsi']!.color.withValues(alpha: 0.5),
          width: indicatorStyles['StochRsi']!.width,
          dashArray: indicatorStyles['StochRsi']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('WilliamsR'))
        LineSeries<IndicatorData, DateTime>(
          name: 'WilliamsR',
          xAxisName: 'xAxis',
          yAxisName: 'williamsRAxis',
          dataSource: indicatorData.where((d) => d.williamsR != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.williamsR,
          color: indicatorStyles['WilliamsR']!.color.withValues(alpha: 0.5),
          width: indicatorStyles['WilliamsR']!.width,
          dashArray: indicatorStyles['WilliamsR']!.dashArray,
          animationDuration: 0,
        ),
      if (isVisibleIndicator('HMA'))
        LineSeries<IndicatorData, DateTime>(
          name: 'HMA',
          xAxisName: 'xAxis',
          yAxisName: 'rightAxis',
          dataSource: indicatorData.where((d) => d.hma != null).toList(),
          xValueMapper: (IndicatorData data, _) => data.date,
          yValueMapper: (IndicatorData data, _) => data.hma,
          color: indicatorStyles['HMA']!.color,
          width: indicatorStyles['HMA']!.width,
          dashArray: indicatorStyles['HMA']!.dashArray,
          animationDuration: 0,
        ),
    ];
  }

  List<LineSeries<IndicatorData, DateTime>> getMacdSeries(
      List<IndicatorData> indicatorData) {
    return [
      LineSeries<IndicatorData, DateTime>(
        name: 'MACD',
        xAxisName: 'xAxis',
        yAxisName: 'macdAxis',
        dataSource: indicatorData.where((d) => d.macdLine != null).toList(),
        xValueMapper: (IndicatorData data, _) => data.date,
        yValueMapper: (IndicatorData data, _) => data.macdLine ?? 0,
        color: indicatorStyles['MACD']!.color.withValues(alpha: 0.5),
        width: indicatorStyles['MACD']!.width,
        dashArray: indicatorStyles['MACD']!.dashArray,
        animationDuration: 0,
      ),
      LineSeries<IndicatorData, DateTime>(
        name: 'MACD Signal',
        xAxisName: 'xAxis',
        yAxisName: 'macdAxis',
        dataSource: indicatorData.where((d) => d.macdSignal != null).toList(),
        xValueMapper: (IndicatorData data, _) => data.date,
        yValueMapper: (IndicatorData data, _) => data.macdSignal ?? 0,
        color: Colors.purple.withValues(alpha: 0.5),
        width: 2,
        animationDuration: 0,
      )
    ];
  }

  // macd axis의 최대 최소값
  // - 최소값은 전체 범위의 5% 아래
  // - 최대값음 전체 범위의 (1/0.3)배를 해서 하단의 30% 정도의 영역에 macd line이 그려지게 함
  List<double> getMacdAxisRange(
      List<IndicatorData> indicatorData, double visibleRate) {
    if (indicatorData.isEmpty) return [0, 0];

    double maxVal = indicatorData
        .map((indicator) =>
            math.max(indicator.macdLine ?? 0, indicator.macdSignal ?? 0))
        .reduce((a, b) => a > b ? a : b);
    double minVal = indicatorData
        .map((indicator) =>
            math.min(indicator.macdLine ?? 0, indicator.macdSignal ?? 0))
        .reduce((a, b) => a < b ? a : b);

    final macdRange = (maxVal - minVal);
    final macdMin = minVal - macdRange * 0.05;
    final macdMax = maxVal + macdRange / visibleRate;

    return [macdMin, macdMax];
  }
}
