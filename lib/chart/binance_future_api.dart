import 'dart:convert';
import 'package:http/http.dart' as http;

import 'candlestick.dart';
import '/config/config.dart';

class BinanceFuturesApi {
  /// 캔들스틱(K라인) 데이터 가져오기
  ///
  /// [symbol] - 심볼 (예: 'BTCUSDT')
  /// [interval] - 시간 간격 ('1m', '1h', '1d' 등)
  /// [limit] - 가져올 데이터 개수 (최대 1500)
  /// [startTime] - 시작 시간 (밀리초 타임스탬프)
  /// [endTime] - 종료 시간 (밀리초 타임스탬프)
  static Future<List<CandlestickEx>> getKlineData({
    required String symbol,
    required String interval,
    int? limit,
    int? startTime,
    int? endTime,
  }) async {
    final Map<String, dynamic> params = {
      'symbol': symbol,
      'interval': interval,
    };

    if (limit != null) params['limit'] = limit.toString();
    if (startTime != null) params['startTime'] = startTime.toString();
    if (endTime != null) params['endTime'] = endTime.toString();

    //debugPrint('getKlineData: ${jsonEncode(params)}');

    final Uri uri = Config.getUri('/api/klines/binance').replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 비정상 데이터 필터링 (가격이 너무 크거나 0인 경우 제외)
        final validData = data.where((item) {
          final open = double.tryParse(item[1].toString()) ?? 0;
          final high = double.tryParse(item[2].toString()) ?? 0;
          final low = double.tryParse(item[3].toString()) ?? 0;
          final close = double.tryParse(item[4].toString()) ?? 0;

          // 가격이 0이거나 10억 이상이면 비정상 데이터
          const maxValidPrice = 1000000000.0; // 10억
          return open > 0 &&
              high > 0 &&
              low > 0 &&
              close > 0 &&
              open < maxValidPrice &&
              high < maxValidPrice &&
              low < maxValidPrice &&
              close < maxValidPrice;
        }).toList();

        return validData
            .map((item) => CandlestickEx.fromBinanceData(item, 0))
            .toList();
      } else {
        throw Exception('API 요청 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('데이터 가져오기 실패: $e');
    }
  }

  /// interval과 시간 범위에 따른 필요한 데이터 개수 계산
  static int calculateRequiredLimit({
    required String intervalType,
    required int intervalValue,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final duration = endTime.difference(startTime);
    int requiredCount;

    switch (intervalType) {
      case 'm':
        // 분봉: 전체 분 수 / interval 값
        requiredCount = (duration.inMinutes / intervalValue).ceil();
        break;

      case 'h':
        // 시간봉: 전체 시간 수 / interval 값
        requiredCount = (duration.inHours / intervalValue).ceil();
        break;

      case 'd':
        // 일봉: 전체 일 수
        requiredCount = duration.inDays;
        break;

      case 'w':
        // 주봉: 전체 주 수
        requiredCount = (duration.inDays / 7).ceil();
        break;

      case 'M':
        // 월봉: 대략적인 월 수 (30일 기준)
        requiredCount = (duration.inDays / 30).ceil();
        break;

      default:
        requiredCount = 100;
    }

    // 최소 1개, 최대 1500개 (바이낸스 API 제한)
    return requiredCount.clamp(1, 1500);
  }

  /// interval에 따라 startTime을 조정하여 최대 limit 개수만큼의 기간으로 제한
  static DateTime adjustStartTime({
    required String intervalType,
    required int intervalValue,
    required DateTime endTime,
    required int maxLimit,
  }) {
    Duration adjustDuration;

    switch (intervalType) {
      case 'm':
        // 분봉: maxLimit * intervalValue 분 전
        adjustDuration = Duration(minutes: maxLimit * intervalValue);
        break;

      case 'h':
        // 시간봉: maxLimit * intervalValue 시간 전
        adjustDuration = Duration(hours: maxLimit * intervalValue);
        break;

      case 'd':
        // 일봉: maxLimit 일 전
        adjustDuration = Duration(days: maxLimit);
        break;

      case 'w':
        // 주봉: maxLimit * 7 일 전
        adjustDuration = Duration(days: maxLimit * 7);
        break;

      case 'M':
        // 월봉: maxLimit * 30 일 전 (대략적)
        adjustDuration = Duration(days: maxLimit * 30);
        break;

      default:
        adjustDuration = Duration(days: maxLimit);
    }

    return endTime.subtract(adjustDuration);
  }

  static Future<List<CandlestickEx>> getData({
    required String intervalType,
    int intervalValue = 1,
    required String symbol,
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // startTime과 endTime이 모두 제공된 경우, 필요한 limit 자동 계산
    int adjustedLimit = limit;
    DateTime? adjustedStartTime = startTime;

    if (startTime != null && endTime != null) {
      final requiredLimit = calculateRequiredLimit(
        intervalType: intervalType,
        intervalValue: intervalValue,
        startTime: startTime,
        endTime: endTime,
      );

      // 요청된 limit보다 더 많은 데이터가 필요한 경우
      if (requiredLimit > limit) {
        // 바이낸스 최대 제한(1500)을 초과하는 경우 startTime 조정
        if (requiredLimit > 1500) {
          adjustedLimit = 1500;
          adjustedStartTime = adjustStartTime(
            intervalType: intervalType,
            intervalValue: intervalValue,
            endTime: endTime,
            maxLimit: 1500,
          );
          print('Required $requiredLimit candles exceeds API limit (1500).');
          print(
              'StartTime adjusted: ${startTime.toIso8601String()} -> ${adjustedStartTime.toIso8601String()}');
          print('Will fetch latest 1500 candles.');
        } else {
          // 1500 이하면 limit만 증가
          adjustedLimit = requiredLimit;
          print(
              'Limit adjusted: $limit -> $adjustedLimit (required for time range)');
        }
      }
    }

    List<CandlestickEx> result;
    switch (intervalType) {
      case 'm':
        result = await getMinuteData(
            minutes: intervalValue,
            symbol: symbol,
            limit: adjustedLimit,
            startTime: adjustedStartTime,
            endTime: endTime);
        break;

      case 'h':
        result = await getHourlyData(
            hours: intervalValue,
            symbol: symbol,
            limit: adjustedLimit,
            startTime: adjustedStartTime,
            endTime: endTime);
        break;

      case 'd':
        result = await getDailyData(
            symbol: symbol,
            limit: adjustedLimit,
            startTime: adjustedStartTime,
            endTime: endTime);
        break;

      case 'M':
        result = await getMonthlyData(
            symbol: symbol,
            limit: adjustedLimit,
            startTime: adjustedStartTime,
            endTime: endTime);
        break;

      default:
        result = [];
    }

    return result;
  }

  /// 분봉 데이터 가져오기 (1분, 3분, 5분, 15분, 30분)
  static Future<List<CandlestickEx>> getMinuteData({
    required String symbol,
    required int minutes, // 1, 3, 5, 15, 30 중 하나
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // 유효한 분 간격 확인
    if (![1, 3, 5, 15, 30].contains(minutes)) {
      throw ArgumentError('minutes는 1, 3, 5, 15, 30 중 하나여야 합니다.');
    }

    return getKlineData(
      symbol: symbol,
      interval: '${minutes}m',
      limit: limit,
      startTime: startTime?.millisecondsSinceEpoch,
      endTime: endTime?.millisecondsSinceEpoch,
    );
  }

  /// 시간봉 데이터 가져오기 (1시간, 2시간, 4시간, 6시간, 8시간, 12시간)
  static Future<List<CandlestickEx>> getHourlyData({
    required String symbol,
    required int hours, // 1, 2, 4, 6, 8, 12 중 하나
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // 유효한 시간 간격 확인
    if (![1, 2, 4, 6, 8, 12].contains(hours)) {
      throw ArgumentError('hours는 1, 2, 4, 6, 8, 12 중 하나여야 합니다.');
    }

    return getKlineData(
      symbol: symbol,
      interval: '${hours}h',
      limit: limit,
      startTime: startTime?.millisecondsSinceEpoch,
      endTime: endTime?.millisecondsSinceEpoch,
    );
  }

  /// 일봉 데이터 가져오기
  static Future<List<CandlestickEx>> getDailyData({
    required String symbol,
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return getKlineData(
      symbol: symbol,
      interval: '1d',
      limit: limit,
      startTime: startTime?.millisecondsSinceEpoch,
      endTime: endTime?.millisecondsSinceEpoch,
    );
  }

  /// 주봉 데이터 가져오기
  static Future<List<CandlestickEx>> getWeeklyData({
    required String symbol,
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return getKlineData(
      symbol: symbol,
      interval: '1w',
      limit: limit,
      startTime: startTime?.millisecondsSinceEpoch,
      endTime: endTime?.millisecondsSinceEpoch,
    );
  }

  /// 월봉 데이터 가져오기
  static Future<List<CandlestickEx>> getMonthlyData({
    required String symbol,
    int limit = 100,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return getKlineData(
      symbol: symbol,
      interval: '1M',
      limit: limit,
      startTime: startTime?.millisecondsSinceEpoch,
      endTime: endTime?.millisecondsSinceEpoch,
    );
  }

  /// 압축된 거래 내역 (집계된 Tick 데이터)
  ///
  /// [symbol] - 심볼 (예: 'BTCUSDT')
  /// [startTime] - 시작 시간 (밀리초 타임스탬프)
  /// [endTime] - 종료 시간 (밀리초 타임스탬프)
  /// [limit] - 가져올 데이터 개수 (기본값: 500, 최대: 1000)
  static Future<List<AggregatedTickData>> getAggregatedTrades({
    required String symbol,
    int? startTime,
    int? endTime,
    int limit = 500,
  }) async {
    final Map<String, dynamic> params = {
      'symbol': symbol,
      'limit': limit.toString(),
    };

    if (startTime != null) params['startTime'] = startTime.toString();
    if (endTime != null) params['endTime'] = endTime.toString();

    final Uri uri = Config.getUri('/api/futures/aggTrades').replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => AggregatedTickData.fromJson(item)).toList();
      } else {
        throw Exception(
            '집계 거래 데이터 요청 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('집계 거래 데이터 가져오기 실패: $e');
    }
  }

  /// 최근 거래 내역 (Tick 데이터)
  ///
  /// [symbol] - 심볼 (예: 'BTCUSDT')
  /// [limit] - 가져올 데이터 개수 (기본값: 500, 최대: 1000)
  static Future<List<TickData>> getRecentTrades({
    required String symbol,
    int limit = 500,
  }) async {
    final Map<String, dynamic> params = {
      'symbol': symbol,
      'limit': limit.toString(),
    };

    final Uri uri = Config.getUri('/api/futures/trades').replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => TickData.fromJson(item)).toList();
      } else {
        throw Exception(
            '최근 거래 데이터 요청 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('최근 거래 데이터 가져오기 실패: $e');
    }
  }
}
