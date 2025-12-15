import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:syncfusion_flutter_charts/charts.dart';

import 'binance_future_api.dart';
import 'fx_consts.dart';
import '../common/util.dart';
import 'candlestick.dart';
import 'indicator_data_manager.dart';
import 'plot_band_view.dart';

final candlestickDataProvider = StateProvider<List<CandlestickEx>>((ref) => []);

enum ChartDragMode { None, Pan, Zoom, YZoom }

/// 차트의 확대/축소 및 패닝 제스처를 관리하는 컨트롤러
/// - syncfusion chart에서 panning은 zoom이 된 경우에만 동작함
///
class KLineChartViewController {
  // 차트 키 참조
  final GlobalKey chartKey;

  void dispose() {
    clearTimer();
  }

  String symbol = 'BTCUSDT';

  // 축 컨트롤러
  DateTimeAxisController? xAxisController;
  NumericAxisController? yAxisController;
  ChartSeriesController? _seriesController;

  IndicatorDataManager _indicator = IndicatorDataManager();

  IndicatorDataManager get indicator => _indicator;

  set seriesController(ChartSeriesController value) =>
      _seriesController = value;

  void setEnabled(bool v) {
    isEnabled = v;
    if (!v) {
      clearTimer();
    } else {
      registerTimer();
    }
  }

  bool isEnabled = true;

  Map<int, List<CandlestickEx>> klineDataMap = {};

  List<CandlestickEx> get candlesticks => klineDataMap[_timeframeIndex]!;

  List<Duration> dateMarginX = [
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(minutes: 60),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
    Duration(days: 2),
    Duration(days: 14),
    Duration(days: 60)
  ];

  int _timeframeIndex = 0;
  String _intervalType = 'm';
  int _intervalValue = 1;

  String get timeframe => timeframeTexts[_timeframeIndex];

  List<IndicatorData> get indicators =>
      _indicator.getCachedData(symbol, timeframe);

  Timer? _dataTimer;

  void registerTimer() {
    _dataTimer?.cancel();

    // 주기적으로 바이낸스에서 캔들 데이터 가져오고, nova 서버에서 히트맵 가져옴
    _dataTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_dataTimer != null) {
        _loadRecentData();
      }
    });
  }

  void clearTimer() {
    _dataTimer?.cancel();
    _dataTimer = null;
  }

  set intervalTypeIndex(String value) {
    _timeframeIndex = timeframeTexts.indexOf(value);

    _intervalType = value.substring(value.length - 1);
    _intervalValue = parseInt(value.substring(0, value.length - 1));

    if (candlesticks.isEmpty) {
      _loadOldFxData();
    }

    // nova 서버에서 최신 데이터 가져오기
    _indicator.loadInitialData(symbol, timeframe).then((values) {
      if (values.isNotEmpty && candlesticks.isNotEmpty) {
        // 캔들 스틱이 최신이 있으면 계산해줘야 함
        if (values.last.timestamp <=
            candlesticks.last.openTime.millisecondsSinceEpoch) {
          final newCandles = candlesticks
              .where((e) =>
                  e.openTime.millisecondsSinceEpoch >= values.last.timestamp)
              .toList();

          _indicator.calculateRealtime(
              symbol, timeframe, newCandles, candlesticks);
        }
      }
    });

    registerTimer();
  }

  // 기본 표시 개수 제한
  final int displayLimit;

  // 유지하고 있을 갯수 (백테스트 제외)
  int get keepPriceCount => displayLimit * 3;

  // 확대/축소
  // - 값이 크면 줌아웃, 작으면 줌인 (0.1 = 1/10, 5: 5배 데이터 더 보임)
  double get _zoomFactorX => (xAxisController?.zoomFactor ?? 1.0);
  double get zoomFactorX =>
      ((_zoomFactorX.isNaN || _zoomFactorX.isInfinite) ? 1.0 : _zoomFactorX);

  // 현재 화면에 보이는 범위
  DateTime currentMinX = DateTime.now();
  DateTime currentMaxX = DateTime.now();
  double minY = 0;
  double maxY = 0;

  // 현재 패닝 중인지 여부
  ChartDragMode _chartDragMode = ChartDragMode.None;
  bool get isPanning => _chartDragMode == ChartDragMode.Pan;
  bool get isZooming => _chartDragMode == ChartDragMode.Zoom;
  bool get isYZooming => _chartDragMode == ChartDragMode.YZoom;
  bool _isTrackballMode = false; // trackball 활성화 상태 관리

  // 실시간으로 업데이트 되는 경우인지, 유저가 멈춰서 보는 건지
  bool isCustomRange = false;

  // 선택된 시간
  DateTime? crossHairPosition;

  double? _currentPrice;

  // 데이터 업데이트 콜백
  final Function(bool addToLast) onDataUpdated;

  double get currentPrice =>
      _currentPrice ??
      (candlesticks.isNotEmpty ? candlesticks.last.close : 0.0);

  set currentPrice(double v) {
    _currentPrice = v;
  }

  bool get isPriceGoingUp => (candlesticks.length > 1 &&
          candlesticks.last.close -
                  candlesticks[candlesticks.length - 2].close >
              0)
      ? true
      : false;

  /// 생성자
  KLineChartViewController({
    required this.chartKey,
    required this.displayLimit,
    required this.onDataUpdated,
  }) {
    for (var i = 0; i < timeframeTexts.length; i++) {
      klineDataMap[i] = [];
    }
  }

  /// 차트 크기 가져오기
  Size? get chartSize =>
      (chartKey.currentContext?.findRenderObject() as RenderBox?)?.size;

  Offset getLocalPosition(Offset pos) =>
      (chartKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(pos);

  /// 기본 표시 범위
  List<CandlestickEx> get defaultVisiblePrices {
    if (candlesticks.isEmpty) return [];

    // zoomFactorX는 최대 10: 10배 데이터를 보여주기
    final xRangeSize = (displayLimit * zoomFactorX).ceil();
    if (candlesticks.length <= xRangeSize) {
      return candlesticks;
    } else {
      return candlesticks.sublist(candlesticks.length - xRangeSize);
    }
  }

  /// 차트에 표시될 x축의 최소값
  DateTime get visibleMinX => isCustomRange
      ? currentMinX
      : (defaultVisiblePrices.isEmpty
          ? DateTime.now()
          : defaultVisiblePrices.first.date);

  /// 차트에 표시될 x축의 최대값
  DateTime get visibleMaxX => isCustomRange
      ? currentMaxX
      : (defaultVisiblePrices.isEmpty
          ? DateTime.now()
          : defaultVisiblePrices.last.date.add(dateMarginX[_timeframeIndex]));

  /// 표시 범위 높이
  double get visibleRangeY => maxY - minY;

  double get totalDataRange => displayLimit.toDouble();

  /// 현재 범위를 기본값으로 리셋
  void resetToDefaultRange() {
    if (defaultVisiblePrices.isEmpty) return;

    isCustomRange = false;

    // 상태 초기화
    // - 시작 위치만 세팅하면 알아서 바뀜
    if (candlesticks.isNotEmpty) {
      currentMinX = candlesticks.first.date;
    }

    setZoomFactorX(1);

    updateData();
  }

  /// 데이터 업데이트 (min/max 계산)
  void updateData() {
    if (candlesticks.isEmpty || !isEnabled) return;

    double minValue = double.maxFinite;
    double maxValue = double.negativeInfinity;

    // 1. 현재 보이는 X 범위의 데이터만 필터링 (y축의 범위를 계산하기 위해서만 사용함)
    List<CandlestickEx> visibleData = [];

    if (isCustomRange) {
      final baseRangeMillis =
          displayLimit * timeframeDuration[timeframe]! * 1000;
      final zoomedRangeMillis = (baseRangeMillis * zoomFactorX).round();

      var zoomedMinX, zoomedMaxX;

      // 줌 적용된 새로운 범위 계산 (현재 범위의 끝부분 기준)
      // - 백테스팅은 과거부터 현재로
      // - 일반의 경우는 현재부터 과거로
      zoomedMinX =
          currentMaxX.subtract(Duration(milliseconds: zoomedRangeMillis));
      zoomedMaxX = currentMaxX;

      currentMinX = zoomedMinX;
      currentMaxX = zoomedMaxX;

      visibleData = candlesticks
          .where((p) =>
              p.date.difference(zoomedMinX).inMilliseconds >= 0 &&
              p.date.difference(zoomedMaxX).inMilliseconds <= 0)
          .toList();

      // 여기서 갱신하지 말것!
      // 해제하면 미친듯이 요동치는 차트를 보게 될 것임
      // if (xAxisController != null) {
      //   xAxisController!.visibleMinimum = zoomedMinX;
      //   xAxisController!.visibleMaximum = zoomedMaxX;
      // }
    } else {
      // 현재 보이는 X 범위에 맞는 데이터 필터링
      visibleData = candlesticks
          .where((p) =>
              p.date.difference(visibleMinX).inMilliseconds >= 0 &&
              p.date.difference(visibleMaxX).inMilliseconds <= 0)
          .toList();
    }

    if (visibleData.isEmpty) {
      isCustomRange = false;
      visibleData = defaultVisiblePrices;
    }

    // 2. 필터링된 데이터의 Y축 범위 계산
    if (visibleData.isNotEmpty) {
      for (int i = 0; i < visibleData.length; i++) {
        final low = visibleData[i].low;
        final high = visibleData[i].high;

        // NaN이나 Infinity 체크
        if (low.isNaN || low.isInfinite || high.isNaN || high.isInfinite) {
          continue;
        }

        minValue = math.min(minValue, low);
        maxValue = math.max(maxValue, high);
      }

      // minValue/maxValue가 여전히 초기값이면 기본값 사용
      if (minValue == double.maxFinite || maxValue == double.negativeInfinity) {
        minValue = 0;
        maxValue = 100000;
      }

      // 기본 Y축 범위 설정
      minY = minValue;
      maxY = maxValue;

      // 3. 줌 레벨에 따른 패딩 적용
      // 줌 레벨 계산 (높을수록 값이 커짐)
      final double zoomLevel = zoomFactorX;

      // 줌 레벨이 높을수록 패딩을 줄임
      final double paddingRatio = math.max(0.05, 0.2 / math.sqrt(zoomLevel));
      final double rangeHeight = maxY - minY;
      final double paddingAmount = rangeHeight * paddingRatio;

      // 패딩 적용
      maxY += paddingAmount;
      minY -= paddingAmount;

      // 4. Y축 줌 스케일 적용
      if (_yZoomScale != 1.0) {
        final center = (maxY + minY) / 2;
        final halfRange = (maxY - minY) / 2;
        final zoomedHalfRange = halfRange / _yZoomScale;

        minY = center - zoomedHalfRange;
        maxY = center + zoomedHalfRange;
      }

      // 5. 최소 범위 보장 (너무 작은 범위 방지)
      if (maxY - minY < 0.5) {
        final mid = (maxY + minY) / 2;
        maxY = mid + 0.25;
        minY = mid - 0.25;
      }
    } else {
      // 데이터가 없는 경우 기본 범위 설정
      maxY = candlesticks.last.high + 10;
      minY = candlesticks.last.low - 10;
    }

    //print('updateData: ${currentMinX.toUtcString()} ~ ${currentMaxX.toUtcString()}, minMaxY [$minY ~ $maxY]');

    // 주의: currentMinX, currentMaxX 는 updateData 이전에 세팅되는 경우가 많기 때문에
    //      그 값 변화 여부로 updateDataSource를 안하면 안된다!

    _seriesController?.updateDataSource(
      updatedDataIndex: candlesticks.length,
    );

    updatePlotBands();

    // 콜백 호출로 데이터 업데이트 알림
    onDataUpdated(true);
  }

  // NumericAxisController 또는 DateTimeAxisController을 사용
  void updatePlotBands() {
    PlotBandRenderer.clearLines();
    PlotBandRenderer.setCurrentPrice(currentPrice);

    if (yAxisController != null) {
      yAxisController!.axis.plotBands = getYPlotBands();
    }
  }

  List<PlotBand> getYPlotBands() {
    List<PlotBand> yPlotBands = [];

    yPlotBands = [
      ...PlotBandRenderer.getHorizLines(
        PlotBandRenderer.yAxisLineValues,
        PlotBandRenderer.yAxisValueTypes,
        priceColors[isPriceGoingUp ? 0 : 1],
      ),
    ];

    return yPlotBands;
  }

  void _addData(CandlestickEx data) {
    if (candlesticks.isEmpty ||
        data.date.difference(candlesticks.last.date).inSeconds > 0) {
      candlesticks.add(data);
    } else if (data.date.difference(candlesticks.first.date).inSeconds < 0) {
      candlesticks.insert(0, data);
    } else if (data.date.millisecondsSinceEpoch ==
        candlesticks.last.date.millisecondsSinceEpoch) {
      candlesticks[candlesticks.length - 1] = data;
    } else if (data.date.millisecondsSinceEpoch ==
        candlesticks.first.date.millisecondsSinceEpoch) {
      candlesticks[0] = data;
    }
  }

  void addChartData(CandlestickEx data, {bool recentData = true}) {
    _addData(data);
  }

  Future _loadOldFxData() async {
    DateTime endTime =
        candlesticks.isEmpty ? DateTime.now() : candlesticks.first.date;

    final startTime = endTime.add(Duration(
        milliseconds: -keepPriceCount * timeframeDuration[timeframe]! * 1000));

    print('_loadOldFxData: ${startTime} ~ ${endTime}');

    final items = await BinanceFuturesApi.getData(
      symbol: symbol,
      intervalType: _intervalType,
      intervalValue: _intervalValue,
      startTime: startTime,
      endTime: endTime,
    );

    for (var i = 0; i < items.length; i++) {
      addChartData(items[items.length - i - 1], recentData: false);
    }

    updateData();
  }

  Future _loadRecentData() async {
    if (candlesticks.isEmpty) return;

    final items = await BinanceFuturesApi.getData(
        symbol: symbol,
        intervalType: _intervalType,
        intervalValue: _intervalValue,
        startTime: candlesticks.last.date);

    if (items.isEmpty) return;

    for (var i = 0; i < items.length; i++) {
      addChartData(items[i], recentData: false);
    }

    if (indicators.isNotEmpty)
      _indicator.calculateRealtime(symbol, timeframe, items, candlesticks);

    updateData();
  }

  bool _isPanningInProgress = false; // 패닝 진행 중 플래그 추가

  void onActualRangeChanged(ActualRangeChangedArgs args) {
    if (args.axis!.name == 'xAxis') {
      //debugPrint('onActualRangeChanged: visible range ${utcDateText(args.visibleMin)} ~ ${utcDateText(args.visibleMax)}, custom range [$isCustomRange, ${utcDateText(currentMinX)} ~ ${utcDateText(currentMaxX)}]');

      // 패닝 중일 때는 currentMinX/MaxX 업데이트를 건너뜀
      // 이렇게 하면 순환 호출과 찔끔찔끔 움직임을 방지할 수 있음
      if (_isPanningInProgress) {
        return;
      }

      // custom range를 사용하는 경우
      // currentMinX, currentMaxX를 여기서 변경하면 차트의 zoomFactor가 커짐에도 불구하고 차트 영역이 줌인이 되거나 하는 불일치가 발생함
      // zoomFactorX가 1보다 작은 경우 (즉, 줌인인 된 경우), onActualRangeChanged가 2회 호출되는데, syncfusion chart는
      // [currentMinX, currentMaxX] 범위에 대한 zoomFactorX를 적용하려고 하기 때문에 두번 호출이 되는 것임.
      //
      // TODO:
      // zoomFactorX를 조절하는 것을 삭제하고, currentMinX, currentMaxX를 바꾸는 것으로 zoom 처리를 하는 게 좋겠음
      if (!isCustomRange) {
        currentMinX =
            DateTime.fromMillisecondsSinceEpoch(args.visibleMin.toInt());
        currentMaxX =
            DateTime.fromMillisecondsSinceEpoch(args.visibleMax.toInt());
      }
    }
  }

  // zoom 정도에 따라서 한번에 움직이는 delta 조정
  double getZoomDelta(double currentZoom) {
    if (currentZoom < 1.0) return 0.1;
    if (currentZoom < 2.0) return 0.25;
    if (currentZoom < 3.5)
      return 0.5;
    else
      return 1.0;
  }

  /// xAxisZoomFactor 설정
  void zoomInOut(bool isZoomIn) {
    double delta = getZoomDelta(zoomFactorX);
    double newZoomFactor;

    if (isZoomIn) {
      newZoomFactor = zoomFactorX - delta;
    } else {
      newZoomFactor = zoomFactorX + delta;
    }

    setZoomFactorX(newZoomFactor);
  }

  late Offset _lastPanPosition, _startPanPosition;
  Timer? _panLongPressTimer;
  double _zoomFactorOnPanStart = 0.0;
  double _yZoomScale = 1.0; // Y축 줌 스케일 추가
  double _initialYRange = 0.0; // 초기 Y축 범위

  /// 차트 제스처 이벤트 처리를 위한 콜백들
  /// - axisHeight는 하단의 40 정도로 생각하고 처리
  void onPanStart(ChartTouchInteractionArgs details, {double? axisHeight}) {
    final size = chartSize!;

    bool isInBottom = details.position.dy > (size.height - (axisHeight ?? 50));
    bool isInRight = details.position.dx > (size.width - 80); // 오른쪽 Y축 레이블 영역
    bool isInChart =
        details.position.dy < (size.height - (axisHeight ?? 50)) && !isInRight;

    // 초기에는 잠재적 모드만 설정 (실제 pan은 움직임이 있을 때 활성화)
    if (isInRight && !isInBottom) {
      _chartDragMode = ChartDragMode.YZoom; // Y축 줌 모드
      _initialYRange = maxY - minY; // 초기 Y축 범위 저장
    } else if (isInChart) {
      _chartDragMode = ChartDragMode.Pan;
    } else if (isInBottom) {
      _chartDragMode = ChartDragMode.Zoom;
    } else {
      _chartDragMode = ChartDragMode.None;
    }

    _zoomFactorOnPanStart = zoomFactorX;
    _isTrackballMode = false; // 초기에는 trackball 비활성화

    // print(
    //     'onPanStart: mode ${_chartDragMode}, zoom ${zoomFactorX}, yRange ${_initialYRange}');

    _lastPanPosition = details.position;
    _startPanPosition = details.position;

    panResetTimer?.cancel();

    // 팬 모드인 경우만
    if (_chartDragMode == ChartDragMode.Pan) {
      // pan 중에 longpress감지하는 타이머
      _panLongPressTimer?.cancel();
      _panLongPressTimer = Timer(Duration(milliseconds: 500), () {
        // 움직임이 없었다면 trackball 모드로 전환
        _isTrackballMode = true;
        _chartDragMode = ChartDragMode.None; // pan/zoom 비활성화
        print('Long press detected - switching to trackball mode');
      });
    }
  }

  void onPanUpdate(ChartTouchInteractionArgs details) {
    // trackball 모드이거나 dragMode가 None이면 pan/zoom 동작 안함
    if (_isTrackballMode ||
        _chartDragMode == ChartDragMode.None ||
        candlesticks.isEmpty) return;

    // delta 직접 계산
    final deltaX = details.position.dx - _lastPanPosition.dx;
    final deltaY = details.position.dy - _lastPanPosition.dy;
    _lastPanPosition = details.position;

    if (_chartDragMode == ChartDragMode.Pan) {
      // 움직인 이동 거리가 충분히 길면 롱프레스 타이머 캔슬 (trackball 모드 방지)
      if (math.max((details.position.dx - _startPanPosition.dx).abs(),
              (details.position.dy - _startPanPosition.dy).abs()) >
          10) {
        _panLongPressTimer?.cancel();
        _isTrackballMode = false; // 움직임이 있으면 trackball 모드 해제
      }
    }

    if (isPanning) {
      _adjustVisibleRange(deltaX);
    } else if (isZooming) {
      // 터치/마우스 이동
      // - 왼쪽 이동: 줌아웃
      // - 오른쪽 이동: 줌인
      final delta = (deltaX / (chartSize!.width - 100)) * 2;
      setZoomFactorX(zoomFactorX - delta);
    } else if (isYZooming) {
      // Y축 줌: 위로 드래그하면 줌인, 아래로 드래그하면 줌아웃
      final zoomDelta = deltaY / 100.0; // 감도 조절
      _yZoomScale = (_yZoomScale + zoomDelta).clamp(0.5, 3.0); // 0.5배 ~ 3배 제한

      // updateData에서 Y축 범위를 재계산하도록 호출
      updateData();
    }
  }

  /// visible range를 deltaX에 따라 조정 (pan 로직)
  void _adjustVisibleRange(double deltaX) {
    if (candlesticks.isEmpty) return;

    // 패닝 시작을 표시
    _isPanningInProgress = true;

    // 화면 크기 가져오기
    final chartSize = this.chartSize!;

    // deltaX를 시간 단위로 변환
    final visibleRangeMillis =
        visibleMaxX.difference(visibleMinX).inMilliseconds;
    final chartWidth = chartSize.width - 100; // 여백 제외

    // deltaX 1픽셀당 시간 변화량 계산
    final millisPerPixel = visibleRangeMillis / chartWidth;
    final timeDeltaMillis = (-deltaX * millisPerPixel).round();

    // 새로운 visible range 계산
    DateTime newMinX = (isCustomRange ? currentMinX : visibleMinX)
        .add(Duration(milliseconds: timeDeltaMillis));

    // pan을 시작할 때의 zoomFactor를 사용해서 newMaxX 갱신
    DateTime newMaxX = (isCustomRange ? currentMaxX : visibleMaxX).add(Duration(
        milliseconds: (timeDeltaMillis * _zoomFactorOnPanStart).ceil()));

    // debugPrint(
    //     '_adjustVisibleRange: deltaX=$deltaX, timeDelta=${timeDeltaMillis}ms, newMinX ${newMinX.toUtcString()}, zoomFactor ${zoomFactorX}');

    // 데이터 범위 제한 확인
    final dataStartTime = candlesticks.first.date;
    final dataEndTime = DateTime.now().add(dateMarginX[_timeframeIndex]);

    // 왼쪽 경계 제한 (과거 데이터 끝)
    if (newMinX.isBefore(dataStartTime)) {
      final diff = dataStartTime.difference(newMinX);
      newMinX = dataStartTime;
      newMaxX = newMaxX.add(diff); // 범위 크기 유지

      _loadOldFxData();
    }

    // 오른쪽 경계 제한 (백테스팅이 아닌 경우만)
    if (newMaxX.isAfter(dataEndTime)) {
      final diff = newMaxX.difference(dataEndTime);
      newMaxX = dataEndTime;
      newMinX = newMinX.subtract(diff); // 범위 크기 유지
    }

    // 범위가 바뀐 경우에 대해서만 updateData를 호출
    if (currentMinX != newMinX || currentMaxX != newMaxX) {
      currentMinX = newMinX;
      currentMaxX = newMaxX;

      isCustomRange = currentMaxX.millisecondsSinceEpoch <
          candlesticks.last.date.millisecondsSinceEpoch;

      // 축 범위 설정 (이것이 실제 pan 효과를 만듦)
      // NOTE: visibleMinimum/visibleMaximum은 deprecated되어 제거됨
      // currentMinX/currentMaxX가 차트 위젯의 minimum/maximum에 자동 반영됨

      // debugPrint(
      //     '_adjustVisibleRange: new range [${newMinX.toUtcString()} ~ ${newMinX.toUtcString()}], isCustomRange $isCustomRange');

      // 차트 업데이트
      updateData();
    }

    // 패닝 완료를 표시
    _isPanningInProgress = false;
  }

  bool isAtBoundary({bool isLeft = true}) {
    if (isLeft) {
      // 현재 보이는 범위가 데이터 시작점에 가까운지 체크
      final visibleStart = isCustomRange ? currentMinX : visibleMinX;
      final dataStart = candlesticks.first.date;

      // 5개 캔들 간격 이하로 가까우면 true
      return visibleStart.difference(dataStart).inMilliseconds <
          (timeframeDuration[timeframe]! * 5);
    } else {
      // 현재 보이는 범위가 데이터 시작점에 가까운지 체크
      final visibleEnd =
          (isCustomRange ? currentMaxX : visibleMaxX).millisecondsSinceEpoch;
      final dataEnd = math.min(candlesticks.last.date.millisecondsSinceEpoch,
          DateTime.timestamp().millisecondsSinceEpoch);

      // 5개 캔들 간격 이하로 가까우면 true
      return (dataEnd - visibleEnd) < (timeframeDuration[timeframe]! * 5);
    }
  }

  void onPanEnd(ChartTouchInteractionArgs details) {
    // trackball 모드가 아닌 경우에만 pan 관련 처리
    if (!_isTrackballMode && _chartDragMode != ChartDragMode.None) {
      //debugPrint('onPanEnd: new range [$currentMinX ~ $currentMaxX]');

      // 60초 후 자동 리셋 타이머 시작
      if (isCustomRange) {
        panResetTimer?.cancel();
        panResetTimer = Timer(Duration(seconds: 60), () {
          resetToDefaultRange();
        });
      }
    }

    // Y축 줌이 끝났을 때 스케일 리셋 옵션 (필요시)
    if (_chartDragMode == ChartDragMode.YZoom) {
      // 더블탭으로 리셋하려면 여기에 로직 추가 가능
    }

    // 모든 모드 리셋
    _chartDragMode = ChartDragMode.None;
    _isTrackballMode = false;
    _panLongPressTimer?.cancel();
  }

  Timer? panResetTimer;

  // zoomFactorX 설정
  // 0.1 = 최대 줌인 (적게 보임)
  // 5 = 최대 줌아웃 (많이 보임)
  void setZoomFactorX(double xValue, {double zoomPosition = 1.0}) {
    xValue = xValue.clamp(0.1, 5);
    if (xAxisController?.zoomFactor == xValue) return;

    print('setZoomFactorX: ${xAxisController?.zoomFactor} => ${xValue}');

    xAxisController?.zoomFactor = xValue;
    xAxisController?.zoomPosition = (1 - xValue) * zoomPosition;

    updateData();
  }

  void onTrackballPositionChanging(TrackballArgs args) {
    // TODO: 이거 선택된 시간으로 변경
    final selectTimeMillis = DateTime.now().millisecondsSinceEpoch;

    int visibleRangeInMillis =
        visibleMaxX.millisecondsSinceEpoch - visibleMinX.millisecondsSinceEpoch;
    int marginInMillis = (visibleRangeInMillis * 0.1).toInt();

    // 여백 제외한 차트 폭
    final chartWidth = chartSize!.width - 100;

    // 오른쪽으로 5% 정도 남겨둔 상태
    if (visibleMaxX.millisecondsSinceEpoch - selectTimeMillis <
        marginInMillis) {
      _adjustVisibleRange(-chartWidth * 0.1);
    }
    // 왼쪽으로 5% 정도 남겨둔 상태
    else if (selectTimeMillis - visibleMinX.millisecondsSinceEpoch <
        marginInMillis) {
      _adjustVisibleRange(chartWidth * 0.1);
    }
  }

  void setCurrentX(DateTime date) {
    if (date.millisecondsSinceEpoch <
        candlesticks.first.openTime.millisecondsSinceEpoch)
      date = candlesticks.first.openTime;

    currentMinX = date;

    updateData();
  }

  void setMakeVisible(DateTime value) {
    int millisRange =
        currentMaxX.millisecondsSinceEpoch - currentMinX.millisecondsSinceEpoch;

    // 위치를 가운데 놔줌
    setCurrentX(DateTime.fromMillisecondsSinceEpoch(
        value.millisecondsSinceEpoch - millisRange ~/ 2));

    onDataUpdated(true);
  }

  /// Y축 줌 리셋
  void resetYZoom() {
    _yZoomScale = 1.0;
    updateData();
  }

  List<CartesianChartAnnotation> getAnnots() {
    if (chartSize == null) return [];

    List<CartesianChartAnnotation> annots = [];
    for (var i = 0; i < PlotBandRenderer.yAxisLineValues.length; i++) {
      final valueType = PlotBandRenderer.yAxisValueTypes[i];

      Color? color;
      String text = '';
      if (valueType == 'current') {
        text = '${PlotBandRenderer.yAxisLineValues[i].toStringAsFixed(3)}';
        color = priceColors[isPriceGoingUp ? 0 : 1];
      } else if (valueType == 'entry') {
        text = 'Entry P.';
        color = Colors.grey;
      } else if (valueType == 'bust') {
        text = 'Bust P.';
        color = Colors.red;
      }

      annots.add(
        CartesianChartAnnotation(
          widget: Container(
            width: 80,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                topLeft: Radius.circular(10),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
          ),
          x: visibleMaxX,
          y: PlotBandRenderer.yAxisLineValues[i],
          horizontalAlignment: ChartAlignment.near,
          coordinateUnit: CoordinateUnit.point,
        ),
      );
    }

    return annots;
  }
}
