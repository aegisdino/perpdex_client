import 'package:flutter/material.dart';

/// 차트 축의 줌인/줌아웃을 관리하는 컨트롤러
class AxisZoomController {
  // 콜백 함수 정의
  final Function(double yZoomFactor, double yZoomPosition) onYAxisZoom;
  final Function(double xZoomFactor, double xZoomPosition) onXAxisZoom;

  // 제스처 관련 상태 변수
  double _startDragPos = 0;

  bool _isDraggingYAxis = false;
  bool _isDraggingXAxis = false;

  // 줌 상태 변수
  double _currentYZoomFactor = 1.0;
  double _currentYZoomPosition = 0.0;

  double _currentXZoomFactor = 1.0;
  double _currentXZoomPosition = 0.0;

  double _startZoomFactor = 0;

  // 설정 변수
  final double _minZoomFactor;
  final double _maxZoomFactorX;
  final double _maxZoomFactorY;
  final double _zoomSensitivity;

  // 차트 사이즈 getter
  Size Function()? getChartSize;

  bool get isDragging => _isDraggingYAxis || _isDraggingXAxis;
  bool get isDraggingX => _isDraggingXAxis;

  /// 생성자
  AxisZoomController({
    required this.onYAxisZoom,
    required this.onXAxisZoom,
    this.getChartSize,
    double minZoomFactor = 0.1,
    double maxZoomFactorX = 2.0,
    double maxZoomFactorY = 2.0,
    double zoomSensitivity = 1.0,
  })  : _minZoomFactor = minZoomFactor,
        _maxZoomFactorX = maxZoomFactorX,
        _maxZoomFactorY = maxZoomFactorY,
        _zoomSensitivity = zoomSensitivity;

  /// 현재 줌 상태 설정
  void setCurrentZoomState({
    double? yZoomFactor,
    double? yZoomPosition,
    double? xZoomFactor,
    double? xZoomPosition,
  }) {
    if (yZoomFactor != null) _currentYZoomFactor = yZoomFactor;
    if (yZoomPosition != null) _currentYZoomPosition = yZoomPosition;
    if (xZoomFactor != null) _currentXZoomFactor = xZoomFactor;
    if (xZoomPosition != null) _currentXZoomPosition = xZoomPosition;
  }

  Size? get chartSize => getChartSize?.call();

  /// 터치 시작 처리
  void handlePanStart(DragDownDetails details, bool isYAxisArea) {
    final Size? size = chartSize;
    if (chartSize == null) return;

    final localPosition = details.localPosition;

    // Y축 영역인지 확인
    if (isYAxisArea) {
      _isDraggingYAxis = true;
      _startDragPos = localPosition.dy;
      _startZoomFactor = _currentYZoomFactor;
      _currentYZoomPosition = (size!.height - _startDragPos) / size.height;
    }
    // X축 영역인지 확인
    else {
      _isDraggingXAxis = true;
      _startDragPos = localPosition.dx;
      _startZoomFactor = _currentXZoomFactor;
      _currentXZoomPosition = _startDragPos / size!.width;
    }
  }

  /// 패닝 업데이트 처리
  void handlePanUpdate(DragUpdateDetails details) {
    final Size size = chartSize!;
    // Y축 드래그 처리
    if (_isDraggingYAxis) {
      // 위가 0, 아래로 커짐
      // 터치를 위로 올리면 줌인, 아래로 내리면 줌아웃
      // deltaY: 음수 = 줌인, 양수 = 줌아웃
      // 줌인: 줌팩터가 작아짐, 줌아웃: 줌팩터가 커짐
      final double currentDragDeltaY = details.localPosition.dy - _startDragPos;

      // 차트 높이에 대한 비율 계산
      // ratio가 커지면 줌아웃, ratio가 작아지면 줌인
      final double ratio = currentDragDeltaY /
          (currentDragDeltaY > 0
              ? (size.height - _startDragPos)
              : _startDragPos);

      // 줌 팩터 및 포지션 업데이트
      _updateYZoom(ratio);
    }
    // X축 드래그 처리
    else if (_isDraggingXAxis) {
      // 왼쪽은 줌아웃, 오른쪽은 줌인
      // deltaX: 음수 = 줌인, 양수 = 줌아웃
      final double currentDragDeltaX = details.localPosition.dx - _startDragPos;

      // 차트 너비에 대한 비율 계산
      final double ratio = currentDragDeltaX /
          (currentDragDeltaX < 0
              ? (size.width - _startDragPos)
              : _startDragPos);

      print('$currentDragDeltaX, $ratio');
      // 줌 팩터 및 포지션 업데이트
      _updateXZoom(ratio * _zoomSensitivity * 2);
    }
  }

  double _getNewZoomFactor(double zoomChange, double maxVal) {
    double newZoomFactor = _startZoomFactor * (1 + zoomChange);
    return newZoomFactor.clamp(_minZoomFactor, maxVal);
  }

  /// Y축 줌 업데이트
  /// - zoomChange가 음수면 줌인, 양수면 줌아웃
  void _updateYZoom(double zoomChange) {
    _currentXZoomFactor = _getNewZoomFactor(zoomChange, _maxZoomFactorY);
    onYAxisZoom(_currentXZoomFactor, _currentYZoomPosition);
  }

  /// X축 줌 업데이트
  /// - zoomChange가 음수면 줌인, 양수면 줌아웃
  void _updateXZoom(double zoomChange) {
    _currentXZoomFactor = _getNewZoomFactor(zoomChange, _maxZoomFactorX);
    onXAxisZoom(_currentXZoomFactor, _currentXZoomPosition);
  }

  /// 패닝 종료 처리
  void handlePanEnd(DragEndDetails details) {
    _isDraggingYAxis = false;
    _isDraggingXAxis = false;
  }

  /// 리소스 정리
  void dispose() {
    // 특별히 해제할 리소스가 없음
  }
}
