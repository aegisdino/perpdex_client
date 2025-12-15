import 'package:flutter/material.dart';

import '../../../common/theme.dart';
import 'panel_type.dart';

/// 드래그 가능한 패널 위젯
class DraggablePanel extends StatefulWidget {
  final PanelData panelData;
  final Widget child;
  final VoidCallback? onRemove;
  final Function(PanelData)? onUpdate;
  final bool isDraggable;
  final bool showHeader;

  const DraggablePanel({
    super.key,
    required this.panelData,
    required this.child,
    this.onRemove,
    this.onUpdate,
    this.isDraggable = true,
    this.showHeader = true,
  });

  @override
  State<DraggablePanel> createState() => _DraggablePanelState();
}

class _DraggablePanelState extends State<DraggablePanel> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161A1E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _isHovering
                ? Colors.grey.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // 헤더 (드래그 핸들, 타이틀, 액션)
            if (widget.showHeader) _buildHeader(),

            // 패널 내용
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 36,
      child: Row(
        children: [
          // 드래그 핸들
          if (widget.isDraggable)
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Draggable<PanelData>(
                data: widget.panelData,
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.dexSecondary,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_indicator,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.panelData.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.5,
                  child: _buildHeaderContent(),
                ),
                child: _buildHeaderContent(),
              ),
            )
          else
            _buildHeaderContent(),

          const Spacer(),

          // 액션 버튼
          _buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isDraggable)
            const Icon(
              Icons.drag_indicator,
              color: Colors.grey,
              size: 16,
            ),
          if (widget.isDraggable) const SizedBox(width: 8),
          Text(
            widget.panelData.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 최소화/최대화
        IconButton(
          icon: const Icon(Icons.minimize, size: 16),
          color: Colors.grey,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () {
            // TODO: 최소화 기능
          },
          tooltip: '최소화',
        ),

        // 설정
        IconButton(
          icon: const Icon(Icons.settings, size: 16),
          color: Colors.grey,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () {
            // TODO: 패널 설정
          },
          tooltip: '설정',
        ),

        // 닫기
        if (widget.onRemove != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onRemove,
            tooltip: '닫기',
          ),

        const SizedBox(width: 4),
      ],
    );
  }
}

/// 크기 조정 가능한 패널 위젯
class ResizablePanel extends StatefulWidget {
  final PanelData panelData;
  final Widget child;
  final VoidCallback? onRemove;
  final Function(int newWidth, int newHeight)? onResize;
  final VoidCallback? onResizeEnd;
  final double gridWidth;
  final double gridHeight;
  final Widget? headerAction; // 헤더에 추가할 위젯 (예: 드롭다운)
  final bool allowMove; // 이동 허용 여부

  const ResizablePanel({
    super.key,
    required this.panelData,
    required this.child,
    required this.gridWidth,
    required this.gridHeight,
    this.onRemove,
    this.onResize,
    this.onResizeEnd,
    this.headerAction,
    this.allowMove = true,
  });

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  bool _isFocused = false;
  bool _isResizing = false;
  double _startWidth = 0;
  double _startHeight = 0;
  double _currentWidth = 0;
  double _currentHeight = 0;
  int? _tempWidth;
  int? _tempHeight;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isFocused = true);
      },
      onExit: (_) {
        setState(() => _isFocused = false);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 메인 패널 컨텐츠
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isFocused || _isResizing
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: widget.child,
          ),

          // 상단 드래그 영역 (전체 너비, 높이 10px) - allowMove가 true일 때만
          if (widget.allowMove)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Draggable<PanelData>(
                  data: widget.panelData,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.dexSecondary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            widget.panelData.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  childWhenDragging: Container(),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),

          // 우하단 크기 조정 핸들 (포커스 시에만 표시, onResize가 null이 아닐 때만)
          if ((_isFocused || _isResizing) && widget.onResize != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isResizing = true;
                      _startWidth =
                          widget.panelData.gridWidth * widget.gridWidth;
                      _startHeight =
                          widget.panelData.gridHeight * widget.gridHeight;
                      _currentWidth = _startWidth;
                      _currentHeight = _startHeight;
                      _tempWidth = null;
                      _tempHeight = null;
                    });
                  },
                  onPanUpdate: (details) {
                    if (widget.onResize != null) {
                      // delta를 누적하여 현재 크기 계산
                      _currentWidth += details.delta.dx;
                      _currentHeight += details.delta.dy;

                      // 퍼센트 단위로 변환 (1~100)
                      final newWidth = (_currentWidth / widget.gridWidth)
                          .round()
                          .clamp(5, 100);
                      final newHeight = (_currentHeight / widget.gridHeight)
                          .round()
                          .clamp(5, 100);

                      // 드래그 중에는 로컬 상태만 업데이트 (시각적 피드백용)
                      if (newWidth != _tempWidth || newHeight != _tempHeight) {
                        setState(() {
                          _tempWidth = newWidth;
                          _tempHeight = newHeight;
                        });
                      }
                    }
                  },
                  onPanEnd: (_) {
                    // 드래그 종료 시에만 실제 리사이즈 호출
                    if (_tempWidth != null &&
                        _tempHeight != null &&
                        widget.onResize != null) {
                      widget.onResize!(_tempWidth!, _tempHeight!);
                    }
                    setState(() {
                      _isResizing = false;
                      _tempWidth = null;
                      _tempHeight = null;
                    });
                    widget.onResizeEnd?.call();
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    child: Image.asset(
                      'assets/image/right_resize.png',
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ),
              ),
            ),

          // 리사이즈 중 시각적 피드백 (드래그 중에만 표시)
          if (_isResizing && _tempWidth != null && _tempHeight != null)
            Positioned(
              left: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  width: _tempWidth! * widget.gridWidth,
                  height: _tempHeight! * widget.gridHeight,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    color: Colors.blue.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 패널 드롭 타겟 위젯
class PanelDropTarget extends StatefulWidget {
  final Widget child;
  final Function(PanelData) onAccept;
  final int gridX;
  final int gridY;

  const PanelDropTarget({
    super.key,
    required this.child,
    required this.onAccept,
    required this.gridX,
    required this.gridY,
  });

  @override
  State<PanelDropTarget> createState() => _PanelDropTargetState();
}

class _PanelDropTargetState extends State<PanelDropTarget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PanelData>(
      onWillAcceptWithDetails: (data) => true,
      onAcceptWithDetails: (details) {
        widget.onAccept(details.data);
        setState(() => _isHovering = false);
      },
      onMove: (_) {
        if (!_isHovering) {
          setState(() => _isHovering = true);
        }
      },
      onLeave: (_) {
        setState(() => _isHovering = false);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            border: _isHovering
                ? Border.all(
                    color: const Color(0xFFFCD535),
                    width: 2,
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 우하단 크기 조정 아이콘 페인터 (꺽쇠 모양 ↘)
class _ResizeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B0E11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final length = 4.0;

    // 우하단 꺽쇠: ㄴ 모양 (90도 회전)
    // 세로선 (위에서 아래로)
    canvas.drawLine(
      Offset(centerX + length, centerY - length),
      Offset(centerX + length, centerY + length),
      paint,
    );

    // 가로선 (왼쪽에서 오른쪽으로)
    canvas.drawLine(
      Offset(centerX - length, centerY + length),
      Offset(centerX + length, centerY + length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
