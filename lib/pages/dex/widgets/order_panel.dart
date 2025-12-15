import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:perpdex/common/all.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '/api/netclient.dart';
import '/common/widgets/slider_shapes.dart';
import '/wallet/providers/ethereum_wallet_provider.dart';
import '/wallet/widgets/wallet_selection_overlay.dart';
import '../providers/account_settings_provider.dart';
import '../providers/order_provider.dart';
import '../providers/position_provider.dart';
import '../providers/leverage_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/leverage_tier_provider.dart';
import '../../../data/providers.dart';
import 'leverage_dialog.dart';

/// 주문 타입 enum
enum OrderType {
  market('시장가'),
  limit('지정가'),
  stopLimit('Stop Limit'),
  stopMarket('Stop Market'),
  trailingStop('Trailing Stop'),
  postOnly('Post Only');

  final String label;
  const OrderType(this.label);

  /// 가격 입력이 필요한 주문 타입인지
  bool get requiresPrice =>
      this == limit || this == postOnly || this == stopLimit;

  /// 숨겨진 주문 옵션을 표시할 수 있는 주문 타입인지
  bool get supportsHiddenOrder =>
      this == limit || this == postOnly || this == stopLimit;
}

/// 주문 패널 위젯
/// - 레버리지 선택, 주문 수량 입력, 매수/매도 버튼
class OrderPanel extends ConsumerStatefulWidget {
  const OrderPanel({super.key});

  @override
  ConsumerState<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends ConsumerState<OrderPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final NumberFormat numberFormat = NumberFormat('#,##0.00', 'en_US');

  // 주문 타입
  OrderType orderType = OrderType.limit;

  // 수량 슬라이더 (0~100%)
  double quantityPercentage = 0;

  // 슬라이더를 통해 입력했는지 여부
  bool isSliderInput = false;

  // 가격 단위 (USDT 또는 BTC)
  String priceUnit = 'BTC';

  // 체크박스 상태
  bool tpSlEnabled = false;
  bool hiddenOrderEnabled = false;
  bool reduceOnlyEnabled = false;

  // Stop Price 관련
  String stopPriceType = 'Mark'; // Mark 또는 Last

  // TP/SL 관련
  String takeProfitPriceType = 'Mark'; // Mark 또는 Last
  String takeProfitValueType = 'PnL'; // Price 또는 PnL
  String stopLossPriceType = 'Mark'; // Mark 또는 Last
  String stopLossValueType = 'PnL'; // Price 또는 PnL

  // 주문 진행 중
  bool _isSubmitting = false;

  // 심볼 (추후 동적으로 변경)
  final String symbol = 'BTCUSDT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 초기 잔고 및 레버리지 티어 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(balanceProvider.notifier).fetchBalance();
      ref.read(leverageTierProvider.notifier).fetchTiers(symbol);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 주문 실행
  Future<void> _submitOrder(String side) async {
    if (_isSubmitting) return;

    // 입력값 가져오기
    final priceText = InputManager().getText(inputTagOrderPrice) ?? '';
    final quantityText = InputManager().getText(inputTagOrderQuantity) ?? '';
    final stopPriceText = InputManager().getText(inputTagStopPrice) ?? '';
    final trailingPercentText =
        InputManager().getText(inputTagTrailingPercent) ?? '';
    final activationPriceText =
        InputManager().getText(inputTagActivationPrice) ?? '';

    // 수량 검증 및 변환
    double quantity =
        parseDouble(quantityText.replaceAll(',', '').replaceAll('%', ''));

    // 가격 가져오기
    double orderPrice = ref.read(currentPriceProvider);
    if (orderType.requiresPrice) {
      final inputPrice = parseDouble(priceText.replaceAll(',', ''));
      if (inputPrice > 0) {
        orderPrice = inputPrice;
      } else {
        Util.toastError('가격을 입력해주세요');
        return;
      }
    }

    // 슬라이더 모드인 경우 퍼센트를 실제 수량으로 변환
    if (isSliderInput && quantity > 0) {
      if (orderPrice > 0) {
        final availableBalance =
            ref.read(balanceProvider).balance.availableBalance;
        final leverage =
            ref.read(leverageProvider.notifier).getLeverage(symbol);
        // 서버 레버리지 티어의 maxNotional 제한 적용
        final maxQuantity =
            ref.read(leverageTierProvider.notifier).calculateMaxQuantity(
                  symbol: symbol,
                  availableBalance: availableBalance,
                  leverage: leverage.toInt(),
                  price: orderPrice,
                );
        quantity = maxQuantity * (quantity / 100);
      }
    } else if (priceUnit == 'USDT' && quantity > 0) {
      // USDT로 입력된 경우 BTC 수량으로 변환
      if (orderPrice > 0) {
        quantity = quantity / orderPrice;
      }
    }

    if (quantity <= 0) {
      Util.toastError('수량을 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final leverage = ref.read(leverageProvider.notifier).getLeverage(symbol);
      final marginMode = ref.read(accountSettingsProvider).marginMode;
      dynamic result;

      // 주문 타입에 따라 다른 API 호출
      switch (orderType) {
        // 일반 주문: POST /api/futures/orders
        case OrderType.market:
          result = await ServerAPI().createFuturesOrder({
            'symbol': symbol,
            'side': side,
            'type': 'MARKET',
            'quantity': quantity.toString(),
            'leverage': leverage.toInt(),
            'marginMode': marginMode.apiValue,
            'reduceOnly': reduceOnlyEnabled,
          });
          break;

        case OrderType.limit:
          result = await ServerAPI().createFuturesOrder({
            'symbol': symbol,
            'side': side,
            'type': 'LIMIT',
            'quantity': quantity.toString(),
            'price': orderPrice.toString(),
            'leverage': leverage.toInt(),
            'marginMode': marginMode.apiValue,
            'reduceOnly': reduceOnlyEnabled,
          });
          break;

        case OrderType.postOnly:
          result = await ServerAPI().createFuturesOrder({
            'symbol': symbol,
            'side': side,
            'type': 'POST_ONLY',
            'quantity': quantity.toString(),
            'price': orderPrice.toString(),
            'leverage': leverage.toInt(),
            'marginMode': marginMode.apiValue,
            'reduceOnly': reduceOnlyEnabled,
          });
          break;

        // 조건부 주문: POST /api/futures/conditionorders
        case OrderType.stopLimit:
          final triggerPrice = parseDouble(stopPriceText.replaceAll(',', ''));
          if (triggerPrice <= 0) {
            Util.toastError('Stop Price를 입력해주세요');
            setState(() => _isSubmitting = false);
            return;
          }
          result = await ServerAPI().createConditionOrder({
            'symbol': symbol,
            'orderType': 'STOP_LIMIT',
            'side': side,
            'quantity': quantity.toString(),
            'triggerPrice': triggerPrice.toString(),
            'orderPrice': orderPrice.toString(),
            'triggerType':
                stopPriceType == 'Mark' ? 'MARK_PRICE' : 'LAST_PRICE',
            'leverage': leverage.toInt(),
            'reduceOnly': reduceOnlyEnabled,
          });
          break;

        case OrderType.stopMarket:
          final triggerPrice = parseDouble(stopPriceText.replaceAll(',', ''));
          if (triggerPrice <= 0) {
            Util.toastError('Stop Price를 입력해주세요');
            setState(() => _isSubmitting = false);
            return;
          }
          result = await ServerAPI().createConditionOrder({
            'symbol': symbol,
            'orderType': 'STOP_MARKET',
            'side': side,
            'quantity': quantity.toString(),
            'triggerPrice': triggerPrice.toString(),
            'triggerType':
                stopPriceType == 'Mark' ? 'MARK_PRICE' : 'LAST_PRICE',
            'leverage': leverage.toInt(),
            'reduceOnly': reduceOnlyEnabled,
          });
          break;

        case OrderType.trailingStop:
          final callbackRate = parseDouble(
              trailingPercentText.replaceAll(',', '').replaceAll('%', ''));
          final activationPrice =
              parseDouble(activationPriceText.replaceAll(',', ''));
          if (callbackRate <= 0) {
            Util.toastError('Callback Rate를 입력해주세요');
            setState(() => _isSubmitting = false);
            return;
          }
          if (activationPrice <= 0) {
            Util.toastError('Activation Price를 입력해주세요');
            setState(() => _isSubmitting = false);
            return;
          }
          result = await ServerAPI().createConditionOrder({
            'symbol': symbol,
            'orderType': 'TRAILING_STOP',
            'side': side,
            'quantity': quantity.toString(),
            'activationPrice': activationPrice.toString(),
            'callbackRate': (callbackRate / 100).toString(), // % -> 소수점 변환
            'triggerType':
                activationPriceType == 'Mark' ? 'MARK_PRICE' : 'LAST_PRICE',
            'leverage': leverage.toInt(),
            'reduceOnly': reduceOnlyEnabled,
          });
          break;
      }

      if (result != null && result['result'] == 0) {
        Util.toastNotice('${side == 'BUY' ? '매수' : '매도'} 주문이 접수되었습니다');
        // 입력 초기화
        _clearOrderInputs();
        // 주문 목록 새로고침
        ref.read(orderListProvider.notifier).fetchOrders(status: 'OPEN');
        // 포지션 목록 새로고침
        ref.read(positionListProvider.notifier).fetchPositions();
        // 잔고 새로고침
        ref.read(balanceProvider.notifier).fetchBalance();
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '주문 실패';
        Util.showAlert(errorMsg);
      }
    } catch (e) {
      Util.toastError('주문 처리 중 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 주문 입력 필드 초기화
  void _clearOrderInputs() {
    InputManager().setText(inputTagOrderQuantity, '');
    InputManager().setText(inputTagStopPrice, '');
    InputManager().setText(inputTagTrailingPercent, '');
    InputManager().setText(inputTagActivationPrice, '');
    setState(() {
      quantityPercentage = 0;
      isSliderInput = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 잔고 구독
    final balanceState = ref.watch(balanceProvider);
    final availableBalance = balanceState.balance.availableBalance;

    // 오더북에서 클릭한 가격 구독
    final selectedPrice = ref.watch(orderPriceProvider);

    // 가격이 업데이트되면 TextField에 반영
    if (selectedPrice != null && orderType.requiresPrice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        InputManager()
            .setText(inputTagOrderPrice, numberFormat.format(selectedPrice));
        updateQuantity();
        ref.read(orderPriceProvider.notifier).clearPrice();
      });
    }

    return Column(
      children: [
        // 헤더 (매수/매도 탭)
        _buildHeader(),

        // 주문 폼
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 가용 잔고 표시
                _buildBalanceInfo(availableBalance),
                const SizedBox(height: 16),

                // 주문 타입별 가격 입력 필드들
                ..._buildPriceInputFields()
                    .expand((widget) => [widget, const SizedBox(height: 12)]),

                // 수량 입력
                _buildQuantityInput(),
                const SizedBox(height: 20),

                // 수량 프리셋 버튼
                _buildQuantityPresets(),
                const SizedBox(height: 16),

                // 체크박스 옵션들
                _buildCheckboxOptions(),

                // TP/SL 입력 필드 (체크 시 표시)
                ..._buildTpSlFields()
                    .expand((widget) => [const SizedBox(height: 12), widget]),
                const SizedBox(height: 16),

                // 매수/매도 버튼
                _buildOrderButtons(),
              ],
            ),
          ),
        ),

        // 하단 정보
        _buildBottomInfo(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      child: Column(
        children: [
          // 첫 번째 줄: 크로스, 레버리지, 모드
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 8,
                children: [
                  // 크로스/격리 버튼
                  Expanded(child: _buildMarginModeButton()),
                  // 레버리지 버튼
                  Expanded(child: _buildLeverageButton()),
                  // 자산 모드 버튼
                  Expanded(child: _buildAssetModeButton()),
                ],
              ),
            ),
          ),
          // 두 번째 줄: 시장가, 지정가, 고급 주문 탭
          Container(
            height: 40,
            child: Row(
              children: [
                Expanded(child: _buildOrderTypeTab(OrderType.market)),
                Expanded(child: _buildOrderTypeTab(OrderType.limit)),
                Expanded(child: _buildAdvancedOrderDropdown()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopButton(
      String currentValue, List<String> values, Function(String) onChanged) {
    return InkWell(
      onTap: () {
        if (values.length > 1) {
          // 크로스/격리처럼 토글 가능한 경우
          final currentIndex = values.indexOf(currentValue);
          final nextIndex = (currentIndex + 1) % values.length;
          onChanged(values[nextIndex]);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.dexSecondary,
        ),
        child: Center(
          child: Text(
            currentValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginModeButton() {
    final accountSettings = ref.watch(accountSettingsProvider);

    return InkWell(
      onTap: _showMarginModeDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.dexSecondary,
        ),
        child: Center(
          child: Text(
            accountSettings.marginMode.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// 마진 모드 선택 다이얼로그
  void _showMarginModeDialog() {
    final accountSettings = ref.read(accountSettingsProvider);
    MarginMode selectedMode = accountSettings.marginMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final walletState = ref.read(ethereumWalletProvider);
          final isAuthenticated = walletState.isAuthenticated;

          return Dialog(
            backgroundColor: AppTheme.popupBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: SelectionArea(
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BTCUSDT 마진 모드',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 설명
                    Text(
                      '마진 모드 전환은 선택된 계약에만 적용됩니다',
                      style: AppTheme.bodyMediumBold,
                    ),
                    const SizedBox(height: 16),
                    // 크로스/격리 선택 버튼
                    Row(
                      spacing: 8,
                      children: MarginMode.values.map((mode) {
                        final isSelected = selectedMode == mode;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedMode = mode;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.dexSecondary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    mode.label,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.check,
                                        color: Colors.white, size: 16),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // 격리 모드 선택 + 멀티 에셋 모드일 때 추가 옵션
                    if (selectedMode == MarginMode.isolated &&
                        accountSettings.assetMode == AssetMode.multi) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.popupSubBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '격리 모드는 단일 자산 모드만 지원합니다. 자산 모드를 조정하세요.',
                              style: AppTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '단일 자산 모드',
                                  style: AppTheme.bodyMediumBold
                                      .copyWith(color: Colors.white),
                                ),
                                Container(
                                  width: 36,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      margin: const EdgeInsets.only(left: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 설명 텍스트
                    Text(
                      '크로스 모드와 아이솔레이트 모드란 무엇인가요?',
                      style:
                          AppTheme.bodyMediumBold.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '포지션에 할당된 마진은 특정 금액으로 제한됩니다. 만약 유지 마진 수준 아래로 마진이 떨어지면 포지션이 청산됩니다. 그러나 이 모드에서는 마진을 자유롭게 추가하거나 제거할 수 있습니다.',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    // 지갑 연결 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isAuthenticated) {
                            if (selectedMode != accountSettings.marginMode) {
                              ref
                                  .read(accountSettingsProvider.notifier)
                                  .setMarginMode(selectedMode);
                            }
                          } else {
                            showWalletSelectionOverlay(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          isAuthenticated ? '확인' : '지갑 연결',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetModeButton() {
    final accountSettings = ref.watch(accountSettingsProvider);

    return InkWell(
      onTap: _showAssetModeDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.dexSecondary,
        ),
        child: Center(
          child: Text(
            accountSettings.assetMode.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// 자산 모드 선택 다이얼로그
  void _showAssetModeDialog() {
    final accountSettings = ref.read(accountSettingsProvider);
    AssetMode selectedMode = accountSettings.assetMode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final walletState = ref.read(ethereumWalletProvider);
          final isAuthenticated = walletState.isAuthenticated;

          return Dialog(
            backgroundColor: AppTheme.popupBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: SelectionArea(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '자산 모드',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 단일 자산 모드 옵션
                    _buildAssetModeOption(
                      mode: AssetMode.single,
                      selectedMode: selectedMode,
                      title: '단일 자산 모드',
                      descriptions: [
                        '거래 계약의 마진으로 USDT만 지원합니다.',
                        '동일한 마진 자산을 가진 포지션의 손익은 상쇄될 수 있습니다.',
                        '크로스 마진 및 격리 마진을 지원합니다.',
                      ],
                      onTap: () {
                        setDialogState(() {
                          selectedMode = AssetMode.single;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // 다중 자산 모드 옵션
                    _buildAssetModeOption(
                      mode: AssetMode.multi,
                      selectedMode: selectedMode,
                      title: '다중 자산 모드',
                      descriptions: [
                        '계약은 마진 자산을 통해 거래될 수 있습니다.',
                        '서로 다른 마진 자산을 가진 포지션의 손익은 상쇄될 수 있습니다.',
                        '크로스 마진 모드만 지원합니다.',
                      ],
                      onTap: () {
                        setDialogState(() {
                          selectedMode = AssetMode.multi;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 하단 안내 텍스트
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '위험 관리를 개선하기 위해 ',
                            style: AppTheme.bodyMedium
                                .copyWith(color: Colors.grey),
                          ),
                          TextSpan(
                            text: '멀티 자산 모드',
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse(
                                    'https://docs.asterdex.com/product/aster-perpetual-pro/single-asset-mode-and-multi-asset-mode'));
                              },
                            style: AppTheme.bodyMedium
                                .copyWith(color: AppTheme.primary),
                          ),
                          TextSpan(
                            text: '에 대해 읽어보십시오.',
                            style: AppTheme.bodyMedium
                                .copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                              ),
                            ),
                            child: Text(
                              '취소',
                              style: AppTheme.bodyMedium
                                  .copyWith(color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              if (isAuthenticated) {
                                if (selectedMode != accountSettings.assetMode) {
                                  ref
                                      .read(accountSettingsProvider.notifier)
                                      .setAssetMode(selectedMode);
                                }
                              } else {
                                showWalletSelectionOverlay(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                              ),
                            ),
                            child: Text(
                              isAuthenticated ? '확인' : '지갑 연결',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 자산 모드 옵션 위젯
  Widget _buildAssetModeOption({
    required AssetMode mode,
    required AssetMode selectedMode,
    required String title,
    required List<String> descriptions,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedMode == mode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 체크박스
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...descriptions.map((desc) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          desc,
                          style:
                              AppTheme.bodyMedium.copyWith(color: Colors.grey),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeverageButton() {
    // watch를 사용하여 레버리지 변경 시 자동 업데이트
    final leverageMap = ref.watch(leverageProvider);
    final leverage = leverageMap[symbol] ?? 20.0;

    return InkWell(
      onTap: () {
        showDialog<double>(
          context: context,
          builder: (context) => LeverageDialog(
            currentLeverage: leverage,
            symbol: symbol,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.dexSecondary,
        ),
        child: Center(
          child: Text(
            '${leverage.toInt()}x',
            style: AppTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  // 고급 주문 타입 목록
  final List<OrderType> _advancedOrderTypes = [
    OrderType.stopLimit,
    OrderType.stopMarket,
    OrderType.trailingStop,
    OrderType.postOnly,
  ];

  Widget _buildOrderTypeTab(OrderType type) {
    final isSelected = orderType == type;
    return InkWell(
      onTap: () {
        setState(() {
          orderType = type;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.upColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          type.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedOrderDropdown() {
    // 현재 선택된 타입이 고급 주문 타입인지 확인
    final isAdvancedSelected = _advancedOrderTypes.contains(orderType);

    return PopupMenuButton<OrderType>(
      onSelected: (value) {
        setState(() {
          orderType = value;
        });
      },
      offset: const Offset(0, 40),
      color: AppTheme.dexSecondary,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isAdvancedSelected ? AppTheme.upColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isAdvancedSelected ? orderType.label : OrderType.stopLimit.label,
              style: TextStyle(
                color: isAdvancedSelected ? Colors.white : Colors.grey,
                fontSize: 13,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: isAdvancedSelected ? Colors.white : Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _advancedOrderTypes.map((type) {
        return PopupMenuItem<OrderType>(
          value: type,
          child: Text(
            type.label,
            style: TextStyle(
              color: orderType == type ? AppTheme.upColor : Colors.white,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBalanceInfo(double availableBalance) {
    return Row(
      spacing: 4,
      children: [
        Text(
          '가능',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Row(
          children: [
            Text(
              Util.commaStringNumber(availableBalance.toStringAsFixed(2)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'USDT',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== 입력 필드 태그 ====================
  final String inputTagOrderPrice = 'inputTagOrderPrice';
  final String inputTagOrderQuantity = 'inputTagOrderQuantity';
  final String inputTagStopPrice = 'inputTagStopPrice';
  final String inputTagTrailingPercent = 'inputTagTrailingPercent';
  final String inputTagActivationPrice = 'inputTagActivationPrice';
  final String inputTagTakeProfit = 'inputTagTakeProfit';
  final String inputTagStopLoss = 'inputTagStopLoss';

  // Activation Price 타입 (Mark 또는 Last)
  String activationPriceType = 'Mark';

  // ==================== 주문 타입별 입력 필드 구성 ====================

  /// 주문 타입에 따른 가격 입력 필드들을 반환
  List<Widget> _buildPriceInputFields() {
    switch (orderType) {
      case OrderType.market:
        return []; // 가격 입력 없음

      case OrderType.limit:
      case OrderType.postOnly:
        return [
          _buildInputField(
              tag: inputTagOrderPrice,
              hintText: 'Price',
              onBlur: updateQuantity),
        ];

      case OrderType.stopLimit:
        return [
          _buildInputFieldWithDropdown(
            tag: inputTagStopPrice,
            hintText: 'Stop Price',
            selectedValue: stopPriceType,
            options: ['Mark', 'Last'],
            onOptionSelected: (v) => setState(() => stopPriceType = v),
          ),
          _buildInputField(
              tag: inputTagOrderPrice,
              hintText: 'Price',
              onBlur: updateQuantity),
        ];

      case OrderType.stopMarket:
        return [
          _buildInputFieldWithDropdown(
            tag: inputTagStopPrice,
            hintText: 'Stop Price',
            selectedValue: stopPriceType,
            options: ['Mark', 'Last'],
            onOptionSelected: (v) => setState(() => stopPriceType = v),
          ),
          _buildReadOnlyField(text: 'Market Price'),
        ];

      case OrderType.trailingStop:
        return [
          _buildInputField(
              tag: inputTagTrailingPercent,
              hintText: 'Callback Rate',
              suffix: '%'),
          _buildInputFieldWithDropdown(
            tag: inputTagActivationPrice,
            hintText: 'Activation Price',
            selectedValue: activationPriceType,
            options: ['Mark', 'Last'],
            onOptionSelected: (v) => setState(() => activationPriceType = v),
          ),
        ];
    }
  }

  // ==================== 입력 필드 빌더 패턴 ====================

  /// 기본 입력 필드
  Widget _buildInputField({
    required String tag,
    String? hintText,
    String? suffix,
    VoidCallback? onBlur,
  }) {
    return IgnorePointer(
      ignoring: _isSubmitting,
      child: Opacity(
        opacity: _isSubmitting ? 0.5 : 1.0,
        child: InputManager().inputBuilder(
          tag,
          hintText: hintText,
          keyboardType: TextInputType.number,
          fillColor: const Color.fromARGB(255, 37, 38, 39),
          borderRadius: 0,
          height: 34,
          fontSize: 12,
          suffix: suffix,
          onFocusChange: onBlur != null
              ? (v) {
                  if (!v) onBlur();
                }
              : null,
        ),
      ),
    );
  }

  /// 드롭다운이 있는 입력 필드
  Widget _buildInputFieldWithDropdown({
    required String tag,
    required String hintText,
    required String selectedValue,
    required List<String> options,
    required Function(String) onOptionSelected,
  }) {
    return IgnorePointer(
      ignoring: _isSubmitting,
      child: Opacity(
        opacity: _isSubmitting ? 0.5 : 1.0,
        child: InputManager().inputBuilder(
          tag,
          hintText: hintText,
          keyboardType: TextInputType.number,
          fillColor: const Color.fromARGB(255, 37, 38, 39),
          borderRadius: 0,
          height: 34,
          fontSize: 12,
          suffixIcon: _buildDropdownSuffix(
            selectedValue: selectedValue,
            options: options,
            onSelected: onOptionSelected,
          ),
        ),
      ),
    );
  }

  /// 읽기 전용 필드 (Market Price 등)
  Widget _buildReadOnlyField({required String text}) {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 37, 38, 39),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  /// 드롭다운 suffix 위젯
  Widget _buildDropdownSuffix({
    required String selectedValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 34),
      color: AppTheme.dexSecondary,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedValue,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options.map((option) {
        return PopupMenuItem<String>(
          value: option,
          height: 36,
          child: Text(
            option,
            style: TextStyle(
              color: selectedValue == option ? AppTheme.upColor : Colors.white,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// TP/SL 입력 필드 (라벨에 드롭다운, 입력에도 드롭다운)
  Widget _buildTpSlInputField({
    required String tag,
    required String label,
    required String labelDropdownValue,
    required List<String> labelDropdownOptions,
    required Function(String) onLabelDropdownSelected,
    required String suffixDropdownValue,
    required List<String> suffixDropdownOptions,
    required Function(String) onSuffixDropdownSelected,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨 + 드롭다운
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            _buildSmallDropdown(
              selectedValue: labelDropdownValue,
              options: labelDropdownOptions,
              onSelected: onLabelDropdownSelected,
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 입력 필드
        IgnorePointer(
          ignoring: _isSubmitting,
          child: Opacity(
            opacity: _isSubmitting ? 0.5 : 1.0,
            child: InputManager().inputBuilder(
              tag,
              hintText: hintText,
              keyboardType: TextInputType.number,
              fillColor: const Color.fromARGB(255, 37, 38, 39),
              borderRadius: 0,
              height: 34,
              fontSize: 12,
              suffixIcon: _buildDropdownSuffix(
                selectedValue: suffixDropdownValue,
                options: suffixDropdownOptions,
                onSelected: onSuffixDropdownSelected,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 작은 드롭다운 (라벨 옆에 붙는 용도)
  Widget _buildSmallDropdown({
    required String selectedValue,
    required List<String> options,
    required Function(String) onSelected,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 20),
      color: AppTheme.dexSecondary,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedValue,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.grey,
              size: 14,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options.map((option) {
        return PopupMenuItem<String>(
          value: option,
          height: 32,
          child: Text(
            option,
            style: TextStyle(
              color: selectedValue == option ? AppTheme.upColor : Colors.white,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// TP/SL 입력 필드들 (tpSlEnabled가 true일 때만 표시)
  List<Widget> _buildTpSlFields() {
    if (!tpSlEnabled) return [];

    return [
      _buildTpSlInputField(
        tag: inputTagTakeProfit,
        label: 'Take Profit',
        hintText: 'TP',
        labelDropdownValue: takeProfitPriceType,
        labelDropdownOptions: ['Mark', 'Last'],
        onLabelDropdownSelected: (v) => setState(() => takeProfitPriceType = v),
        suffixDropdownValue: takeProfitValueType,
        suffixDropdownOptions: ['Price', 'PnL', 'ROI'],
        onSuffixDropdownSelected: (v) =>
            setState(() => takeProfitValueType = v),
      ),
      _buildTpSlInputField(
        tag: inputTagStopLoss,
        label: 'Stop Loss',
        hintText: 'SL',
        labelDropdownValue: stopLossPriceType,
        labelDropdownOptions: ['Mark', 'Last'],
        onLabelDropdownSelected: (v) => setState(() => stopLossPriceType = v),
        suffixDropdownValue: stopLossValueType,
        suffixDropdownOptions: ['Price', 'PnL', 'ROI'],
        onSuffixDropdownSelected: (v) => setState(() => stopLossValueType = v),
      ),
    ];
  }

  void updateQuantity() {
    if (quantityPercentage > 0)
      _updateQuantityFromPercentage(quantityPercentage);
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: _isSubmitting,
                child: Opacity(
                  opacity: _isSubmitting ? 0.5 : 1.0,
                  child: InputManager().inputBuilder(
                    inputTagOrderQuantity,
                    hintText: !isSliderInput ? '크기' : '',
                    keyboardType: TextInputType.number,
                    suffixStyle: AppTheme.bodySmall,
                    fillColor: const Color.fromARGB(255, 37, 38, 39),
                    borderRadius: 0,
                    height: 34,
                    fontSize: 12,
                    onChanged: (value) {
                      // 입력값이 변경될 때마다 UI 업데이트
                      setState(() {});
                    },
                    onFocusChange: (v) {
                      if (v) {
                        // 포커스를 받으면 직접 입력 모드로 전환
                        if (isSliderInput) {
                          setState(() {
                            isSliderInput = false;
                            // 현재 BTC 수량으로 변환하여 표시
                            final quantityText =
                                InputManager().getText(inputTagOrderQuantity) ??
                                    '';
                            final currentQuantity = parseDouble(quantityText
                                .replaceAll(',', '')
                                .replaceAll('%', ''));
                            if (currentQuantity > 0) {
                              // 퍼센트를 실제 수량으로 변환
                              double price = ref.read(currentPriceProvider);
                              if (orderType.requiresPrice) {
                                price = InputManager()
                                    .getDouble(inputTagOrderPrice);
                              }
                              if (price > 0) {
                                final availableBalance = ref
                                    .read(balanceProvider)
                                    .balance
                                    .availableBalance;
                                final leverage = ref
                                    .read(leverageProvider.notifier)
                                    .getLeverage(symbol);
                                // 서버 레버리지 티어의 maxNotional 제한 적용
                                final maxQuantity = ref
                                    .read(leverageTierProvider.notifier)
                                    .calculateMaxQuantity(
                                      symbol: symbol,
                                      availableBalance: availableBalance,
                                      leverage: leverage.toInt(),
                                      price: price,
                                    );
                                final actualQuantity =
                                    maxQuantity * (currentQuantity / 100);

                                // priceUnit에 따라 표시 형식 결정
                                if (priceUnit == 'USDT') {
                                  // USDT로 표시 (수량 × 가격)
                                  InputManager().setText(
                                      inputTagOrderQuantity,
                                      numberFormat
                                          .format(actualQuantity * price));
                                } else {
                                  // BTC로 표시
                                  InputManager().setText(inputTagOrderQuantity,
                                      numberFormat.format(actualQuantity));
                                }
                              }
                            }
                          });
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IgnorePointer(
              ignoring: _isSubmitting,
              child: Opacity(
                opacity: _isSubmitting ? 0.5 : 1.0,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 37, 38, 39),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButton<String>(
                    value: priceUnit,
                    underline: const SizedBox(),
                    dropdownColor: const Color.fromARGB(255, 37, 38, 39),
                    style: AppTheme.bodySmall.copyWith(color: Colors.white),
                    items: ['USDT', 'BTC'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          priceUnit = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityPresets() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: IgnorePointer(
        ignoring: _isSubmitting,
        child: Opacity(
          opacity: _isSubmitting ? 0.5 : 1.0,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                bottom: 0,
                child: Row(
                  children: [
                    SizedBox(width: 4),
                    _buildTickMark(),
                    Expanded(child: Container()),
                    _buildTickMark(),
                    Expanded(child: Container()),
                    _buildTickMark(),
                    Expanded(child: Container()),
                    _buildTickMark(),
                    Expanded(child: Container()),
                    _buildTickMark(),
                  ],
                ),
              ),
              SfSliderTheme(
                data: SfSliderThemeData(
                  activeTrackHeight: 4,
                  inactiveTrackHeight: 0,
                  trackCornerRadius: 0,
                  overlayRadius: 4.0,
                  thumbRadius: 4.0,
                ),
                child: SfSlider(
                  value: quantityPercentage,
                  min: 0.0,
                  max: 100.0,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.primary.withValues(alpha: 0.2),
                  trackShape: CustomSfTrackShape(),
                  thumbShape: const CustomSfRectThumbShape(),
                  onChanged: (dynamic value) {
                    setState(() {
                      quantityPercentage = value as double;
                      isSliderInput = true; // 슬라이더를 통한 입력
                      _updateQuantityFromPercentage(value);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickMark() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.primary,
      ),
    );
  }

  void _updateQuantityFromPercentage(double percentage) {
    final currentPrice = ref.read(currentPriceProvider);
    if (currentPrice == 0) return;

    // 시장가일 경우 현재가 사용, 지정가일 경우 입력된 가격 사용
    double price = currentPrice;
    if (orderType.requiresPrice) {
      price = InputManager().getDouble(inputTagOrderPrice);
    }

    if (isSliderInput) {
      // 슬라이더 입력일 때는 퍼센트로 표시
      InputManager()
          .setText(inputTagOrderQuantity, '${percentage.toStringAsFixed(0)}%');
    } else {
      // 직접 입력일 때는 실제 수량으로 표시
      final percent = percentage / 100;
      final availableBalance =
          ref.read(balanceProvider).balance.availableBalance;
      final leverage = ref.read(leverageProvider.notifier).getLeverage(symbol);
      // 서버 레버리지 티어의 maxNotional 제한 적용
      final maxQuantity =
          ref.read(leverageTierProvider.notifier).calculateMaxQuantity(
                symbol: symbol,
                availableBalance: availableBalance,
                leverage: leverage.toInt(),
                price: price,
              );
      final quantity = maxQuantity * percent;
      InputManager()
          .setText(inputTagOrderQuantity, numberFormat.format(quantity));
    }
  }

  Widget _buildCheckboxOptions() {
    return Column(
      children: [
        _buildCheckboxRow('TP/SL', tpSlEnabled, (value) {
          setState(() {
            tpSlEnabled = value ?? false;
            // TP/SL과 감소 전용은 동시 선택 불가
            if (tpSlEnabled) reduceOnlyEnabled = false;
          });
        }),
        if (orderType.supportsHiddenOrder)
          _buildCheckboxRow('숨겨진 주문', hiddenOrderEnabled, (value) {
            setState(() {
              hiddenOrderEnabled = value ?? false;
            });
          }),
        _buildCheckboxRow('감소 전용', reduceOnlyEnabled, (value) {
          setState(() {
            reduceOnlyEnabled = value ?? false;
            // 감소 전용과 TP/SL은 동시 선택 불가
            if (reduceOnlyEnabled) tpSlEnabled = false;
          });
        }),
      ],
    );
  }

  Widget _buildCheckboxRow(
      String label, bool value, Function(bool?) onChanged) {
    return InkWell(
      onTap: () {
        onChanged(!value);
      },
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AppTheme.primary,
                side: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButtons() {
    // 지갑 인증 상태 확인
    final walletState = ref.watch(ethereumWalletProvider);
    final isAuthenticated = walletState.isAuthenticated;

    // 지갑이 연결되지 않은 경우 연결 버튼 표시
    if (!isAuthenticated) {
      return SizedBox(
        width: double.infinity,
        height: 36,
        child: ElevatedButton(
          onPressed: () => showWalletSelectionOverlay(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            padding: EdgeInsets.all(4),
          ),
          child: const Text(
            '지갑 연결',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // 지갑이 연결된 경우 매수/매도 버튼 표시
    return Row(
      children: [
        // 매수 버튼
        Expanded(
          child: SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitOrder('BUY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.upColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                padding: EdgeInsets.all(4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  '매수/롱',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 매도 버튼
        Expanded(
          child: SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () => _submitOrder('SELL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.downColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                padding: EdgeInsets.all(4),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: const Text(
                  '매도/숏',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfo() {
    // 증거금 계산
    final leverageMap = ref.watch(leverageProvider);
    final leverage = leverageMap[symbol] ?? 20.0;
    final availableBalance =
        ref.watch(balanceProvider).balance.availableBalance;

    double margin = 0.0;
    double maxOpen = 0.0;
    String sizeDisplay = '';

    final quantityText = InputManager().getText(inputTagOrderQuantity) ?? '';
    // 슬라이더 입력이면 퍼센트, 직접 입력이면 실제 수량
    final quantity =
        parseDouble(quantityText.replaceAll(',', '').replaceAll('%', ''));

    double price = ref.read(currentPriceProvider);
    if (orderType.requiresPrice) {
      final priceText = InputManager().getText(inputTagOrderPrice) ?? '';
      final inputPrice = parseDouble(priceText.replaceAll(',', ''));
      if (inputPrice > 0) {
        price = inputPrice;
      }
    }

    // 최대 오픈 = 서버 레버리지 티어의 maxNotional 제한 적용
    if (price > 0) {
      maxOpen = ref.read(leverageTierProvider.notifier).calculateMaxQuantity(
            symbol: symbol,
            availableBalance: availableBalance,
            leverage: leverage.toInt(),
            price: price,
          );
    }

    if (quantity > 0) {
      // 슬라이더 입력이면 퍼센트를 실제 수량으로 변환
      double actualQuantity = quantity;
      if (isSliderInput && price > 0) {
        actualQuantity = maxOpen * (quantity / 100);
        sizeDisplay =
            '${numberFormat.format(actualQuantity)} BTC (${quantity.toStringAsFixed(0)}%)';
      } else if (priceUnit == 'USDT' && price > 0) {
        // USDT로 입력된 경우 BTC 수량으로 변환
        actualQuantity = quantity / price;
        sizeDisplay = '${numberFormat.format(actualQuantity)} BTC';
      } else {
        sizeDisplay = '${numberFormat.format(quantity)} BTC';
      }

      // 증거금 = (가격 × 수량) / 레버리지
      margin = (price * actualQuantity) / leverage;
    } else {
      sizeDisplay = '0.00 BTC';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Long 섹션
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                _buildInfoRow('청산 가격', _calculateLongLiquidationPrice(), true),
                _buildInfoRow(
                    '증거금',
                    '${Util.commaStringNumber(margin.toStringAsFixed(2))}',
                    true),
                _buildInfoRow('크기', sizeDisplay, true),
                _buildInfoRow(
                    '최대 오픈',
                    '${Util.commaStringNumber(maxOpen.toStringAsFixed(2))} BTC',
                    true),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Short 섹션
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                _buildInfoRow(
                    '청산 가격', _calculateShortLiquidationPrice(), false),
                _buildInfoRow(
                    '증거금',
                    '${Util.commaStringNumber(margin.toStringAsFixed(2))}',
                    false),
                _buildInfoRow('크기', sizeDisplay, false),
                _buildInfoRow(
                    '최대 오픈',
                    '${Util.commaStringNumber(maxOpen.toStringAsFixed(2))} BTC',
                    false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isLong) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.num12.copyWith(
              color: isLong ? AppTheme.upColor : AppTheme.downColor,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _calculateLongLiquidationPrice() {
    final leverageMap = ref.watch(leverageProvider);
    final leverage = leverageMap[symbol] ?? 20.0;

    double price = ref.read(currentPriceProvider);
    if (orderType.requiresPrice) {
      final priceText = InputManager().getText(inputTagOrderPrice) ?? '';
      final inputPrice = parseDouble(priceText.replaceAll(',', ''));
      if (inputPrice > 0) {
        price = inputPrice;
      }
    }

    if (price == 0) return '--';

    // Long 청산가격 = 진입가격 * (1 - 1/레버리지)
    final liquidationPrice = price * (1 - 1 / leverage);

    return '${Util.commaStringNumber(liquidationPrice.toStringAsFixed(2))}';
  }

  String _calculateShortLiquidationPrice() {
    final leverageMap = ref.watch(leverageProvider);
    final leverage = leverageMap[symbol] ?? 20.0;

    double price = ref.read(currentPriceProvider);
    if (orderType.requiresPrice) {
      final priceText = InputManager().getText(inputTagOrderPrice) ?? '';
      final inputPrice = parseDouble(priceText.replaceAll(',', ''));
      if (inputPrice > 0) {
        price = inputPrice;
      }
    }

    if (price == 0) return '--';

    // Short 청산가격 = 진입가격 * (1 + 1/레버리지)
    final liquidationPrice = price * (1 + 1 / leverage);
    return '${Util.commaStringNumber(liquidationPrice.toStringAsFixed(2))}';
  }
}
