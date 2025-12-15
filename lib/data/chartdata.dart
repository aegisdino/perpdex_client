import '../common/util.dart';

class ChartData {
  ChartData(this.x, this.y);
  final String x;
  double y;
}

class ChartDataInt {
  ChartDataInt(this.x, this.y);
  final String x;
  final int y;
}

enum PriceType { Mark, Last, Rand }

class FxData {
  final double x;
  final double y;
  final DateTime date;
  final bool isMarkPrice;

  const FxData(this.x, this.y, this.date, this.isMarkPrice);

  static FxData fromJson(Map<String, dynamic> data) {
    double price = parseDouble(data['price']);
    int millis = parseInt(data['time'] ?? data['pricedate']);
    DateTime date = DateTime.fromMillisecondsSinceEpoch(millis);
    final bool isMarkPrice = (data['type'] ?? 'm') != 'i';
    return FxData(0, price, date, isMarkPrice);
  }
}
