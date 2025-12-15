import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/theme.dart';
import '../widgets/trading_chart.dart';
import 'panel_type.dart';
import 'draggable_panel.dart';
import '../widgets/orderbook_widget.dart';
import '../widgets/order_panel.dart';
import '../widgets/account_info_tabs.dart';
import '../widgets/account_info_widget.dart';

/// 레이아웃 상태 관리 Provider
class LayoutState {
  final List<PanelData> panels;
  final int columns;
  final int rows;

  LayoutState({
    required this.panels,
    this.columns = 5,
    this.rows = 3,
  });

  LayoutState copyWith({
    List<PanelData>? panels,
    int? columns,
    int? rows,
  }) {
    return LayoutState(
      panels: panels ?? this.panels,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
    );
  }
}

class LayoutNotifier extends Notifier<LayoutState> {
  @override
  LayoutState build() {
    final initialState = LayoutState(
      panels: DefaultLayouts.standard,
      columns: 100, // 퍼센트 기준
      rows: 100,
    );
    // 초기 인접 관계 계산
    Future.microtask(() => _updatePanelAdjacency());
    return initialState;
  }

  void updatePanel(PanelData panel) {
    final index = state.panels.indexWhere((p) => p.id == panel.id);
    if (index != -1) {
      final newPanels = List<PanelData>.from(state.panels);
      newPanels[index] = panel;
      state = state.copyWith(panels: newPanels);
    }
  }

  void movePanel(String panelId, int newX, int newY) {
    final index = state.panels.indexWhere((p) => p.id == panelId);
    if (index != -1) {
      final panel = state.panels[index];
      updatePanel(panel.copyWith(gridX: newX, gridY: newY));
    }
  }

  void removePanel(String panelId) {
    state = state.copyWith(
      panels: state.panels.where((p) => p.id != panelId).toList(),
    );
  }

  void addPanel(PanelData panel) {
    state = state.copyWith(
      panels: [...state.panels, panel],
    );
  }

  void loadLayout(List<PanelData> panels) {
    state = state.copyWith(panels: panels);
    _updatePanelAdjacency();
  }

  void resetToDefault() {
    state = state.copyWith(panels: DefaultLayouts.standard);
    _updatePanelAdjacency();
  }

  // 패널 간 인접 관계 업데이트
  void _updatePanelAdjacency() {
    final panels = List<PanelData>.from(state.panels);

    for (var panel in panels) {
      // 오른쪽 패널 찾기
      final rightPanels = panels
          .where((p) =>
              p.id != panel.id &&
              p.gridY == panel.gridY &&
              p.gridX > panel.gridX)
          .toList();
      rightPanels.sort((a, b) => a.gridX.compareTo(b.gridX));
      panel.rightPanelId = rightPanels.isNotEmpty ? rightPanels.first.id : null;

      // 아래 패널 찾기
      final bottomPanels = panels
          .where((p) =>
              p.id != panel.id &&
              p.gridX == panel.gridX &&
              p.gridY > panel.gridY)
          .toList();
      bottomPanels.sort((a, b) => a.gridY.compareTo(b.gridY));
      panel.bottomPanelId =
          bottomPanels.isNotEmpty ? bottomPanels.first.id : null;
    }

    state = state.copyWith(panels: panels);
  }
}

/// Provider 정의
final layoutProvider = NotifierProvider<LayoutNotifier, LayoutState>(() {
  return LayoutNotifier();
});

/// 커스터마이징 가능한 레이아웃 위젯
class CustomizableLayout extends ConsumerStatefulWidget {
  final double? topHeight;
  final double? bottomHeight;
  final bool allowResize;
  final bool allowMove;

  const CustomizableLayout({
    super.key,
    this.topHeight,
    this.bottomHeight,
    this.allowResize = true,
    this.allowMove = true,
  });

  @override
  ConsumerState<CustomizableLayout> createState() => _CustomizableLayoutState();
}

class _CustomizableLayoutState extends ConsumerState<CustomizableLayout> {
  // 리사이즈 중인 패널의 현재 크기 추적 (로컬 상태)
  final Map<String, ({int width, int height})> _resizingPanels = {};

  // 패널의 헤더 액션 위젯 저장 (예: 오더북의 틱 사이즈 드롭다운)
  final Map<String, Widget> _panelHeaderActions = {};

  bool get isNarrowMode => _isNarrowMode;
  bool _isNarrowMode = false;

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutProvider);
    const spacing = 3.0; // 패널 간 간격

    return LayoutBuilder(
      builder: (context, constraints) {
        // 폭인 작은 화면 체크 (800px 이하)
        _isNarrowMode = constraints.maxWidth <= 800;
        if (isNarrowMode) {
          return _buildMobileLayout(
              layoutState, spacing, constraints.maxHeight);
        }

        // 데스크톱 레이아웃
        final gridWidth = constraints.maxWidth / layoutState.columns;
        final gridHeight = constraints.maxHeight / layoutState.rows;

        // 각 패널의 실제 top 위치를 계산
        double calculatePanelTop(PanelData panel) {
          final visiblePanels = layoutState.panels.where((p) => p.isVisible);
          final panelRight = panel.gridX + panel.gridWidth;

          // 패널이 화면 오른쪽 끝에 닿는지 확인
          final touchesRightEdge = panelRight >= layoutState.columns;

          // 상단 패널들 찾기
          final upperPanels = visiblePanels.where((p) {
            if (p.gridY >= panel.gridY) return false; // 위에 있어야 함

            if (touchesRightEdge) {
              // 오른쪽 끝에 닿는 패널: 같은 gridY의 모든 상단 패널 고려
              return true;
            } else {
              // 그렇지 않으면: X 범위가 겹치는 상단 패널만 고려
              final pRight = p.gridX + p.gridWidth;
              return panel.gridX < pRight && panelRight > p.gridX;
            }
          }).toList();

          if (upperPanels.isEmpty) {
            // 위에 패널이 없으면 gridY 기준으로 top 계산
            return panel.gridY * gridHeight;
          }

          // 위 패널들의 하단 중 가장 아래에 있는 것을 찾음
          double maxBottom = 0;
          for (final upperPanel in upperPanels) {
            // upperPanel의 실제 top을 재귀적으로 계산
            final upperTop = calculatePanelTop(upperPanel);
            final upperBottom =
                upperTop + upperPanel.gridHeight * gridHeight + spacing;
            if (upperBottom > maxBottom) {
              maxBottom = upperBottom;
            }
          }

          return maxBottom;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: layoutState.panels.where((p) => p.isVisible).map((panel) {
            final actualTop = calculatePanelTop(panel);

            return Positioned(
              left: panel.gridX * gridWidth + (panel.gridX > 0 ? spacing : 0),
              top: actualTop,
              width: panel.gridWidth * gridWidth - spacing,
              height: panel.gridHeight * gridHeight - spacing,
              child: _buildPanel(panel, gridWidth, gridHeight),
            );
          }).toList(),
        );
      },
    );
  }

  // 모바일 레이아웃: 차트(상단) + 호가창/주문창(하단)
  Widget _buildMobileLayout(
      LayoutState layoutState, double spacing, double maxHeight) {
    final chartPanel = layoutState.panels.firstWhere(
      (p) => p.type == PanelType.chart && p.isVisible,
      orElse: () => layoutState.panels.first,
    );

    final orderbookPanel = layoutState.panels.firstWhere(
      (p) => p.type == PanelType.orderbook && p.isVisible,
      orElse: () => layoutState.panels.first,
    );

    final orderPanelData = layoutState.panels.firstWhere(
      (p) => p.type == PanelType.orderPanel && p.isVisible,
      orElse: () => layoutState.panels.first,
    );

    // 계정 정보 패널 찾기
    final accountPanel = layoutState.panels.firstWhere(
      (p) =>
          (p.type == PanelType.positions ||
              p.type == PanelType.orders ||
              p.type == PanelType.history ||
              p.type == PanelType.funds) &&
          p.isVisible,
      orElse: () => layoutState.panels.first,
    );

    // 전달받은 높이 사용, 없으면 기본값
    final topHeight = widget.topHeight ?? 700.0;
    final bottomHeight = widget.bottomHeight ?? 400.0;

    return Column(
      children: [
        // 차트 영역 (고정 높이)
        SizedBox(
          height: topHeight,
          child: Container(
            margin: EdgeInsets.all(spacing),
            child: _buildMobilePanelContent(chartPanel.id, chartPanel.type),
          ),
        ),

        // 호가창 + 주문창 (고정 높이)
        SizedBox(
          height: bottomHeight,
          child: Row(
            children: [
              // 호가창 (왼쪽)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: spacing,
                    right: spacing / 2,
                    bottom: spacing,
                  ),
                  child: _buildMobilePanelWrapper(
                    orderbookPanel.title,
                    _buildPanelContent(orderbookPanel.id, orderbookPanel.type),
                    headerAction: _panelHeaderActions[orderbookPanel.id],
                  ),
                ),
              ),

              // 주문창 (오른쪽)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: spacing / 2,
                    right: spacing,
                    bottom: spacing,
                  ),
                  child: _buildMobilePanelWrapper(
                    orderPanelData.title,
                    _buildPanelContent(orderPanelData.id, orderPanelData.type),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 계정 정보 (고정 높이 300px)
        SizedBox(
          height: 300,
          child: Container(
            margin: EdgeInsets.only(
              left: spacing,
              right: spacing,
              bottom: spacing,
            ),
            child: _buildMobilePanelWrapper(
              accountPanel.title,
              _buildPanelContent(accountPanel.id, accountPanel.type),
            ),
          ),
        ),
      ],
    );
  }

  // 모바일용 패널 컨텐츠 래퍼 (헤더 포함)
  Widget _buildMobilePanelContent(String panelId, PanelType type) {
    final panel = ref.read(layoutProvider).panels.firstWhere(
          (p) => p.id == panelId,
          orElse: () => ref.read(layoutProvider).panels.first,
        );

    return _buildMobilePanelWrapper(
      panel.title,
      _buildPanelContent(panelId, type),
    );
  }

  // 모바일용 패널 래퍼 (헤더 제거, 컨텐츠만)
  Widget _buildMobilePanelWrapper(String title, Widget content,
      {Widget? headerAction}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: content,
    );
  }

  Widget _buildPanel(PanelData panelData, double gridWidth, double gridHeight) {
    return PanelDropTarget(
      gridX: panelData.gridX,
      gridY: panelData.gridY,
      onAccept: (droppedPanel) {
        _insertPanel(droppedPanel, panelData);
      },
      child: ResizablePanel(
        panelData: panelData,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        onResize: widget.allowResize
            ? (newWidth, newHeight) {
                _resizePanel(panelData, newWidth, newHeight);
              }
            : null,
        onResizeEnd: () {
          _resizingPanels.remove(panelData.id);
        },
        headerAction: _panelHeaderActions[panelData.id],
        allowMove: widget.allowMove,
        child: _buildPanelContent(panelData.id, panelData.type),
      ),
    );
  }

  // 패널 크기 조정: 오른쪽 패널 자동 조정
  void _resizePanel(PanelData panel, int newWidth, int newHeight) {
    // 최소/최대 크기 제한 (먼저 적용)
    const minWidth = 10; // 10%
    const maxWidth = 80; // 80%
    const minHeight = 20; // 20%
    const maxHeight = 80; // 80%

    newWidth = newWidth.clamp(minWidth, maxWidth);
    newHeight = newHeight.clamp(minHeight, maxHeight);

    // 현재 상태 가져오기
    final currentState = ref.read(layoutProvider);

    // 최신 panel 정보 가져오기
    final currentPanel = currentState.panels
        .firstWhere((p) => p.id == panel.id, orElse: () => panel);

    // 로컬 상태에서 이전 크기 가져오기 (없으면 현재 패널 크기)
    final previousSize = _resizingPanels[panel.id];
    final oldWidth = previousSize?.width ?? currentPanel.gridWidth;
    final oldHeight = previousSize?.height ?? currentPanel.gridHeight;

    // 크기가 변경되지 않았으면 무시 (중복 호출 방지)
    if (newWidth == oldWidth && newHeight == oldHeight) {
      return;
    }

    debugPrint('=== _resizePanel 호출: ${panel.id} ===');
    debugPrint('oldSize: ($oldWidth, $oldHeight)');
    debugPrint('newSize: ($newWidth, $newHeight)');

    final widthDiff = newWidth - oldWidth;
    final heightDiff = newHeight - oldHeight;

    debugPrint('widthDiff: $widthDiff, heightDiff: $heightDiff');
    debugPrint(
        'rightPanelId: ${currentPanel.rightPanelId}, bottomPanelId: ${currentPanel.bottomPanelId}');

    // 가로 크기 조정
    // 같은 행(Y좌표)에 있는 모든 오른쪽 패널들 찾기
    final rightPanels = currentState.panels
        .where((p) =>
            p.id != panel.id &&
            p.gridY == panel.gridY &&
            p.gridX >= panel.gridX + oldWidth)
        .toList();
    rightPanels.sort((a, b) => a.gridX.compareTo(b.gridX));

    if (rightPanels.isNotEmpty) {
      // 오른쪽에 패널들이 있는 경우

      // 1. 바로 인접한 오른쪽 패널
      final rightPanel = rightPanels.first;

      // 2. 모든 오른쪽 패널들의 최소 크기 합계
      final totalMinWidthOfRightPanels = rightPanels.length * minWidth;

      // 3. 현재 패널의 최대 허용 크기
      // panel.gridX + newWidth + (모든 오른쪽 패널들의 최소 크기 합) <= 100
      final maxAllowedWidth =
          currentState.columns - panel.gridX - totalMinWidthOfRightPanels;

      if (newWidth > maxAllowedWidth) {
        newWidth = maxAllowedWidth;
        debugPrint(
            '패널 크기 제한: 오른쪽 패널들이 화면 경계를 넘지 않도록 조정 -> $newWidth (오른쪽 패널 ${rightPanels.length}개)');
      }

      // 4. 바로 인접한 오른쪽 패널이 최소 크기보다 작아지는지 체크
      final newRightWidth = rightPanel.gridWidth - widthDiff;
      if (newRightWidth < minWidth) {
        final maxWidthIncrease = rightPanel.gridWidth - minWidth;
        newWidth = (oldWidth + maxWidthIncrease).toInt();
        debugPrint('패널 크기 제한: 인접 패널 최소 크기 유지 -> $newWidth');
      }

      // 5. 패널 업데이트
      final updatedPanel = currentPanel.copyWith(
        gridWidth: newWidth,
        gridHeight: newHeight,
      );
      final actualWidthDiff = newWidth - oldWidth;

      // 로컬 상태 업데이트 (최종 확정된 크기로)
      _resizingPanels[panel.id] = (width: newWidth, height: newHeight);

      // 6. 바로 인접한 오른쪽 패널 조정
      final rightWidth =
          (rightPanel.gridWidth - actualWidthDiff).clamp(minWidth, maxWidth);
      final newRightX = currentPanel.gridX + newWidth;

      final updatedRightPanel = rightPanel.copyWith(
        gridX: newRightX,
        gridWidth: rightWidth,
      );

      debugPrint(
          '패널 조정: panel[$newWidth], rightPanel[$rightWidth] (widthDiff: $actualWidthDiff)');

      ref.read(layoutProvider.notifier).updatePanel(updatedPanel);
      ref.read(layoutProvider.notifier).updatePanel(updatedRightPanel);

      // 7. 나머지 오른쪽 패널들도 X 위치 이동
      if (rightPanels.length > 1) {
        for (int i = 1; i < rightPanels.length; i++) {
          final prevPanel = i == 1 ? updatedRightPanel : rightPanels[i - 1];
          final currPanel = rightPanels[i];

          final updatedCurrPanel = currPanel.copyWith(
            gridX: prevPanel.gridX + prevPanel.gridWidth,
          );

          ref.read(layoutProvider.notifier).updatePanel(updatedCurrPanel);
          debugPrint(
              '연쇄 패널 이동: ${currPanel.id} -> X:${updatedCurrPanel.gridX}');
        }
      }
    } else {
      // 오른쪽 패널이 없으면 단순 크기 조정 (화면 경계 체크)
      final maxAllowedWidth = currentState.columns - currentPanel.gridX;
      newWidth = newWidth.clamp(minWidth, maxAllowedWidth);

      // 로컬 상태 업데이트 (최종 확정된 크기로)
      _resizingPanels[panel.id] = (width: newWidth, height: newHeight);

      ref.read(layoutProvider.notifier).updatePanel(currentPanel.copyWith(
            gridWidth: newWidth,
            gridHeight: newHeight,
          ));

      debugPrint(
          '패널 단독 조정: ${panel.id} -> width: $newWidth, height: $newHeight');
    }

    // 세로 크기만 변경된 경우 (가로는 이미 위에서 처리됨)
    if (heightDiff != 0 && widthDiff == 0) {
      // 최소/최대 높이 제한만 적용
      newHeight = newHeight.clamp(minHeight, maxHeight);

      // 로컬 상태 업데이트 (최종 확정된 높이로)
      _resizingPanels[panel.id] = (width: newWidth, height: newHeight);

      ref
          .read(layoutProvider.notifier)
          .updatePanel(currentPanel.copyWith(gridHeight: newHeight));

      debugPrint('세로 크기만 조정: ${panel.id} -> $newHeight');
    }
  }

  // 패널 삽입: droppedPanel을 targetPanel 위치에 삽입하고 나머지를 밀어냄
  void _insertPanel(PanelData droppedPanel, PanelData targetPanel) {
    final state = ref.read(layoutProvider);

    // 같은 패널에 드롭하면 무시
    if (droppedPanel.id == targetPanel.id) return;

    // 현재 패널 목록을 위치 순서대로 정렬 (Y좌표 우선, 같으면 X좌표)
    final sortedPanels = List<PanelData>.from(state.panels);
    sortedPanels.sort((a, b) {
      if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
      return a.gridX.compareTo(b.gridX);
    });

    // droppedPanel을 목록에서 제거
    sortedPanels.removeWhere((p) => p.id == droppedPanel.id);

    // targetPanel의 인덱스 찾기
    final targetIndex = sortedPanels.indexWhere((p) => p.id == targetPanel.id);

    // droppedPanel을 targetPanel 위치에 삽입
    if (targetIndex >= 0) {
      sortedPanels.insert(targetIndex, droppedPanel);
    }

    // 재배치: 한 줄에 패널들을 순서대로 배치
    _rearrangePanels(sortedPanels);

    // 인접 관계 재계산
    ref.read(layoutProvider.notifier)._updatePanelAdjacency();
  }

  // 패널들을 겹치지 않게 재배치
  void _rearrangePanels(List<PanelData> panels) {
    final state = ref.read(layoutProvider);
    final notifier = ref.read(layoutProvider.notifier);

    int currentX = 0;
    int currentY = 0;

    for (final panel in panels) {
      // 현재 줄에 공간이 있는지 확인
      if (currentX + panel.gridWidth > state.columns) {
        // 다음 줄로
        currentX = 0;
        currentY += 70; // 기본 높이 (표준 레이아웃 참고)
      }

      // 패널 위치 업데이트
      notifier.updatePanel(panel.copyWith(
        gridX: currentX,
        gridY: currentY,
      ));

      // 다음 패널 위치
      currentX += panel.gridWidth;
    }
  }

  Widget _buildPanelContent(String panelId, PanelType type) {
    switch (type) {
      case PanelType.chart:
        return const TradingChart();
      case PanelType.orderbook:
        return OrderbookWidget(
          onHeaderActionBuilt: (widget) {
            setState(() {
              _panelHeaderActions[panelId] = widget;
            });
          },
          position:
              isNarrowMode ? OrderBookPosition.bottom : OrderBookPosition.left,
        );
      case PanelType.orderPanel:
        return const OrderPanel();

      case PanelType.accountInfo:
        return const AccountInfoWidget();

      case PanelType.positions:
      case PanelType.orders:
      case PanelType.history:
      case PanelType.funds:
        return AccountInfoTabs(isNarrowMode: isNarrowMode);

      case PanelType.trades:
        return Container(
          color: const Color(0xFF161A1E),
          child: const Center(
            child: Text(
              '최근 체결',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
    }
  }
}

/// 레이아웃 설정 버튼 (툴바에 추가할 위젯)
class LayoutSettingsButton extends ConsumerWidget {
  const LayoutSettingsButton({super.key});

  void _showResetConfirmDialog(BuildContext context, LayoutNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dexSurface,
        title: const Text(
          '레이아웃 초기화',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '레이아웃을 초기 설정으로 되돌리시겠습니까?\n현재 레이아웃 변경사항이 모두 사라집니다.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              notifier.resetToDefault();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('레이아웃이 초기화되었습니다')),
              );
            },
            child: const Text(
              '초기화',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.dashboard_customize, color: Colors.grey),
      tooltip: '레이아웃 설정',
      color: AppTheme.dexSecondary,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'standard',
          child: Text('표준 레이아웃', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'chart_focused',
          child: Text('차트 중심', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'trading_focused',
          child: Text('트레이딩 중심', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'save',
          child: Text('현재 레이아웃 저장', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'reset',
          child: Text('초기화', style: TextStyle(color: Colors.grey)),
        ),
      ],
      onSelected: (value) {
        final notifier = ref.read(layoutProvider.notifier);
        switch (value) {
          case 'standard':
            notifier.loadLayout(DefaultLayouts.standard);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('표준 레이아웃으로 변경되었습니다')),
            );
            break;
          case 'chart_focused':
            notifier.loadLayout(DefaultLayouts.chartFocused);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('차트 중심 레이아웃으로 변경되었습니다')),
            );
            break;
          case 'trading_focused':
            notifier.loadLayout(DefaultLayouts.tradingFocused);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('트레이딩 중심 레이아웃으로 변경되었습니다')),
            );
            break;
          case 'reset':
            _showResetConfirmDialog(context, notifier);
            break;
          case 'save':
            // TODO: 로컬 스토리지에 저장
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('레이아웃이 저장되었습니다')),
            );
            break;
        }
      },
    );
  }
}
