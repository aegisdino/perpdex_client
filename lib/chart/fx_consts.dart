import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:perpdex/common/all.dart';

List<Color> priceColors = [
  AppTheme.upColor,
  AppTheme.downColor,
];

List<String> signalTexts = ['SELL', 'HOLD', 'BUY'];
List<Color> signalColors = [Colors.red, Colors.yellow, Colors.green];

enum TradingMode { Scalp, Daily, Swing }

enum SignalType { Classic, Momentum, Reactive }

// 타임프레임별 색상 정의
Map<String, Color> timeframeColors = {
  '1m': Colors.blue.shade300,
  '3m': Colors.green.shade400,
  '5m': Colors.orange.shade400,
  '15m': Colors.purple.shade400,
  '1h': Colors.red.shade400,
  '4h': Colors.teal.shade400,
  '1d': Colors.brown.shade400,
};

Map<String, int> timeframeDuration = {
  '1m': 60,
  '3m': 60 * 3,
  '5m': 60 * 5,
  '15m': 60 * 15,
  '30m': 60 * 30,
  '1h': 60 * 60,
  '2h': 60 * 60 * 2,
  '4h': 60 * 60 * 4,
  '1d': 60 * 60 * 24,
  '1w': 60 * 60 * 24 * 7,
  '1M': 60 * 60 * 24 * 30,
};

List<String> timeframeTexts = [
  '1m',
  '3m',
  '5m',
  '15m',
  '30m',
  '1h',
  '2h',
  '4h',
  '1d',
  '1w',
  '1M'
];

class ChartTimeFormatter {
  static String formatByTimeframe(DateTime utcTime, String timeframe) {
    switch (timeframe) {
      case '1m':
      case '5m':
      case '15m':
      case '30m':
        return DateFormat('HH:mm').format(utcTime);

      case '1h':
      case '4h':
        return DateFormat('MM/dd HH:mm').format(utcTime);

      case '1d':
        return DateFormat('MM/dd').format(utcTime);

      case '1w':
      case '1M':
        return DateFormat('yyyy/MM').format(utcTime);

      default:
        return DateFormat('MM/dd HH:mm').format(utcTime);
    }
  }
}
