import 'package:flutter/material.dart';

/// 호가창 표시 모드 아이콘 위젯들
/// 3가지 표시 모드: 매도만/전체/매수만

enum OrderbookDisplayMode {
  /// 매도 호가만 표시 (빨간색 위쪽)
  askOnly,

  /// 매도 + 매수 호가 모두 표시 (빨간색 + 초록색)
  both,

  /// 매수 호가만 표시 (초록색 아래쪽)
  bidOnly,
}

class OrderbookDisplayModeIcon extends StatelessWidget {
  final OrderbookDisplayMode mode;
  final Color? askColor;
  final Color? bidColor;
  final double size;

  const OrderbookDisplayModeIcon({
    super.key,
    required this.mode,
    this.askColor,
    this.bidColor,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OrderbookDisplayModePainter(
          mode: mode,
          askColor: askColor ?? const Color(0xFFEF5350),
          bidColor: bidColor ?? const Color(0xFF26A69A),
        ),
      ),
    );
  }
}

class _OrderbookDisplayModePainter extends CustomPainter {
  final OrderbookDisplayMode mode;
  final Color askColor;
  final Color bidColor;

  _OrderbookDisplayModePainter({
    required this.mode,
    required this.askColor,
    required this.bidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case OrderbookDisplayMode.askOnly:
        _drawAskOnly(canvas, size);
        break;
      case OrderbookDisplayMode.both:
        _drawBoth(canvas, size);
        break;
      case OrderbookDisplayMode.bidOnly:
        _drawBidOnly(canvas, size);
        break;
    }
  }

  /// 매도만 표시 (왼쪽: 긴 사각형, 오른쪽: 작은 사각형들)
  void _drawAskOnly(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final askStrokePaint = Paint()
      ..color = askColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final linePaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;

    final leftWidth = (width - 2) * 0.5;

    // 왼쪽: 긴 빨간색 사각형 outline (전체 높이)
    canvas.drawRect(
      Rect.fromLTWH(2, 2, leftWidth - 2, height - 4),
      askStrokePaint,
    );

    // 오른쪽 영역: 4개의 작은 사각형 (6x3)
    final rectWidth = width - leftWidth - 2;
    final rectHeight = 4.0;
    final spacing = (height - (rectHeight * 3)) / 4;

    for (int i = 0; i < 3; i++) {
      final y = spacing + i * (rectHeight + spacing);
      canvas.drawRect(
        Rect.fromLTWH(leftWidth + 2, y, rectWidth, rectHeight),
        linePaint,
      );
    }

    // 외곽선
    final borderPaint = Paint()
      ..color = askColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      borderPaint,
    );
  }

  /// 전체 표시 (왼쪽: 매도/매수 사각형, 오른쪽: 긴 사각형들)
  void _drawBoth(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final askStrokePaint = Paint()
      ..color = askColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bidStrokePaint = Paint()
      ..color = bidColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final linePaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;

    // 왼쪽 영역 너비 (전체의 30%)
    final leftWidth = (width - 2) * 0.5;
    final squareSize = 6.0;

    // 왼쪽 상단: 매도 사각형 outline (6x6)
    canvas.drawRect(
      Rect.fromLTWH(2, 2, squareSize, squareSize),
      askStrokePaint,
    );

    // 왼쪽 하단: 매수 사각형 outline (6x6)
    canvas.drawRect(
      Rect.fromLTWH(2, height - squareSize - 2, squareSize, squareSize),
      bidStrokePaint,
    );

    // 오른쪽 영역: 4개의 긴 사각형 (6x3)
    final rectWidth = width - leftWidth - 2;
    final rectHeight = 3.0;
    final spacing = (height - (rectHeight * 4)) / 5; // 5개 간격 (위아래 + 사이 3개)

    for (int i = 0; i < 4; i++) {
      final y = spacing + i * (rectHeight + spacing);
      canvas.drawRect(
        Rect.fromLTWH(leftWidth + 2, y, rectWidth, rectHeight),
        linePaint,
      );
    }

    // 외곽선
    final borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      borderPaint,
    );
  }

  /// 매수만 표시 (왼쪽: 긴 사각형, 오른쪽: 작은 사각형들)
  void _drawBidOnly(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final bidStrokePaint = Paint()
      ..color = bidColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final linePaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;

    // 왼쪽 영역 너비 (전체의 60% - 2배로 증가)
    final leftWidth = (width - 2) * 0.5;

    // 왼쪽: 긴 초록색 사각형 outline (전체 높이)
    canvas.drawRect(
      Rect.fromLTWH(2, 2, leftWidth - 2, height - 4),
      bidStrokePaint,
    );

    // 오른쪽 영역: 4개의 작은 사각형 (6x3)
    final rectWidth = width - leftWidth - 2;
    final rectHeight = 4.0;
    final spacing = (height - (rectHeight * 3)) / 4;

    for (int i = 0; i < 3; i++) {
      final y = spacing + i * (rectHeight + spacing);
      canvas.drawRect(
        Rect.fromLTWH(leftWidth + 2, y, rectWidth, rectHeight),
        linePaint,
      );
    }

    // 외곽선
    final borderPaint = Paint()
      ..color = bidColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 호가창 표시 모드 선택 버튼
class OrderbookDisplayModeButton extends StatelessWidget {
  final OrderbookDisplayMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const OrderbookDisplayModeButton({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        opacity: isSelected ? 1 : 0.5,
        child: OrderbookDisplayModeIcon(
          mode: mode,
          size: 18,
        ),
      ),
    );
  }
}

/// 호가창 표시 모드 선택기
class OrderbookDisplayModeSelector extends StatefulWidget {
  final OrderbookDisplayMode initialMode;
  final bool showFullList;
  final Function(OrderbookDisplayMode)? onModeChanged;

  const OrderbookDisplayModeSelector({
    super.key,
    this.initialMode = OrderbookDisplayMode.both,
    this.showFullList = true,
    this.onModeChanged,
  });

  @override
  State<OrderbookDisplayModeSelector> createState() =>
      _OrderbookDisplayModeSelectorState();
}

class _OrderbookDisplayModeSelectorState
    extends State<OrderbookDisplayModeSelector> {
  late OrderbookDisplayMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return widget.showFullList
        ? Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              OrderbookDisplayMode.both,
              OrderbookDisplayMode.askOnly,
              OrderbookDisplayMode.bidOnly,
            ]
                .map((e) => OrderbookDisplayModeButton(
                      mode: e,
                      isSelected: _selectedMode == e,
                      onTap: () {
                        setState(() {
                          _selectedMode = e;
                        });
                        widget.onModeChanged?.call(e);
                      },
                    ))
                .toList(),
          )
        : _buildDropdown();
  }

  Widget _buildDropdown() {
    return OrderbookDisplayModeButton(
      mode: _selectedMode,
      isSelected: true,
      onTap: () {},
    );
  }
}
