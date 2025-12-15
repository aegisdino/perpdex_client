import 'dart:async';

import 'package:flutter/material.dart';

/// 차트의 관성 스크롤을 관리하는 컨트롤러
class ChartPanScrollController {
  // 콜백 함수 정의
  final Function(double ratio) onScrollRatio;
  final Function(bool isReset) onScrollEnd;
  final Function() onDataLoadRequest;
  final bool Function() isAtNewestData;
  final bool Function() isAtOldestData;

  // 제스처 관련 상태 변수
  double _startDragX = 0;
  double _lastDragDeltaX = 0;
  bool _isDragging = false;

  bool get isDragging => _isDragging;

  // 관성 스크롤 관련 변수
  Timer? _inertialScrollTimer;
  double _scrollVelocity = 0.0;
  DateTime _lastDragTime = DateTime.now();
  List<double> _recentVelocities = [];

  // 설정 변수
  final int _velocitySampleCount; // 속도 샘플 개수
  final double _velocityDecay; // 관성 감소율 (값이 클수록 오래 지속)
  final double _minVelocity; // 스크롤 중지 기준 최소 속도
  final Duration _resetTimerDuration; // 자동 리셋 타이머 기간

  Timer? _resetTimer;
  bool _isEnabled = true;

  // 차트 사이즈 getter
  Size? Function()? getChartSize;

  /// 생성자
  ChartPanScrollController({
    required this.onScrollRatio,
    required this.onScrollEnd,
    required this.onDataLoadRequest,
    required this.isAtNewestData,
    required this.isAtOldestData,
    this.getChartSize,
    int velocitySampleCount = 5,
    double velocityDecay = 0.95,
    double minVelocity = 0.1,
    Duration? resetTimerDuration,
  })  : _velocitySampleCount = velocitySampleCount,
        _velocityDecay = velocityDecay,
        _minVelocity = minVelocity,
        _resetTimerDuration = resetTimerDuration ?? Duration(seconds: 60);

  /// 활성화/비활성화 설정
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _inertialScrollTimer?.cancel();
      _resetTimer?.cancel();
    }
  }

  /// 제스처로 차트를 패닝하는 메서드
  void handlePanStart(DragDownDetails details) {
    if (!_isEnabled) return;

    // 기존 관성 스크롤 중지
    _inertialScrollTimer?.cancel();

    _isDragging = true;
    _startDragX = details.localPosition.dx;
    _lastDragDeltaX = 0;
    _lastDragTime = DateTime.now();
    _recentVelocities.clear();
  }

  /// 패닝 업데이트 처리
  void handlePanUpdate(DragUpdateDetails details) {
    if (!_isEnabled || !_isDragging) return;

    // 차트 크기 확인
    final Size? size = getChartSize?.call();
    if (size == null) return;

    final double chartWidth = size.width;

    // 현재 드래그 델타 계산
    final double currentDragDeltaX =
        details.localPosition.dx - _startDragX - _lastDragDeltaX;

    // 속도 계산을 위한 시간 측정
    final DateTime now = DateTime.now();
    final int millisElapsed = now.difference(_lastDragTime).inMilliseconds;

    if (millisElapsed > 0) {
      // 픽셀/밀리초 단위의 속도 계산
      double velocity = currentDragDeltaX / millisElapsed;

      // 속도 샘플 저장 (최근 N개만 유지)
      _recentVelocities.add(velocity);
      if (_recentVelocities.length > _velocitySampleCount) {
        _recentVelocities.removeAt(0);
      }

      _lastDragTime = now;
    }

    _lastDragDeltaX += currentDragDeltaX;

    // 차트 이동 비율 계산
    final double ratio = currentDragDeltaX / chartWidth;

    // 비율이 0이면 무시
    if (ratio == 0) return;

    // 경계 확인
    if (ratio > 0 && isAtOldestData()) {
      onDataLoadRequest();
    } else if (ratio < 0 && isAtNewestData()) {
      onScrollEnd(true); // 최신 데이터로 리셋
    } else {
      // 스크롤 비율을 콜백 함수로 전달
      onScrollRatio(ratio);
    }
  }

  /// 패닝 종료 처리
  void handlePanEnd(DragEndDetails details) {
    if (!_isEnabled || !_isDragging) return;

    _isDragging = false;

    // 마지막 속도 계산 (최근 샘플의 평균)
    if (_recentVelocities.isNotEmpty) {
      _scrollVelocity =
          _recentVelocities.reduce((a, b) => a + b) / _recentVelocities.length;

      // 속도가 충분히 빠르면 관성 스크롤 시작
      if (_scrollVelocity.abs() > _minVelocity) {
        _startInertialScroll();
      }
    }

    onScrollEnd(false); // 패닝 종료 후 차트 업데이트 강제 실행 (리셋하지 않음)
  }

  /// 관성 스크롤 시작
  void _startInertialScroll() {
    if (!_isEnabled) return;

    // 기존 타이머 정리
    _inertialScrollTimer?.cancel();

    // 매 프레임마다 스크롤 수행 (약 60fps)
    _inertialScrollTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      // 속도가 최소값보다 작아지면 스크롤 중지
      if (_scrollVelocity.abs() < _minVelocity) {
        timer.cancel();
        return;
      }

      // 속도 감소
      _scrollVelocity *= _velocityDecay;

      // 차트 크기 확인
      final Size? size = getChartSize?.call();
      if (size == null) {
        timer.cancel();
        return;
      }

      final double chartWidth = size.width;
      final double dragDeltaX = _scrollVelocity * 16; // 프레임당 이동 거리

      // 차트 이동 비율 계산
      final double ratio = dragDeltaX / chartWidth;

      // 경계 확인
      if (ratio > 0 && isAtOldestData()) {
        onDataLoadRequest();
        if (_scrollVelocity > 0) {
          // 과거 데이터를 로드할 때 속도 감소
          _scrollVelocity *= 0.8;
        }
        return;
      }

      if (ratio < 0 && isAtNewestData()) {
        timer.cancel();
        onScrollEnd(true); // 최신 데이터로 리셋
        return;
      }

      // 스크롤 비율을 콜백 함수로 전달
      onScrollRatio(ratio);
    });

    // 자동 리셋 타이머 설정
    _resetTimer?.cancel();
    _resetTimer = Timer(_resetTimerDuration, () {
      onScrollEnd(true); // 자동 리셋
    });
  }

  /// 리소스 정리
  void dispose() {
    _inertialScrollTimer?.cancel();
    _resetTimer?.cancel();
  }

  /// 관성 스크롤 즉시 중지
  void stopScroll() {
    _inertialScrollTimer?.cancel();
    _scrollVelocity = 0.0;
  }
}
