import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/chart/fx_chartview.dart';

/// K-line (캔들스틱) 차트 위젯
///
/// 사용법:
/// - nova 폴더를 삭제하기 전까지는 ../../../nova/lib/pages/nova/fx_chartview.dart를 import하여 사용
/// - nova 삭제 후에는 lib/common/chart/kline_chart_widget.dart를 사용하도록 변경 필요
class TradingChart extends ConsumerStatefulWidget {
  const TradingChart({super.key});

  @override
  ConsumerState<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends ConsumerState<TradingChart> {
  @override
  Widget build(BuildContext context) {
    return FxChartView();
  }
}
