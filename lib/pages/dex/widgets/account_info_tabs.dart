import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common/theme.dart';
import '../../../data/providers.dart';
import '../../../wallet/providers/ethereum_wallet_provider.dart';
import '../providers/order_provider.dart';
import '../providers/position_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/order_history_provider.dart';
import '../providers/trade_history_provider.dart';

/// 계정 정보 탭 위젯
/// - 포지션, 주문내역, 거래내역, 입출금 정보
class AccountInfoTabs extends ConsumerStatefulWidget {
  final bool isNarrowMode;

  const AccountInfoTabs({required this.isNarrowMode, super.key});

  @override
  ConsumerState<AccountInfoTabs> createState() => _AccountInfoTabsState();
}

class _AccountInfoTabsState extends ConsumerState<AccountInfoTabs>
    with TickerProviderStateMixin {
  late List<TabController> _tabControllers;
  final NumberFormat numberFormat = NumberFormat('#,##0.00', 'en_US');

  List<List<String>> _tabTitles = [
    ['포지션', '미체결'],
    ['포지션', '미체결', '주문 내역', '거래 내역', '전송 내역', '입금 및 출금', '자산']
  ];

  int get _tabIndex => widget.isNarrowMode ? 0 : 1;

  // 취소 중인 주문 ID들
  final Set<int> _cancellingOrderIds = {};

  // 종료 중인 포지션 ID들
  final Set<String> _closingPositionIds = {};

  @override
  void initState() {
    super.initState();
    _tabControllers = [
      TabController(length: _tabTitles[0].length, vsync: this),
      TabController(length: _tabTitles[1].length, vsync: this)
    ];

    // 각 TabController에 리스너 추가
    for (int i = 0; i < _tabControllers.length; i++) {
      _tabControllers[i].addListener(() => _onTabChanged(i));
    }

    // 현재가 변동 감지 리스너 추가
    ref.listenManual(currentPriceProvider, (prev, next) {
      if (next > 0) {
        // BTCUSDT 포지션의 현재가 업데이트
        ref
            .read(positionListProvider.notifier)
            .updateMarkPrice('BTCUSDT', next);
      }
    });

    // 지갑 인증 상태 변경 감지 리스너 추가
    ref.listenManual(
      ethereumWalletProvider.select((state) => state.isAuthenticated),
      (prev, next) {
        // 로그인 성공 시 (false -> true)
        if (prev == false && next == true) {
          // 현재 선택된 탭에 따라 데이터 다시 로드
          final currentTab = _tabControllers[_tabIndex].index;
          if (currentTab == 0) {
            // 포지션 탭
            ref.read(positionListProvider.notifier).fetchPositions();
          } else if (currentTab == 1) {
            // 미체결 탭
            ref.read(orderListProvider.notifier).fetchOrders(status: 'OPEN');
          }
        }
      },
    );

    // 페이지 로드 시 초기 데이터 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 현재 선택된 탭에 따라 초기 데이터 로드
      final currentTab = _tabControllers[_tabIndex].index;
      if (currentTab == 0) {
        // 포지션 탭
        ref.read(positionListProvider.notifier).fetchPositions();
      } else if (currentTab == 1) {
        // 미체결 탭
        ref.read(orderListProvider.notifier).fetchOrders(status: 'OPEN');
      }
    });
  }

  void _onTabChanged(int controllerIndex) {
    if (!_tabControllers[controllerIndex].indexIsChanging) {
      final tabIndex = _tabControllers[controllerIndex].index;

      // Narrow 모드 (0) - 포지션(0), 미체결(1)
      // Wide 모드 (1) - 포지션(0), 미체결(1), 주문내역(2), 거래내역(3), ...
      if (tabIndex == 0) {
        // 포지션 탭이 선택되면 서버에서 데이터 가져오기
        ref.read(positionListProvider.notifier).fetchPositions();
      } else if (tabIndex == 1) {
        // 미체결 탭이 선택되면 서버에서 데이터 가져오기
        ref.read(orderListProvider.notifier).fetchOrders(status: 'OPEN');
      } else if (tabIndex == 2 && controllerIndex == 1) {
        // 주문 내역 탭 (Wide 모드에서만)
        ref.read(orderHistoryProvider.notifier).fetchOrderHistory();
      } else if (tabIndex == 3 && controllerIndex == 1) {
        // 거래 내역 탭 (Wide 모드에서만)
        ref.read(tradeHistoryProvider.notifier).fetchTradeHistory();
      }
    }
  }

  @override
  void dispose() {
    _tabControllers.forEach((e) => e.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Container(
        margin: const EdgeInsets.all(4),
        child: Column(
          children: [
            // 탭 헤더
            _buildTabHeader(),

            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabControllers[_tabIndex],
                children: [
                  _buildPositionsTab(),
                  _buildOpenOrdersTab(),
                  ..._tabIndex == 0
                      ? []
                      : [
                          _buildOrdersTab(),
                          _buildTradeHistoryTab(),
                          _buildFundsTab(),
                          Container(),
                          Container(),
                        ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
                controller: _tabControllers[_tabIndex],
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: _tabTitles[widget.isNarrowMode ? 0 : 1]
                    .map((e) => Tab(text: e))
                    .toList()),
          ),
          if (widget.isNarrowMode)
            Icon(
              Icons.menu,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  // 미체결 주문 탭
  Widget _buildOpenOrdersTab() {
    final orderState = ref.watch(orderListProvider);
    final orders = orderState.orders.where((o) => o.status == 'OPEN').toList();

    return Column(
      children: [
        // 새로고침 버튼
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '미체결 ${orders.length}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref
                      .read(orderListProvider.notifier)
                      .fetchOrders(status: 'OPEN');
                },
                icon: orderState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
            ],
          ),
        ),

        // 컬럼 헤더
        if (!widget.isNarrowMode)
          _buildTableHeader([
            '시간',
            '거래쌍',
            '타입',
            '사이드',
            '가격',
            '수량',
            '미체결',
            '액션',
          ]),

        // 주문 목록
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        orderState.error ?? '미체결 주문이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderRow(order);
                  },
                ),
        ),
      ],
    );
  }

  // 주문 행 위젯
  Widget _buildOrderRow(FuturesOrder order) {
    final isBuy = order.side == 'BUY';
    final sideColor = isBuy ? AppTheme.upColor : AppTheme.downColor;
    final timeFormat = DateFormat('MM-dd HH:mm');

    if (widget.isNarrowMode) {
      // 좁은 화면용 카드 형태
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    isBuy ? '매수' : '매도',
                    style: TextStyle(
                      color: sideColor,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                _cancellingOrderIds.contains(order.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: () => _cancelOrder(order),
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.grey,
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildOrderInfo('가격', numberFormat.format(order.price)),
                const SizedBox(width: 16),
                _buildOrderInfo('수량', numberFormat.format(order.quantity)),
                const SizedBox(width: 16),
                _buildOrderInfo(
                    '미체결', numberFormat.format(order.remainingQuantity)),
              ],
            ),
          ],
        ),
      );
    }

    // 넓은 화면용 테이블 행
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              timeFormat.format(order.createdAt),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              order.symbol,
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              order.type,
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              isBuy ? '매수' : '매도',
              style: AppTheme.bodySmall.copyWith(color: sideColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(order.price),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(order.quantity),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(order.remainingQuantity),
              style: AppTheme.num14.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _cancellingOrderIds.contains(order.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _cancelOrder(order),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          '취소',
                          style: AppTheme.bodySmallBold
                              .copyWith(color: Colors.red),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
        Text(
          value,
          style: AppTheme.num14.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _cancelOrder(FuturesOrder order) async {
    if (_cancellingOrderIds.contains(order.id)) return;

    // 취소 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2329),
        title: const Text(
          '주문 취소',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${order.symbol} ${order.side == 'BUY' ? '매수' : '매도'} 주문을 취소하시겠습니까?\n\n'
          '가격: ${numberFormat.format(order.price)} USDT\n'
          '수량: ${numberFormat.format(order.quantity)}',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _cancellingOrderIds.add(order.id);
    });

    try {
      final success =
          await ref.read(orderListProvider.notifier).cancelOrder(order.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문이 취소되었습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<void> _closePosition(FuturesPosition position) async {
    print(
        '[UI] Closing position with ID: "${position.id}" (type: ${position.id.runtimeType})');
    if (_closingPositionIds.contains(position.id)) return;

    // 포지션 종료 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.popupBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        title: const Text(
          '포지션 종료',
          style: TextStyle(color: Colors.white),
        ),
        content: SelectionArea(
          child: Text(
            '${position.symbol} ${position.side == 'LONG' ? '롱' : '숏'} 포지션을 종료하시겠습니까?\n\n'
            '포지션 번호: ${position.id}\n'
            '진입가: ${numberFormat.format(position.entryPrice)} USDT\n'
            '현재가: ${numberFormat.format(position.markPrice)} USDT\n'
            '수량: ${numberFormat.format(position.size.abs())}\n'
            '예상 손익: ${position.unrealizedPnl >= 0 ? '+' : ''}${numberFormat.format(position.unrealizedPnl)} USDT',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _closingPositionIds.add(position.id);
    });

    try {
      final success = await ref
          .read(positionListProvider.notifier)
          .closePosition(position.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포지션이 종료되었습니다')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포지션 종료에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _closingPositionIds.remove(position.id);
        });
      }
    }
  }

  // 포지션 탭
  Widget _buildPositionsTab() {
    final positionState = ref.watch(positionListProvider);
    final positions = positionState.positions;

    return Column(
      children: [
        // 새로고침 버튼
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '포지션 ${positions.length}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(positionListProvider.notifier).fetchPositions();
                },
                icon: positionState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
            ],
          ),
        ),

        // 컬럼 헤더
        if (!widget.isNarrowMode)
          _buildTableHeader([
            '포지션',
            '거래쌍',
            '수량',
            '진입가',
            '현재가',
            'PNL',
            '청산가',
            '증거금',
            '액션',
          ]),

        // 포지션 목록
        Expanded(
          child: positions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        positionState.error ?? '포지션을 찾을 수 없습니다',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: positions.length,
                  itemBuilder: (context, index) {
                    final position = positions[index];
                    return _buildPositionRow(position);
                  },
                ),
        ),
      ],
    );
  }

  // 포지션 행 위젯
  Widget _buildPositionRow(FuturesPosition position) {
    final isLong = position.side == 'LONG';
    final sideColor = isLong ? AppTheme.upColor : AppTheme.downColor;
    final pnlColor =
        position.unrealizedPnl >= 0 ? AppTheme.upColor : AppTheme.downColor;

    if (widget.isNarrowMode) {
      // 좁은 화면용 카드 형태
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2329),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  position.symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    isLong ? 'Long' : 'Short',
                    style: AppTheme.bodyMedium.copyWith(
                      color: sideColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${position.unrealizedPnl >= 0 ? '+' : ''}${numberFormat.format(position.unrealizedPnl)}',
                  style: AppTheme.num14.copyWith(
                    color: pnlColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPositionInfo(
                    '수량', '${numberFormat.format(position.size.abs())}'),
                const SizedBox(width: 16),
                _buildPositionInfo(
                    '진입가', numberFormat.format(position.entryPrice)),
                const SizedBox(width: 16),
                _buildPositionInfo(
                    '청산가', numberFormat.format(position.liquidationPrice)),
              ],
            ),
          ],
        ),
      );
    }

    // 넓은 화면용 테이블 행
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isLong ? 'LONG' : 'SHORT',
              style: AppTheme.bodySmall.copyWith(color: sideColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              position.symbol,
              style: AppTheme.bodySmall.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${numberFormat.format(position.size.abs())}',
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(position.entryPrice),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(position.markPrice),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Text(
                  '${position.unrealizedPnl >= 0 ? '+' : ''}${numberFormat.format(position.unrealizedPnl)}',
                  style: AppTheme.num14.copyWith(color: pnlColor),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '(${position.roe >= 0 ? '+' : ''}${position.roe.toStringAsFixed(2)}%)',
                  style: AppTheme.num14.copyWith(color: pnlColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(position.liquidationPrice),
              style: AppTheme.num14.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              numberFormat.format(position.margin),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _closingPositionIds.contains(position.id)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _closePosition(position),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          '청산',
                          style: AppTheme.bodySmallBold
                              .copyWith(color: Colors.red),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
        Text(
          value,
          style: AppTheme.num14.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  // 주문내역 탭
  // 컬럼: 날짜, 페어, 유형, 평균/가격, 실행/금액, 트리거 조건, 리듀스온리, 포스트온리, 상태
  Widget _buildOrdersTab() {
    final orderHistoryState = ref.watch(orderHistoryProvider);
    final orders = orderHistoryState.orders;

    return Column(
      children: [
        // 새로고침 버튼
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '주문 내역 ${orders.length}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(orderHistoryProvider.notifier).fetchOrderHistory();
                },
                icon: orderHistoryState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
            ],
          ),
        ),

        // 컬럼 헤더
        _buildTableHeader([
          '날짜',
          '페어',
          '유형',
          '평균/가격',
          '실행/금액',
          '트리거 조건',
          'Reduce Only',
          'Post Only',
          '상태',
        ]),

        // 주문 목록
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        orderHistoryState.error ?? '주문 내역이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderHistoryRow(order);
                  },
                ),
        ),
      ],
    );
  }

  // 주문 이력 행 위젯
  Widget _buildOrderHistoryRow(OrderHistory order) {
    final isBuy = order.side == 'BUY';
    final sideColor = isBuy ? AppTheme.upColor : AppTheme.downColor;
    final timeFormat = DateFormat('MM-dd HH:mm:ss');

    // 상태 색상
    Color statusColor;
    switch (order.status) {
      case 'FILLED':
        statusColor = AppTheme.upColor;
        break;
      case 'CANCELLED':
        statusColor = Colors.grey;
        break;
      case 'REJECTED':
        statusColor = AppTheme.downColor;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 날짜
          Expanded(
            child: Text(
              timeFormat.format(order.createdAt),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          // 페어 + 사이드
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  order.symbol,
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  isBuy ? '매수' : '매도',
                  style: AppTheme.bodySmall
                      .copyWith(color: sideColor, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 유형
          Expanded(
            child: Text(
              order.typeText,
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          // 평균/가격
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  numberFormat.format(order.averagePrice),
                  style: AppTheme.num14
                      .copyWith(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  numberFormat.format(order.price),
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.grey[500], fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 실행/금액
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${numberFormat.format(order.filledQuantity)}/${numberFormat.format(order.quantity)}',
                  style: AppTheme.num14
                      .copyWith(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  numberFormat.format(order.filledAmount),
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.grey[500], fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 트리거 조건
          Expanded(
            child: Text(
              '-',
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          // 리듀스온리
          Expanded(
            child: Text(
              order.reduceOnly ? 'Y' : '-',
              style: AppTheme.bodySmall.copyWith(
                color: order.reduceOnly ? Colors.yellow : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 포스트온리
          Expanded(
            child: Text(
              order.timeInForce == 'GTX' ? 'Y' : '-',
              style: AppTheme.bodySmall.copyWith(
                color: order.timeInForce == 'GTX' ? Colors.yellow : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 상태
          Expanded(
            child: Text(
              order.statusText,
              style: AppTheme.bodySmall.copyWith(color: statusColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 거래내역 탭
  // 컬럼: 날짜, 페어, 가격, 수량, 수수료, 실현손익
  Widget _buildTradeHistoryTab() {
    final tradeHistoryState = ref.watch(tradeHistoryProvider);
    final trades = tradeHistoryState.trades;

    return Column(
      children: [
        // 새로고침 버튼
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(
                '거래 내역 ${trades.length}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ref.read(tradeHistoryProvider.notifier).fetchTradeHistory();
                },
                icon: tradeHistoryState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.grey,
              ),
            ],
          ),
        ),

        // 컬럼 헤더
        _buildTableHeader([
          '날짜',
          '페어',
          '가격',
          '수량',
          '수수료',
          '실현손익',
        ]),

        // 거래 목록
        Expanded(
          child: trades.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        color: Colors.grey[600],
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tradeHistoryState.error ?? '거래 내역이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: trades.length,
                  itemBuilder: (context, index) {
                    final trade = trades[index];
                    return _buildTradeHistoryRow(trade);
                  },
                ),
        ),
      ],
    );
  }

  // 거래 내역 행 위젯
  Widget _buildTradeHistoryRow(TradeHistory trade) {
    final isBuy = trade.side == 'BUY';
    final sideColor = isBuy ? AppTheme.upColor : AppTheme.downColor;
    final pnlColor =
        trade.realizedPnl >= 0 ? AppTheme.upColor : AppTheme.downColor;
    final timeFormat = DateFormat('MM-dd HH:mm:ss');

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 날짜
          Expanded(
            child: Text(
              timeFormat.format(trade.createdAt),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          // 페어 + 사이드
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  trade.symbol,
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  isBuy ? '매수' : '매도',
                  style: AppTheme.bodySmall
                      .copyWith(color: sideColor, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 가격
          Expanded(
            child: Text(
              numberFormat.format(trade.price),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          // 수량
          Expanded(
            child: Text(
              numberFormat.format(trade.quantity),
              style: AppTheme.num14.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          // 수수료
          Expanded(
            child: Text(
              numberFormat.format(trade.fee),
              style: AppTheme.num14.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          // 실현손익
          Expanded(
            child: Text(
              '${trade.realizedPnl >= 0 ? '+' : ''}${numberFormat.format(trade.realizedPnl)}',
              style: AppTheme.num14.copyWith(color: pnlColor),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // 입출금 탭
  Widget _buildFundsTab() {
    final balanceState = ref.watch(balanceProvider);
    final balance = balanceState.balance;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 잔고 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.dexSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '총 잔고',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${numberFormat.format(balance.totalBalance)} USDT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Play',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceItem('사용 가능',
                          numberFormat.format(balance.availableBalance)),
                    ),
                    Expanded(
                      child: _buildBalanceItem(
                          '주문 잠김', numberFormat.format(balance.lockedBalance)),
                    ),
                    Expanded(
                      child: _buildBalanceItem('미실현 PNL',
                          numberFormat.format(balance.totalUnrealizedPnl)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceItem(
                          '자산', numberFormat.format(balance.equity)),
                    ),
                    Expanded(
                      child: _buildBalanceItem('유지 마진',
                          numberFormat.format(balance.totalMaintenanceMargin)),
                    ),
                    Expanded(
                      child: _buildBalanceItem('마진 비율',
                          '${(balance.marginRatio * 100).toStringAsFixed(2)}%'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 입출금 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 입금
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('입금'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.upColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 출금
                  },
                  icon: const Icon(Icons.upload, size: 18),
                  label: const Text('출금'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dexSecondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 입출금 내역
          Text(
            '최근 입출금 내역',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.grey[600],
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '입출금 내역이 없습니다',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Play',
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(List<String> columns) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: columns.map((column) {
          return Expanded(
            child: Text(
              column,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );
  }
}
