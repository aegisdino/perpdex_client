import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '/common/theme.dart';
import '/wallet/providers/ethereum_wallet_provider.dart';
import '/wallet/widgets/wallet_selection_overlay.dart';
import '../providers/account_settings_provider.dart' hide MarginMode;
import '../providers/account_config_provider.dart';

/// ============================================================================
/// 자산 모드 다이얼로그
/// ============================================================================
void showAssetModeDialog(BuildContext context, WidgetRef ref) {
  final accountSettings = ref.read(accountSettingsProvider);
  AssetMode selectedMode = accountSettings.assetMode;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final walletState = ref.read(ethereumWalletProvider);
        final isAuthenticated = walletState.isAuthenticated;

        return _TradingModeDialog(
          title: '자산 모드',
          options: [
            _ModeOption(
              isSelected: selectedMode == AssetMode.single,
              title: '단일 자산 모드',
              descriptions: const [
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
            _ModeOption(
              isSelected: selectedMode == AssetMode.multi,
              title: '다중 자산 모드',
              descriptions: const [
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
          ],
          footerWidget: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '위험 관리를 개선하기 위해 ',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                ),
                TextSpan(
                  text: '멀티 자산 모드',
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launchUrl(Uri.parse(
                          'https://docs.asterdex.com/product/aster-perpetual-pro/single-asset-mode-and-multi-asset-mode'));
                    },
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.primary),
                ),
                TextSpan(
                  text: '에 대해 읽어보십시오.',
                  style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          isAuthenticated: isAuthenticated,
          onConfirm: () {
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
        );
      },
    ),
  );
}

/// ============================================================================
/// 포지션 모드 다이얼로그
/// ============================================================================
void showPositionModeDialog(BuildContext context, WidgetRef ref) {
  final accountConfig = ref.read(accountConfigProvider);
  PositionMode selectedMode = accountConfig.defaultPositionMode;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final walletState = ref.read(ethereumWalletProvider);
        final isAuthenticated = walletState.isAuthenticated;

        return _TradingModeDialog(
          title: '포지션 모드',
          options: [
            _ModeOption(
              isSelected: selectedMode == PositionMode.oneWay,
              title: '일방향 모드',
              descriptions: const [
                '동일한 심볼에 대해 하나의 포지션만 유지됩니다. 반대 방향 주문은 먼저 기존 포지션을 상계하며, 상계 이후 남은 수량이 있을 경우 반대 방향 포지션으로 전환될 수 있습니다.',
              ],
              onTap: () {
                setDialogState(() {
                  selectedMode = PositionMode.oneWay;
                });
              },
            ),
            _ModeOption(
              isSelected: selectedMode == PositionMode.hedge,
              title: '헤지 모드',
              descriptions: const [
                '하나의 심볼(계약)에 대해 롱(Long)과 숏(Short) 포지션을 동시에 보유할 수 있으며, 동일한 심볼에서 서로 반대 방향의 포지션을 독립적으로 운용할 수 있습니다.',
              ],
              onTap: () {
                setDialogState(() {
                  selectedMode = PositionMode.hedge;
                });
              },
            ),
          ],
          footerWidget: Text(
            '사용자가 기존 포지션 또는 미체결 주문이 있을 경우 포지션 모드를 변경할 수 없습니다. 이 포지션 모드 조정은 모든 영구 계약에 적용됩니다.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
          ),
          isAuthenticated: isAuthenticated,
          onConfirm: () async {
            if (isAuthenticated) {
              final currentMode = accountConfig.defaultPositionMode;
              if (selectedMode != currentMode) {
                final success = await ref
                    .read(accountConfigProvider.notifier)
                    .setDefaultPositionMode(selectedMode);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          success ? '포지션 모드가 변경되었습니다' : '포지션 모드 변경에 실패했습니다'),
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
              showWalletSelectionOverlay(context);
            }
          },
        );
      },
    ),
  );
}

/// ============================================================================
/// 마진 모드 다이얼로그 (크로스/격리)
/// ============================================================================
void showMarginModeDialog(BuildContext context, WidgetRef ref, String symbol) {
  final accountConfig = ref.read(accountConfigProvider);
  MarginMode selectedMode = accountConfig.getMarginMode(symbol);

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final walletState = ref.read(ethereumWalletProvider);
        final isAuthenticated = walletState.isAuthenticated;

        return _TradingModeDialog(
          title: '마진 모드',
          options: [
            _ModeOption(
              isSelected: selectedMode == MarginMode.cross,
              title: '크로스 마진',
              descriptions: const [
                '동일한 마진 자산을 공유하는 모든 크로스 포지션은 동일한 자산 크로스 마진 잔액을 공유합니다.',
                '청산 시 해당 자산의 전체 마진 잔액과 해당 자산의 모든 크로스 포지션이 상실될 수 있습니다.',
              ],
              onTap: () {
                setDialogState(() {
                  selectedMode = MarginMode.cross;
                });
              },
            ),
            _ModeOption(
              isSelected: selectedMode == MarginMode.isolated,
              title: '격리 마진',
              descriptions: const [
                '포지션에 할당된 마진이 제한됩니다.',
                '마진 비율이 100%에 도달하면 포지션은 청산됩니다.',
                '마진은 포지션에 추가하거나 제거할 수 있습니다.',
              ],
              onTap: () {
                setDialogState(() {
                  selectedMode = MarginMode.isolated;
                });
              },
            ),
          ],
          footerWidget: Text(
            '마진 모드 변경은 선택한 심볼에만 적용됩니다. 기존 포지션이 있는 경우 모드를 변경할 수 없습니다.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
          ),
          isAuthenticated: isAuthenticated,
          onConfirm: () async {
            if (isAuthenticated) {
              final currentMode = accountConfig.getMarginMode(symbol);
              if (selectedMode != currentMode) {
                final success = await ref
                    .read(accountConfigProvider.notifier)
                    .setMarginMode(symbol, selectedMode);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(success ? '마진 모드가 변경되었습니다' : '마진 모드 변경에 실패했습니다'),
                    ),
                  );
                }
              } else {
                Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
              showWalletSelectionOverlay(context);
            }
          },
        );
      },
    ),
  );
}

/// ============================================================================
/// 공통 다이얼로그 위젯
/// ============================================================================
class _TradingModeDialog extends StatelessWidget {
  final String title;
  final List<_ModeOption> options;
  final Widget footerWidget;
  final bool isAuthenticated;
  final VoidCallback onConfirm;

  const _TradingModeDialog({
    required this.title,
    required this.options,
    required this.footerWidget,
    required this.isAuthenticated,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.grey, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 옵션들
              ...options.map((option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: option,
                  )),
              const SizedBox(height: 4),
              // 하단 안내 텍스트
              footerWidget,
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
                        style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
  }
}

/// ============================================================================
/// 공통 옵션 위젯
/// ============================================================================
class _ModeOption extends StatelessWidget {
  final bool isSelected;
  final String title;
  final List<String> descriptions;
  final VoidCallback onTap;

  const _ModeOption({
    required this.isSelected,
    required this.title,
    required this.descriptions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.white24,
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
                color: isSelected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.grey,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.black, size: 14)
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
}
