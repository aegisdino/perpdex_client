import 'package:flutter/material.dart';

class RiskSliderView extends StatefulWidget {
  final double initialMultiplier;
  final Function(double)? onChanged;

  const RiskSliderView({
    required this.initialMultiplier,
    this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  State<RiskSliderView> createState() => _RiskSliderViewState();
}

class _RiskSliderViewState extends State<RiskSliderView> {
  // 특정 단계의 배율 목록
  final List<int> multiplierSteps = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000];

  // 현재 선택된 배율 값 (기본값은 첫 번째 단계)
  double _currentMultiplier = 1;

  // 슬라이더 값 (0.0~1.0 사이)
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentMultiplier = widget.initialMultiplier;
    _updateSliderValue();
  }

  @override
  void didUpdateWidget(RiskSliderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMultiplier != widget.initialMultiplier) {
      _currentMultiplier = widget.initialMultiplier;
      _updateSliderValue();
    }
  }

  // 현재 배율에 따라 슬라이더 값 업데이트
  void _updateSliderValue() {
    // 정확히 단계값인 경우
    if (multiplierSteps.contains(_currentMultiplier.toInt())) {
      _sliderValue = multiplierSteps.indexOf(_currentMultiplier.toInt()) /
          (multiplierSteps.length - 1);
    } else {
      // 단계 사이의 값인 경우, 알맞은 위치 계산
      int lowerIndex = 0;
      int upperIndex = 0;

      // 적절한 범위 찾기
      for (int i = 0; i < multiplierSteps.length - 1; i++) {
        if (_currentMultiplier >= multiplierSteps[i] &&
            _currentMultiplier <= multiplierSteps[i + 1]) {
          lowerIndex = i;
          upperIndex = i + 1;
          break;
        }
      }

      // 단계 사이에서의 상대적 위치 계산
      double lowerValue = multiplierSteps[lowerIndex].toDouble();
      double upperValue = multiplierSteps[upperIndex].toDouble();
      double t = (_currentMultiplier - lowerValue) / (upperValue - lowerValue);

      // 슬라이더 값 계산
      _sliderValue = (lowerIndex + t) / (multiplierSteps.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Custom Gradient Slider
        SizedBox(
          height: 12,
          child: CustomRiskSlider(
            value: _sliderValue,
            steps: multiplierSteps,
            onChanged: (value, isThumb) {
              setState(() {
                _sliderValue = value;

                if (isThumb) {
                  // thumb 드래그: 9단계로 스냅
                  int index = (value * (multiplierSteps.length - 1)).round();
                  _currentMultiplier = multiplierSteps[index].toDouble();
                } else {
                  // 트랙 클릭: 단계 사이를 선형 보간(lerp)
                  double exactIndex = value * (multiplierSteps.length - 1);
                  int lowerIndex = exactIndex.floor();
                  int upperIndex = exactIndex.ceil();

                  if (lowerIndex == upperIndex) {
                    _currentMultiplier = multiplierSteps[lowerIndex].toDouble();
                  } else {
                    double t = exactIndex - lowerIndex;
                    double lowerValue = multiplierSteps[lowerIndex].toDouble();
                    double upperValue = multiplierSteps[upperIndex].toDouble();
                    _currentMultiplier =
                        lowerValue + (upperValue - lowerValue) * t;
                  }
                }

                // 기존 콜백 호출 유지
                widget.onChanged?.call(_currentMultiplier);
              });
            },
          ),
        ),

        const SizedBox(height: 20),

        // 배율 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('x1 · ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'Safe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 10, 249, 18),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Wild',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 253, 31, 15),
                  ),
                ),
                Text(' · x1000', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class CustomRiskSlider extends StatefulWidget {
  final double value;
  final Function(double, bool) onChanged; // isThumb 매개변수 추가
  final List<int> steps;

  const CustomRiskSlider({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.steps,
  }) : super(key: key);

  @override
  State<CustomRiskSlider> createState() => _CustomRiskSliderState();
}

class _CustomRiskSliderState extends State<CustomRiskSlider> {
  bool _isDraggingThumb = false;

  // thumb 위치 계산 함수
  Rect _getThumbRect() {
    final double thumbRadius = 30.0;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final double width = box.size.width;
    final double thumbCenterX = widget.value * width;

    return Rect.fromCircle(
        center: Offset(thumbCenterX, box.size.height / 2), radius: thumbRadius);
  }

  // 포인터가 thumb 영역 내에 있는지 확인하는 함수
  bool _isPointInThumb(Offset localPosition) {
    final Rect thumbRect = _getThumbRect();
    return thumbRect.contains(localPosition);
  }

  void onTapDown(TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = details.localPosition;

    // Thumb을 누른 경우는 여기서 처리하지 않음
    if (_isPointInThumb(localPosition)) {
      setState(() {
        _isDraggingThumb = true;
      });
      return;
    }

    final double dx = localPosition.dx.clamp(0.0, box.size.width);
    final double newValue = dx / box.size.width;
    widget.onChanged(newValue, false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            // 그라데이션 배경
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [
                    Colors.green,
                    Color(0xFFCCFF00), // 연두색
                    Colors.yellow,
                    Colors.orange,
                    Colors.red,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            // 슬라이더 위젯
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 15,
                  elevation: 5,
                ),
                thumbSize: WidgetStateProperty.all(Size(60.0, 30.0)),
                overlayColor: Colors.white.withAlpha(60),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 25),
                padding: EdgeInsets.zero,
              ),
              child: Listener(
                onPointerDown: (event) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition =
                      box.globalToLocal(event.position);

                  if (_isPointInThumb(localPosition)) {
                    setState(() {
                      _isDraggingThumb = true;
                    });
                  }
                },
                onPointerUp: (event) {
                  setState(() {
                    _isDraggingThumb = false;
                  });
                },
                child: Slider(
                  value: widget.value,
                  onChanged: (newValue) {
                    if (_isDraggingThumb) {
                      // Thumb 드래그 시 단계로 스냅
                      int index =
                          (newValue * (widget.steps.length - 1)).round();
                      double snappedValue = index / (widget.steps.length - 1);
                      widget.onChanged(snappedValue, true);
                    } else {
                      // 일반 클릭 또는 탭 (isThumb = false)
                      widget.onChanged(newValue, false);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
