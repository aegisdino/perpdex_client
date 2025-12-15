import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../api/netclient.dart';
import '../../../common/util.dart';
import '../../../common/widgets/slider_shapes.dart';
import '../../../data/providers.dart';
import '../../../models/leverage_tier.dart';
import '../../../wallet/providers/ethereum_wallet_provider.dart';
import '../../../wallet/widgets/wallet_selection_overlay.dart';
import '../providers/balance_provider.dart';
import '../providers/leverage_provider.dart';
import '../providers/leverage_tier_provider.dart';

class LeverageDialog extends ConsumerStatefulWidget {
  final double currentLeverage;
  final String symbol;

  const LeverageDialog({
    super.key,
    required this.currentLeverage,
    required this.symbol,
  });

  @override
  ConsumerState<LeverageDialog> createState() => _LeverageDialogState();
}

class _LeverageDialogState extends ConsumerState<LeverageDialog> {
  late double selectedLeverage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    selectedLeverage = widget.currentLeverage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 레버리지 티어 정보 fetch
      ref.read(leverageTierProvider.notifier).fetchTiers(widget.symbol);
    });
  }

  /// 서버에서 받은 티어 리스트 가져오기
  List<LeverageTier> _getTiers() {
    return ref.read(leverageTierProvider.notifier).getTiers(widget.symbol);
  }

  /// 슬라이더의 최대 레버리지 (첫 번째 티어의 maxLeverage)
  int _getMaxLeverage() {
    final tiers = _getTiers();
    if (tiers.isEmpty) return 125;
    return tiers.first.maxLeverage;
  }

  /// 최대 주문 가능 명목가치 계산
  /// - 티어 기반 maxNotional과 잔고 기반 maxNotional 중 작은 값
  double _calculateMaxNotional() {
    final leverage = selectedLeverage.toInt();

    // 티어 기반 최대 명목가치
    final tierMaxNotional = ref
        .read(leverageTierProvider.notifier)
        .getMaxNotionalForLeverage(widget.symbol, leverage);

    return tierMaxNotional;
  }

  double _calculateMaxOrderValue() {
    final leverage = selectedLeverage.toInt();

    // 잔고 기반 최대 명목가치
    final availableBalance =
        ref.watch(balanceProvider).balance.availableBalance;
    final balanceBasedNotional = availableBalance * leverage;

    // 둘 중 작은 값 반환
    return math.min(balanceBasedNotional, _calculateMaxNotional());
  }

  /// 최대 주문 가능 수량 계산 (현재가 기준)
  double _calculateMaxQuantity() {
    final currentPrice = ref.read(currentPriceProvider);
    if (currentPrice <= 0) return 0;

    final maxNotional = _calculateMaxOrderValue();
    return maxNotional / currentPrice;
  }

  Future<void> _submitLeverageChange() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // 레버리지 유효성 검증
      final result = await ServerAPI().validateLeverage(
        symbol: widget.symbol,
        leverage: selectedLeverage.toInt(),
      );

      if (result != null && result['success'] == true) {
        if (result['accepted'] == true) {
          // 검증 통과 - 로컬에 레버리지 저장
          ref
              .read(leverageProvider.notifier)
              .setLeverage(widget.symbol, selectedLeverage);

          // 다이얼로그 닫기
          if (mounted) {
            Navigator.of(context).pop(selectedLeverage);
          }
        } else {
          // 검증 실패
          final reason = result['reason'] ?? '레버리지 설정이 거부되었습니다.';
          final maxAllowed = result['maxLeverage'];

          Util.toastError(reason);

          // 허용된 최대 레버리지로 자동 조정
          if (maxAllowed != null && maxAllowed is int) {
            setState(() {
              selectedLeverage = maxAllowed.toDouble();
            });
          }
        }
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '레버리지 검증 실패';
        Util.toastError(errorMsg);
      }
    } catch (e) {
      print('[LeverageDialog] validateLeverage error: $e');
      Util.toastError('레버리지 검증 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(ethereumWalletProvider);
    final isWalletConnected = walletState.isConnected;

    final maxLeverage = _getMaxLeverage();
    final maxNotional = _calculateMaxNotional();
    final maxQuantity = _calculateMaxQuantity();

    return Dialog(
      backgroundColor: AppTheme.dexSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
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
                Text(
                  '${widget.symbol} 레버리지 조정',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 레버리지 값
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '레버리지',
                    style: AppTheme.bodyMediumBold,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(width: 0.5, color: Colors.grey[600]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              if (selectedLeverage > 1) {
                                selectedLeverage = (selectedLeverage - 1)
                                    .clamp(1, maxLeverage.toDouble());
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            selectedLeverage.toInt().toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              selectedLeverage = (selectedLeverage + 1)
                                  .clamp(1, maxLeverage.toDouble());
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 슬라이더
            _buildSlider(maxLeverage),
            const SizedBox(height: 8),

            // 정보 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(width: 0.5, color: Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    '남은 열 수 있는 명목 가치',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    '${Util.commaStringNumber(maxNotional.toInt())} USDT',
                    style: AppTheme.bodyLargeBold,
                  ),
                  Text(
                    '현재 레버리지 및 시스템 리스크 관리 한도에 따라 열 수 있는 최대 명목가치입니다.',
                    style: AppTheme.bodySmall.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (isWalletConnected) ...[
                    const SizedBox(height: 8),
                    // 최대 수량
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '나의 최대 주문 가능 수량',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                        Text(
                          '${maxQuantity.toStringAsFixed(4)} ${widget.symbol.replaceAll('USDT', '')}',
                          style: AppTheme.bodyMediumBold,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 경고 텍스트
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 레버리지 및 시스템 리스크 관리로 예 열린 주문도 적당되는 점에 유의하십시오.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '더 높은 레버리지(예: 10배)를 선택하면 정산 가능성이 높아짐니다.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : isWalletConnected
                        ? _submitLeverageChange
                        : () {
                            // 다이얼로그를 닫고 지갑 선택 오버레이 표시
                            Navigator.of(context).pop();
                            showWalletSelectionOverlay(context);
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor:
                      AppTheme.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        isWalletConnected ? '확인' : '지갑 연결',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(int maxLeverage) {
    return SizedBox(
      height: 40,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 4,
            child: Row(
              children: [
                const SizedBox(width: 4),
                _buildTickMark(),
                Expanded(child: Container()),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SfSliderTheme(
              data: SfSliderThemeData(
                activeTrackHeight: 4,
                inactiveTrackHeight: 0,
                trackCornerRadius: 0,
                overlayRadius: 4.0,
                thumbRadius: 4.0,
              ),
              child: SfSlider(
                value: selectedLeverage,
                min: 1.0,
                max: maxLeverage.toDouble(),
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.primary.withValues(alpha: 0.2),
                trackShape: CustomSfTrackShape(),
                thumbShape: const CustomSfRectThumbShape(),
                onChanged: (dynamic value) {
                  setState(() {
                    selectedLeverage = value as double;
                  });
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 20,
            child: Row(
              children: [
                const SizedBox(width: 4),
                _buildTickText(0),
                Expanded(child: Container()),
                _buildTickText(1),
                Expanded(child: Container()),
                _buildTickText(2),
                Expanded(child: Container()),
                _buildTickText(3),
                Expanded(child: Container()),
                _buildTickText(4),
                Expanded(child: Container()),
                _buildTickText(5),
              ],
            ),
          ),
        ],
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

  Widget _buildTickText(int pos) {
    int maxLeverage = _getMaxLeverage();
    int value = math.max(1, (pos * (maxLeverage / 5)).toInt());

    return Text(
      '${value}x',
      style: AppTheme.bodySmall.copyWith(
        color: Colors.grey,
      ),
    );
  }
}
