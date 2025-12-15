import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '/pages/dex/widgets/orderbook_display_mode_icons.dart';
import '/data/providers.dart';
import '/common/theme.dart';
import '/config/config.dart';
import '../providers/order_provider.dart';

enum OrderBookPosition { left, bottom }

// 폭이 250px 이하면 중간 컬럼 숨김
const double middleColumnDisplayThreshold = 250;

/// 호가창(오더북) 위젯
/// - 매도 호가(asks), 현재가, 매수 호가(bids) 표시
class OrderbookWidget extends ConsumerStatefulWidget {
  final OrderBookPosition position;
  final Function(Widget)? onHeaderActionBuilt; // 헤더 액션 위젯을 전달하는 콜백

  const OrderbookWidget({
    this.position = OrderBookPosition.left,
    this.onHeaderActionBuilt,
    super.key,
  });

  @override
  ConsumerState<OrderbookWidget> createState() => _OrderbookWidgetState();
}

class _OrderbookWidgetState extends ConsumerState<OrderbookWidget> {
  final NumberFormat quantityFormat = NumberFormat('#,##0.000', 'en_US');
  final NumberFormat amountFormat = NumberFormat('#,##0.0', 'en_US');

  // 가격 포맷은 틱 사이즈에 따라 동적으로 생성
  NumberFormat _getPriceFormat(double unitSize) {
    if (unitSize >= 1) {
      // 1 이상: 소수점 없음
      return NumberFormat('#,##0', 'en_US');
    } else if (unitSize >= 0.1) {
      // 0.1: 소수점 1자리
      return NumberFormat('#,##0.0', 'en_US');
    } else {
      // 0.1 미만: 소수점 2자리
      return NumberFormat('#,##0.00', 'en_US');
    }
  }

  // 호가 데이터
  List<OrderBookEntry> asks = [];
  List<OrderBookEntry> bids = [];

  List<OrderBookEntry> visibleAsks = [];
  List<OrderBookEntry> visibleBids = [];

  double currentPrice = 0.0;
  double previousPrice = 0.0; // 이전 가격 추적
  int priceDirection = 0; // -1: 하락, 0: 변동없음, 1: 상승
  double maxTotal = 0;

  Timer? _timer;

  // 바이낸스 API 설정
  final String symbol = 'BTCUSDT';

  // 표시 모드: true = USDT 크기, false = BTC 수량
  bool showUsdtMode = true;

  // 틱 사이즈 (호가 간격)
  double unitSize = 0.1;
  final List<double> unitSizes = [0.1, 1, 10, 50, 100];

  // 현재 화면에 보이는 행 수 (매도 + 매수)
  int _visibleRows = 20;

  // 틱 사이즈와 보이는 행 수를 고려한 API limit 파라미터 계산
  int _calculateOptimalLimit() {
    // 보이는 행 수의 1.5배를 버퍼로 요청 (스크롤 및 가격 변동 대비)
    final desiredRows = (_visibleRows * 1.5).ceil();

    // unitSize가 클수록 더 많은 원본 데이터 필요
    // (큰 unitSize는 여러 가격대를 통합하므로)
    int multiplier;
    if (unitSize <= 0.1) {
      multiplier = 1; // 0.1: 거의 원본 그대로
    } else if (unitSize <= 1) {
      multiplier = 2; // 1: 10개 가격대 통합
    } else if (unitSize <= 10) {
      multiplier = 5; // 10: 100개 가격대 통합
    } else if (unitSize <= 50) {
      multiplier = 10; // 50: 500개 가격대 통합
    } else {
      multiplier = 20; // 100: 1000개 가격대 통합
    }

    final calculatedLimit = desiredRows * multiplier;

    // Binance API의 limit 제약에 맞춰 조정
    // 유효한 limit: 5, 10, 20, 50, 100, 500, 1000, 5000
    if (calculatedLimit <= 5) return 5;
    if (calculatedLimit <= 10) return 10;
    if (calculatedLimit <= 20) return 20;
    if (calculatedLimit <= 50) return 50;
    if (calculatedLimit <= 100) return 100;
    if (calculatedLimit <= 500) return 500;
    if (calculatedLimit <= 1000) return 1000;
    return 5000; // 최대값
  }

  @override
  void initState() {
    super.initState();

    _fetchOrderBook();

    // 1초마다 오더북 업데이트
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _fetchOrderBook();
    });
  }

  @override
  void didUpdateWidget(OrderbookWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.position != widget.position) setState(() {});
  }

  Widget _buildTickSizeDropdown() {
    return StatefulBuilder(
      builder: (context, setDropdownState) {
        return Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E11),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: DropdownButton<double>(
            value: unitSize,
            isDense: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E2329),
            menuMaxHeight: 250,
            style: AppTheme.num10.copyWith(
              color: Colors.grey[400],
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Colors.grey[600],
            ),
            items: unitSizes.map((size) {
              return DropdownMenuItem<double>(
                value: size,
                child: Text(
                  size >= 1 ? size.toInt().toString() : size.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
            onChanged: (newSize) {
              if (newSize != null) {
                setState(() {
                  unitSize = newSize;
                  _fetchOrderBook(); // 틱 사이즈 변경 시 오더북 재로드
                });
                // 드롭다운만 업데이트
                setDropdownState(() {});
              }
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _lastOrderbookTime = 0;
  String? _lastOrderBookText;

  Future<void> _fetchOrderBook() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastOrderbookTime < 300) return;

      _lastOrderbookTime = now;

      // 틱 사이즈와 화면 높이에 따라 적절한 limit 계산
      final limit = _calculateOptimalLimit();
      final url = '/api/futures/orderbook/$symbol?depth=$limit';

      final response = await http.get(
        Config.getUri(url),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (!mounted) return;

        // 새 API 응답 형식: { "result": 0, "orderbook": { "bids": [...], "asks": [...] } }
        if (data['result'] == 0 && data['orderbook'] != null) {
          final orderbook = data['orderbook'];
          String _orderbookText = jsonEncode(
              {'bids': orderbook['bids'], 'asks': orderbook['asks']});

          // if (_lastOrderBookText == _orderbookText) {
          //   print(
          //       '_fetchOrderbook: orderbook not changed [bids: ${orderbook['bids'].length}, asks: ${orderbook['asks'].length}]');
          // }

          _lastOrderBookText = _orderbookText;

          setState(() {
            // Asks 파싱 및 그룹화 (매도 호가 - 높은 가격부터 정렬 = 내림차순)
            asks = _parseServerOrderBook(
              orderbook['asks'] as List,
              ascending: false,
              unitSize: unitSize,
            );

            // Bids 파싱 및 그룹화 (매수 호가 - 높은 가격부터 정렬 = 내림차순)
            bids = _parseServerOrderBook(
              orderbook['bids'] as List,
              ascending: false,
              unitSize: unitSize,
            );

            // 현재가 계산 (최고 매수가와 최저 매도가의 중간값)
            if (asks.isNotEmpty && bids.isNotEmpty) {
              previousPrice = currentPrice; // 이전 가격 저장
              currentPrice = (asks.first.price + bids.first.price) / 2;

              uncontrolledContainer.read(currentPriceProvider.notifier).state =
                  currentPrice;

              // 가격 방향 업데이트
              if (previousPrice == 0 || currentPrice == previousPrice) {
                priceDirection = 0; // 변동 없음
              } else if (currentPrice > previousPrice) {
                priceDirection = 1; // 상승
              } else {
                priceDirection = -1; // 하락
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('오더북 데이터 가져오기 실패: $e');
    }
  }

  /// 서버 API 응답 형식 파싱
  /// 입력: [{ "price": "50000.00", "quantity": "1.5" }, ...]
  List<OrderBookEntry> _parseServerOrderBook(
    List<dynamic> rawData, {
    required bool ascending,
    required double unitSize,
  }) {
    final Map<double, ({double btc, double usdt})> priceMap = {};

    for (var item in rawData) {
      final price = double.parse(item['price'].toString());
      final btcQuantity = double.parse(item['quantity'].toString());
      final usdtSize = price * btcQuantity; // USDT 크기 = 가격 × BTC 수량

      // 틱 사이즈로 반올림
      final roundedPrice = (price / unitSize).round() * unitSize;

      // 같은 가격대의 BTC 수량과 USDT 크기 합산
      final existing = priceMap[roundedPrice];
      priceMap[roundedPrice] = (
        btc: (existing?.btc ?? 0) + btcQuantity,
        usdt: (existing?.usdt ?? 0) + usdtSize,
      );
    }

    // Map을 리스트로 변환하고 정렬
    final entries = priceMap.entries.map((entry) {
      return OrderBookEntry(
        price: entry.key,
        quantity: entry.value.btc,
        usdtSize: entry.value.usdt,
        total: 0,
      );
    }).toList();

    // 가격 순으로 정렬 (ascending: true = 오름차순, false = 내림차순)
    entries.sort((a, b) =>
        ascending ? a.price.compareTo(b.price) : b.price.compareTo(a.price));

    return entries;
  }

  void _calculateTotals(int visibleRows) {
    // Asks의 Total 계산
    // ListView가 reverse=true이므로 화면상 아래에서 위로 누적
    // 낮은 가격(index 0)부터 시작
    double askTotal = 0;
    visibleAsks.clear();
    for (var i = 0; i < visibleRows && i < asks.length; i++) {
      var ask = asks[i];
      askTotal += showUsdtMode ? ask.usdtSize : ask.quantity;
      ask.total = askTotal;
      visibleAsks.insert(0, ask);
    }

    // Bids의 Total 계산
    // ListView가 정순이므로 화면상 위에서 아래로 누적
    // 높은 가격(index 0)부터 시작
    visibleBids.clear();
    double bidTotal = 0;
    for (var i = 0; i < visibleRows && i < bids.length; i++) {
      var bid = bids[i];
      bidTotal += showUsdtMode ? bid.usdtSize : bid.quantity;
      bid.total = bidTotal;
      visibleBids.add(bid);
    }

    maxTotal = askTotal > bidTotal ? askTotal : bidTotal;
  }

  void updateVisibleItems(double maxHeight) {
    final visibleRows = (maxHeight / 20).ceil();

    // 보이는 행 수가 변경되었으면 오더북 다시 가져오기
    if (_visibleRows != visibleRows * 2) {
      // * 2 = 매도 + 매수
      final previousVisibleRows = _visibleRows;
      _visibleRows = visibleRows * 2;

      // 행 수가 크게 변경되었을 때만 재요청 (최적화)
      if ((previousVisibleRows - _visibleRows).abs() > 5) {
        _fetchOrderBook();
      }
    }

    _calculateTotals(visibleRows);
  }

  @override
  Widget build(BuildContext context) {
    // 데이터 로딩 중
    if (asks.isEmpty && bids.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // 상단 헤더 (position이 left일 때만)
        if (widget.position == OrderBookPosition.left) _buildTopHeader(),

        // 컬럼 헤더
        _buildColumnHeader(),

        ..._buildOrderList(),
        // 하단 헤더 (position이 bottom일 때만)
        if (widget.position == OrderBookPosition.bottom) _buildBottomHeader(),
      ],
    );
  }

  List<Widget> _buildOrderList() {
    switch (_orderBookMode) {
      case OrderbookDisplayMode.both:
        return [
          // 매도 호가 (위쪽)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                updateVisibleItems(constraints.maxHeight);

                return ListView.builder(
                  reverse: true,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemExtent: 20,
                  itemCount: visibleAsks.length,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final ask = visibleAsks[index];
                    return _buildOrderBookRowWithMax(
                      ask,
                      true, // isAsk
                      index,
                      maxTotal,
                    );
                  },
                );
              },
            ),
          ),

          // 현재가
          _buildCurrentPrice(),

          // 매수 호가 (아래쪽)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                updateVisibleItems(constraints.maxHeight);

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: visibleBids.length,
                  shrinkWrap: true,
                  itemExtent: 20,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final bid = visibleBids[index];
                    return _buildOrderBookRowWithMax(
                      bid,
                      false, // isBid
                      index,
                      maxTotal,
                    );
                  },
                );
              },
            ),
          ),
        ];

      case OrderbookDisplayMode.askOnly:
        return [
          // 매도 호가 (위쪽)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                updateVisibleItems(constraints.maxHeight);

                return ListView.builder(
                  reverse: true,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemExtent: 20,
                  itemCount: visibleAsks.length,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final ask = visibleAsks[index];
                    return _buildOrderBookRowWithMax(
                      ask,
                      true, // isAsk
                      index,
                      maxTotal,
                    );
                  },
                );
              },
            ),
          ),
        ];

      case OrderbookDisplayMode.bidOnly:
        return [
          // 매수 호가 (아래쪽)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                updateVisibleItems(constraints.maxHeight);

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: visibleBids.length,
                  shrinkWrap: true,
                  itemExtent: 20,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final bid = visibleBids[index];
                    return _buildOrderBookRowWithMax(
                      bid,
                      false, // isBid
                      index,
                      maxTotal,
                    );
                  },
                );
              },
            ),
          ),
        ];
    }
  }

  int? hOverIndex;

  OrderbookDisplayMode _orderBookMode = OrderbookDisplayMode.both;

  Widget _buildTopHeader() {
    return Container(
      height: 36,
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
          OrderbookDisplayModeSelector(
            initialMode: _orderBookMode,
            showFullList: true,
            onModeChanged: (v) {
              setState(() {
                _orderBookMode = v;
              });
            },
          ),
          Expanded(child: Container()),
          // 틱 사이즈 드롭다운
          _buildTickSizeDropdown(),
        ],
      ),
    );
  }

  Widget _buildColumnHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showMiddleColumn =
            constraints.maxWidth > middleColumnDisplayThreshold;

        return Container(
          height: 30,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '가격(USDT)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (showMiddleColumn)
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        showUsdtMode = !showUsdtMode;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          showUsdtMode ? '크기(USDT)' : '수량(BTC)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_horiz,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                flex: 2,
                child: Text(
                  showUsdtMode ? '합계(USDT)' : '합계(BTC)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomHeader() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          OrderbookDisplayModeSelector(
            initialMode: _orderBookMode,
            showFullList: false,
            onModeChanged: (v) {
              setState(() {
                _orderBookMode = v;
              });
            },
          ),
          Expanded(child: Container()),
          // 틱 사이즈 드롭다운
          _buildTickSizeDropdown(),
        ],
      ),
    );
  }

  Widget _buildOrderBookRowWithMax(
    OrderBookEntry entry,
    bool isAsk,
    int index,
    double localMaxTotal,
  ) {
    final color = isAsk ? AppTheme.downColor : AppTheme.upColor;
    final backgroundColor = isAsk ? AppTheme.downColorBg : AppTheme.upColorBg;

    final percentage = localMaxTotal > 0 ? entry.total / localMaxTotal : 0.0;

    // 표시할 값 선택 (모드에 따라)
    final displayValue = showUsdtMode ? entry.usdtSize : entry.quantity;

    // 현재 행이 호버 상태인지 확인
    final isHovered = hOverIndex == (isAsk ? index : -index);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showMiddleColumn =
            constraints.maxWidth > middleColumnDisplayThreshold;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) {
            setState(() {
              hOverIndex = isAsk ? index : -index;
            });
          },
          onExit: (_) {
            setState(() {
              hOverIndex = null;
            });
          },
          child: GestureDetector(
            onTap: () {
              // 오더북 클릭 시 주문 패널의 가격 입력창에 가격 설정
              ref.read(orderPriceProvider.notifier).setPrice(entry.price);
            },
            child: Stack(
              children: [
                // 배경 바 (누적량 표시) - Row로 변경
                Row(
                  children: [
                    // 빈 공간
                    Expanded(
                      flex: ((1 - percentage) * 100).toInt(),
                      child: Container(),
                    ),
                    // 배경 바
                    Expanded(
                      flex: (percentage * 100).toInt(),
                      child: Container(
                        color: backgroundColor,
                      ),
                    ),
                  ],
                ),

                // 호버 배경 (누적량 위에 표시)
                if (isHovered)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),

                // 텍스트
                Row(
                  children: [
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _getPriceFormat(unitSize).format(entry.price),
                        style: AppTheme.num12.copyWith(
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (showMiddleColumn) ...[
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          showUsdtMode
                              ? amountFormat.format(displayValue)
                              : quantityFormat.format(displayValue),
                          textAlign: TextAlign.right,
                          style: AppTheme.num12.copyWith(
                            color: Colors.white,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        showUsdtMode
                            ? amountFormat.format(entry.total)
                            : quantityFormat.format(entry.total),
                        textAlign: TextAlign.right,
                        style: AppTheme.num12.copyWith(
                          color: Colors.grey[400],
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentPrice() {
    // 가격 변동 방향 계산
    Color priceColor;
    IconData? priceIcon;

    if (priceDirection == 0) {
      // 변동 없음 - 아이콘 표시 안 함
      priceColor = Colors.white;
      priceIcon = null;
    } else if (priceDirection == 1) {
      // 상승
      priceColor = AppTheme.upColor;
      priceIcon = Icons.arrow_upward;
    } else {
      // 하락
      priceColor = AppTheme.downColor;
      priceIcon = Icons.arrow_downward;
    }

    return Container(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Text(
              _getPriceFormat(unitSize).format(currentPrice),
              style: AppTheme.num16.copyWith(
                color: priceColor,
              ),
            ),
            const SizedBox(width: 4),
            // 아이콘 애니메이션
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: priceIcon != null
                  ? Icon(
                      priceIcon,
                      key: ValueKey<int>(priceDirection), // 방향이 바뀔 때 애니메이션 트리거
                      color: priceColor,
                      size: 16,
                    )
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      key: ValueKey<int>(0),
                    ),
            ),
            const Spacer(),
            Text(
              '${_getPriceFormat(unitSize).format(currentPrice)}',
              style: AppTheme.num12.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 호가창 개별 항목 모델
class OrderBookEntry {
  final double price;
  final double quantity; // BTC 수량
  final double usdtSize; // USDT 크기 (price × quantity)
  double total; // 누적 합계 (모드에 따라 BTC 또는 USDT)

  OrderBookEntry({
    required this.price,
    required this.quantity,
    required this.usdtSize,
    required this.total,
  });
}
