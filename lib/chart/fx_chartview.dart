import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:syncfusion_flutter_charts/charts.dart';

import '../../data/data.dart';
import '../../view/common/commonview.dart';
import '../data/providers.dart';
import 'candlestick.dart';
import 'chartpainter.dart';
import '/common/util.dart';
import '/pages/dex/providers/order_provider.dart';
import 'fx_consts.dart';
import 'kline_chart_controller.dart';
import 'indicator_data_manager.dart';
import 'indicator_select_popup.dart';

class FxChartView extends ConsumerStatefulWidget {
  final bool isBacktesting;

  const FxChartView({
    super.key,
    this.isBacktesting = false,
  });

  @override
  ConsumerState<FxChartView> createState() => FxChartViewState();
}

class FxChartViewState extends ConsumerState<FxChartView>
    with SingleTickerProviderStateMixin {
  // 기본 표시 개수 제한

  final tickChartKey = GlobalKey<SfCartesianChartState>();
  final kLineChartKey = GlobalKey<SfCartesianChartState>();

  // 차트 제스처 컨트롤러
  late KLineChartViewController kLineChartViewController;

  late ZoomPanBehavior zoomPanBehavior;
  late ZoomPanBehavior kLineZoomPanBehavior;
  late TrackballBehavior trackballBehavior;
  late TooltipBehavior tooltipBehavior;

  Map<String, ui.Image> get assetImageMap => ChartImageManager().assetImageMap;
  List<String> get updownAssetNames => ChartImageManager().updownAssetNames;

  //List<FxData> get prices => chartViewController.prices;

  bool get isPriceGoingUp => kLineChartViewController.isPriceGoingUp;
  double get currentPrice => kLineChartViewController.currentPrice;

  List<double> yAxisLineValues = [];
  List<String> yAxisValueTypes = [];

  List<String> chartTypes = [];
  String currentTimeframe = '1d';

  void changeChartType(String newTf) {
    currentTimeframe = newTf;
    kLineChartViewController.intervalTypeIndex = newTf;

    kLineChartViewController.setEnabled(true);

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    kLineChartViewController = KLineChartViewController(
      chartKey: kLineChartKey,
      displayLimit: 80,
      onDataUpdated: (bool addToLast) {
        if (!mounted) return;
        setState(() {});
      },
    );

    chartTypes = timeframeTexts;

    zoomPanBehavior = ZoomPanBehavior(
      enablePanning: true,
      enableMouseWheelZooming: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x,
      maximumZoomLevel: 0.5,
    );

    kLineZoomPanBehavior = ZoomPanBehavior(
      enablePanning: false,
      enableMouseWheelZooming: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x,
      maximumZoomLevel: 0.5,
    );

    tooltipBehavior =
        TooltipBehavior(enable: true, activationMode: ActivationMode.longPress);

    trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.longPress,
      tooltipSettings: InteractiveTooltip(enable: true, color: Colors.white),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      changeChartType(currentTimeframe);
    });
  }

  @override
  void dispose() {
    super.dispose();

    kLineChartViewController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentPriceProvider, (prev, next) {
      kLineChartViewController.currentPrice = next;
      if (mounted) setState(() {});
    });

    if (!kLineChartViewController.isEnabled) {
      return Container();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: 50,
                  child: _buildDashboard(),
                ),
                Container(color: Colors.black, height: 4),

                // 바깥쪽 높이가 정해져있어야 함
                Expanded(child: _buildChart()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCryptoCurrentPrice() {
    final color = priceColors[isPriceGoingUp ? 0 : 1];

    return Row(
      children: [
        SizedBox(width: 10),
        Image.asset(
          'assets/logo/ic_btc.png',
          width: 30,
        ),
        SizedBox(width: 10),
        Image.asset(
            'assets/image/${isPriceGoingUp ? 'arrow_up2.png' : 'arrow_down2.png'}',
            color: color,
            width: 20),
        SizedBox(width: 10),
        Text(
          currentPrice.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildCryptoCurrentPrice(),
        Expanded(child: Container()),
        InkWell(
          child: Image.asset(
            'assets/image/icon_fx.png',
            width: 25,
            color: Colors.grey,
          ),
          onTap: () {
            openIndicatorSelectPopup(context, onChangeSelection: (s, v) {
              setState(() {});
            });
          },
        ),
        SizedBox(width: 5),
        Card(
          child: Padding(
              padding: const EdgeInsets.all(0),
              child: SizedBox(
                height: 30,
                child: DropDownMenu(
                  value: currentTimeframe,
                  width: 100,
                  padding: EdgeInsets.zero,
                  itemPadding: EdgeInsets.zero,
                  borderColor: Colors.transparent,
                  dense: true,
                  onChanged: (v) {
                    changeChartType(v!);
                  },
                  items: chartTypes,
                ),
              )),
        ),
      ],
    );
  }

  bool get showVolume =>
      DataManager().selectedIndicators.contains('Volume') || true;
  bool get showMACD => DataManager().selectedIndicators.contains('MACD');

  static const double PRICE_AREA_RATIO = 0.7;

  // 영역 계산을 다시 정의
  double get totalRange =>
      kLineChartViewController.maxY - kLineChartViewController.minY;

  // 전체 차트 범위 (전체 영역의 상위 70%만 사용)
  double get adjustedMinY =>
      kLineChartViewController.minY - (totalRange * (1 - PRICE_AREA_RATIO));
  double get adjustedMaxY => kLineChartViewController.maxY;

  void setMakeVisible(DateTime value) {
    kLineChartViewController.setMakeVisible(value);
  }

  Widget _buildKLineChart() {
    final macdRanges = IndicatorDataManager().getMacdAxisRange(
        kLineChartViewController.indicators, 1 - PRICE_AREA_RATIO);

    final volumeMax = _getMaxVolume() / (1 - PRICE_AREA_RATIO);

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SfCartesianChart(
        key: kLineChartKey,
        backgroundColor: Colors.transparent,
        plotAreaBorderWidth: 0,
        enableAxisAnimation: true,
        zoomPanBehavior: kLineZoomPanBehavior,
        trackballBehavior: trackballBehavior,
        tooltipBehavior: tooltipBehavior,
        onTrackballPositionChanging: (TrackballArgs args) {
          kLineChartViewController.onTrackballPositionChanging(args);

          if (args.chartPointInfo.dataPointIndex != null) {
            tooltipBehavior.showByPixel(
                args.chartPointInfo.xPosition!.toDouble(),
                args.chartPointInfo.yPosition!.toDouble());
          }
        },
        // syncfusion chart에서 panning은 zoom이 된 경우에만 동작하기 때문에 별도로 구현해줘야 함
        onChartTouchInteractionDown: (ChartTouchInteractionArgs args) {
          kLineChartViewController.onPanStart(args);
        },
        onChartTouchInteractionMove: (ChartTouchInteractionArgs args) {
          kLineChartViewController.onPanUpdate(args);
        },
        onChartTouchInteractionUp: (ChartTouchInteractionArgs args) {
          kLineChartViewController.onPanEnd(args);
        },
        onActualRangeChanged: (args) {
          kLineChartViewController.onActualRangeChanged(args);
        },
        primaryXAxis: DateTimeAxis(
          name: 'xAxis',
          minimum: kLineChartViewController.visibleMinX,
          maximum: kLineChartViewController.visibleMaxX,
          isVisible: true,
          majorGridLines: MajorGridLines(width: 0),
          minorGridLines: MinorGridLines(width: 0),
          majorTickLines: MajorTickLines(size: 0),
          minorTickLines: MinorTickLines(size: 0),
          axisLine: AxisLine(width: 1),
          labelPosition: ChartDataLabelPosition.outside,
          onRendererCreated: (DateTimeAxisController controller) {
            kLineChartViewController.xAxisController = controller;
          },
          initialZoomFactor: 1.0,
          plotBands: [
            if (kLineChartViewController.crossHairPosition != null)
              plotVertLine(kLineChartViewController.crossHairPosition,
                  Colors.grey, false, ''),
          ],
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            DateTime utcTime = DateTime.fromMillisecondsSinceEpoch(
              details.value.toInt(),
              isUtc: true,
            );

            return ChartAxisLabel(
              ChartTimeFormatter.formatByTimeframe(utcTime, currentTimeframe),
              details.textStyle,
            );
          },
        ),
        primaryYAxis: NumericAxis(
          minimum: adjustedMinY,
          maximum: adjustedMaxY,
          isVisible: false,
          labelStyle: TextStyle(fontSize: 12),
          majorGridLines: MajorGridLines(width: 0),
          minorGridLines: const MinorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          minorTickLines: const MinorTickLines(size: 0),
          axisLine: const AxisLine(width: 1),
          labelPosition: ChartDataLabelPosition.outside,
        ),
        axes: <ChartAxis>[
          NumericAxis(
            name: 'rightAxis',
            minimum: adjustedMinY,
            maximum: adjustedMaxY,
            labelStyle: TextStyle(fontSize: 10),
            axisLabelFormatter: (AxisLabelRenderDetails details) {
              return ChartAxisLabel(
                '${Util.commaStringNumber(parseDouble(details.text).toStringAsFixed(1))}    ',
                TextStyle(color: Colors.white),
              );
            },
            onRendererCreated: (NumericAxisController controller) {
              kLineChartViewController.yAxisController = controller;
            },
            majorGridLines: MajorGridLines(
                width: 0, color: Colors.grey.withValues(alpha: 0.3)),
            minorGridLines: const MinorGridLines(width: 0),
            majorTickLines: const MajorTickLines(size: 0),
            minorTickLines: const MinorTickLines(size: 0),
            axisLine: const AxisLine(width: 1),
            opposedPosition: true,
            decimalPlaces: 0,
            plotBands: [
              ...kLineChartViewController.getYPlotBands(),
              ..._getHorizLines(),
            ],
          ),
          NumericAxis(
            name: 'volumeAxis',
            minimum: 0,
            maximum: volumeMax,
            isVisible: showVolume, // 거래량 축은 숨김
            opposedPosition: false, // 왼쪽에 배치
            labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
            axisLabelFormatter: (AxisLabelRenderDetails details) {
              final volumeValue = parseDouble(details.text);
              return ChartAxisLabel(
                volumeValue > _getMaxVolume() ? '' : _formatVolume(volumeValue),
                TextStyle(color: const ui.Color.fromARGB(255, 202, 196, 196)),
              );
            },
            majorGridLines: MajorGridLines(width: 0),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            minorTickLines: MinorTickLines(size: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey),
            autoScrollingDelta: null,
            enableAutoIntervalOnZooming: false,
            plotBands: [
              plotHorizeLine(
                  volumeMax / 3, Colors.grey.withAlpha(150), true, ''),
            ],
          ),
          NumericAxis(
            name: 'macdAxis',
            minimum: macdRanges[0],
            maximum: macdRanges[1],
            isVisible: false,
            opposedPosition: false, // 왼쪽에 배치
            labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
            majorGridLines: MajorGridLines(width: 0),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            minorTickLines: MinorTickLines(size: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey),
          ),
          NumericAxis(
            name: 'momentumAxis',
            minimum: -0.5,
            maximum: 1.5,
            isVisible: false,
            opposedPosition: false, // 왼쪽에 배치
            labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
            majorGridLines: MajorGridLines(width: 0),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            minorTickLines: MinorTickLines(size: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey),
          ),
          NumericAxis(
            name: 'stochRsiAxis',
            minimum: -20,
            maximum: 120,
            isVisible: false,
            opposedPosition: false, // 왼쪽에 배치
            labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
            majorGridLines: MajorGridLines(width: 0),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            minorTickLines: MinorTickLines(size: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey),
          ),
          NumericAxis(
            name: 'williamsRAxis',
            minimum: -100,
            maximum: 700 / 3,
            isVisible: false,
            opposedPosition: false, // 왼쪽에 배치
            labelStyle: TextStyle(fontSize: 10, color: Colors.grey),
            majorGridLines: MajorGridLines(width: 0),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            minorTickLines: MinorTickLines(size: 0),
            axisLine: AxisLine(width: 1, color: Colors.grey),
          ),
        ],
        series: [
          // 거래량 컬럼 (맨 뒤에 배치해서 캔들 뒤로 숨김)
          if (showVolume)
            ColumnSeries<CandlestickEx, DateTime>(
              name: 'Volume',
              isVisibleInLegend: true,
              legendIconType: LegendIconType.rectangle,
              xAxisName: 'xAxis',
              yAxisName: 'volumeAxis', // 거래량 전용 축 사용
              dataSource: kLineChartViewController.candlesticks,
              xValueMapper: (CandlestickEx data, _) => data.date,
              yValueMapper: (CandlestickEx data, _) => data.volume,
              pointColorMapper: (CandlestickEx data, _) =>
                  data.close >= data.open
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.red.withValues(alpha: 0.5),
              width: 0.99,
              spacing: 0,
              animationDuration: 0,
            ),

          // 캔들스틱 시리즈
          CandleSeries<CandlestickEx, DateTime>(
            xAxisName: 'xAxis',
            yAxisName: 'rightAxis',
            isVisibleInLegend: false,
            onRendererCreated: (ChartSeriesController controller) {
              kLineChartViewController.seriesController = controller;
            },
            dataSource: kLineChartViewController.candlesticks,
            xValueMapper: (CandlestickEx data, _) => data.date,
            lowValueMapper: (CandlestickEx data, _) => data.low,
            highValueMapper: (CandlestickEx data, _) => data.high,
            openValueMapper: (CandlestickEx data, _) => data.open,
            closeValueMapper: (CandlestickEx data, _) => data.close,
            enableSolidCandles: true,
            bullColor: AppTheme.upColor,
            bearColor: AppTheme.downColor,
            animationDuration: 0,
            borderWidth: 0.5,
            width: 1,
            spacing: 0,
            showIndicationForSameValues: true, // 시리즈 탭 이벤트
            selectionBehavior: SelectionBehavior(
              enable: true,
              selectedColor: Colors.yellow.withOpacity(0.8),
              unselectedColor: Colors.grey.withOpacity(0.3),
            ),
            onPointTap: (ChartPointDetails details) {
              print(details);
            },
          ),
          ...IndicatorDataManager()
              .buildIndicatorSeries(kLineChartViewController.indicators),
        ],
        annotations: [
          ...kLineChartViewController.getAnnots(),
        ],
      ),
    );
  }

  // 최대 거래량 계산 헬퍼 함수 추가
  double _getMaxVolume() {
    if (kLineChartViewController.candlesticks.isEmpty) return 1000000;

    return kLineChartViewController.candlesticks
        .map((candle) => candle.volume)
        .reduce((a, b) => a > b ? a : b);
  }

  // 거래량 포맷팅
  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    } else {
      return volume.toStringAsFixed(0);
    }
  }

  Widget _buildChart() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: _buildKLineChart(),
        ),
        ..._buildZoomControls(),
      ],
    );
  }

  List<Widget> _buildZoomControls() {
    return [
      Positioned(
        right: 10,
        bottom: 0,
        child: Row(
          children: [
            InkWell(
              onTap: () {
                kLineChartViewController.resetToDefaultRange();
                setState(() {});
              },
              child: Icon(
                Icons.refresh,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  PlotBand plotHorizeLine(
      double yValue, Color color, bool isDashedLine, String text) {
    return PlotBand(
      isVisible: true,
      start: yValue,
      end: yValue,
      text: text,
      shouldRenderAboveSeries: true,
      horizontalTextPadding: '-10',
      horizontalTextAlignment: TextAnchor.end,
      verticalTextAlignment: TextAnchor.middle, // 수직 가운데 정렬
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 0,
      ),
      borderWidth: 1,
      borderColor: color,
      dashArray: isDashedLine ? [5, 5] : [0, 0],
    );
  }

  PlotBand plotVertLine(
      dynamic xValue, Color color, bool isDashedLine, String text) {
    return PlotBand(
      isVisible: true,
      start: xValue,
      end: xValue,
      text: text,
      shouldRenderAboveSeries: true,
      verticalTextPadding: '-10',
      verticalTextAlignment: TextAnchor.middle,
      horizontalTextAlignment: TextAnchor.end,
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 0,
      ),
      borderWidth: 1,
      borderColor: color,
      dashArray: isDashedLine ? [5, 5] : [0, 0],
    );
  }

  List<PlotBand> _getHorizLines() {
    final lines = yAxisLineValues
        .asMap()
        .map((index, e) => MapEntry(
            index,
            plotHorizeLine(
                yAxisLineValues[index],
                yAxisValueTypes[index] == 'bust'
                    ? Colors.red
                    : yAxisValueTypes[index] == 'entry'
                        ? Colors.grey
                        : priceColors[isPriceGoingUp ? 0 : 1],
                yAxisValueTypes[index] == 'current',
                yAxisLineValues[index].toStringAsFixed(2))))
        .values
        .toList();

    // 오더북에서 선택한 가격 표시
    final selectedPrice = ref.watch(orderPriceProvider);
    if (selectedPrice != null) {
      lines.add(plotHorizeLine(
        selectedPrice,
        Colors.yellow,
        true,
        selectedPrice.toStringAsFixed(2),
      ));
    }

    return lines;
  }
}
