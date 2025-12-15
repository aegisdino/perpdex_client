import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '/common/theme.dart';
import '../providers/account_settings_provider.dart';
import '../providers/balance_provider.dart';
import '../providers/position_provider.dart';
import 'trading_mode_dialogs.dart';

/// 계정 정보 위젯
class AccountInfoWidget extends ConsumerStatefulWidget {
  const AccountInfoWidget({super.key});

  @override
  ConsumerState<AccountInfoWidget> createState() => _AccountInfoWidgetState();
}

class _AccountInfoWidgetState extends ConsumerState<AccountInfoWidget> {
  final NumberFormat numberFormat = NumberFormat('#,##0.00', 'en_US');

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(balanceProvider);
    final balance = balanceState.balance;
    final positionState = ref.watch(positionListProvider);

    // 미실현 손익 색상
    final pnlColor =
        balance.totalUnrealizedPnl >= 0 ? AppTheme.upColor : AppTheme.downColor;

    // 마진 비율 색상 (5% 이상이면 위험)
    final marginColor =
        balance.marginRatio < 0.05 ? AppTheme.upColor : AppTheme.downColor;

    // 총 유지 마진: balance에서 제공하면 사용, 없으면 포지션 합산
    final totalMaintenanceMargin = balance.totalMaintenanceMargin > 0
        ? balance.totalMaintenanceMargin
        : positionState.totalMaintenanceMargin;

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 계정
          _buildHeader(),

          // 탭 메뉴: 입금, 출금, 전송
          _buildTabMenu(),

          // 계정 자산 정보 (스크롤 가능)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('계정 자산정보'),
                    const SizedBox(height: 12),
                    _buildBalanceRow('스팟 총 가치', 0.00),
                    _buildBalanceRow('무기한 총 가치', balance.equity),
                    _buildBalanceRow('미실현 손익', balance.totalUnrealizedPnl,
                        valueColor: pnlColor),

                    const SizedBox(height: 16),
                    _buildSectionTitle('마진'),
                    const SizedBox(height: 12),
                    _buildMarginRow(
                        '계좌 마진 비율',
                        '${(balance.marginRatio * 100).toStringAsFixed(2)}%',
                        marginColor,
                        iconPath: 'icon_marginrate.png'),
                    _buildBalanceRow(
                        '계좌 유지 마진', totalMaintenanceMargin),
                    _buildBalanceRow('계좌 자산', balance.totalBalance),

                    const SizedBox(height: 16),
                    // 단일 자산 모드 버튼
                    _buildAssetModeButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Text(
        '계정',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTabMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildActionButton('입금')),
          const SizedBox(width: 8),
          Expanded(child: _buildActionButton('출금')),
          const SizedBox(width: 8),
          Expanded(child: _buildActionButton('전송')),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label) {
    return InkWell(
      onTap: () => _showDepositWithdrawDialog(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.dexSecondary,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBalanceRow(String label, double value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} USDT',
            style: AppTheme.num12.copyWith(
              color: valueColor ?? Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginRow(String label, String value, Color valueColor,
      {String? iconPath}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: valueColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              if (iconPath != null)
                Image.asset(
                  'assets/image/${iconPath}',
                  width: 20,
                ),
              Text(
                value,
                style: AppTheme.num12.copyWith(
                  color: valueColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetModeButton() {
    final accountSettings = ref.watch(accountSettingsProvider);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => showAssetModeDialog(context, ref),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppTheme.dexSecondary),
          backgroundColor: AppTheme.dexSurface,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          accountSettings.assetMode == AssetMode.single
              ? '단일 자산 모드'
              : '다중 자산 모드',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showDepositWithdrawDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dexSurface,
        title: Text(
          type,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '$type 기능은 준비 중입니다.',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

}
