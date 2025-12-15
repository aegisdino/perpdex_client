import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perpdex/api/netclient.dart';
import 'package:perpdex/common/all.dart';

/// 마진 모드 enum
enum MarginMode {
  cross('크로스', 'CROSS'),
  isolated('격리', 'ISOLATED');

  final String label;
  final String apiValue;
  const MarginMode(this.label, this.apiValue);

  static MarginMode fromApiValue(String value) {
    return MarginMode.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => MarginMode.cross,
    );
  }
}

/// 자산 모드 enum
enum AssetMode {
  single('단일', 'SINGLE_ASSET'),
  multi('멀티', 'MULTI_ASSET');

  final String label;
  final String apiValue;
  const AssetMode(this.label, this.apiValue);

  static AssetMode fromApiValue(String value) {
    return AssetMode.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => AssetMode.single,
    );
  }
}

/// 계정 설정 상태
class AccountSettings {
  final MarginMode marginMode;
  final AssetMode assetMode;
  final bool isLoading;

  const AccountSettings({
    this.marginMode = MarginMode.cross,
    this.assetMode = AssetMode.single,
    this.isLoading = false,
  });

  AccountSettings copyWith({
    MarginMode? marginMode,
    AssetMode? assetMode,
    bool? isLoading,
  }) {
    return AccountSettings(
      marginMode: marginMode ?? this.marginMode,
      assetMode: assetMode ?? this.assetMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 계정 설정 Notifier
class AccountSettingsNotifier extends Notifier<AccountSettings> {
  @override
  AccountSettings build() {
    return const AccountSettings();
  }

  /// 서버에서 계정 설정 로드
  Future<void> fetchAccountSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await ServerAPI().getAccountSettings();
      if (result != null && result['result'] == 0) {
        final data = result['data'];
        state = state.copyWith(
          marginMode: MarginMode.fromApiValue(data['marginMode'] ?? 'CROSS'),
          assetMode: AssetMode.fromApiValue(data['multiAssetMode'] ?? 'SINGLE_ASSET'),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 마진 모드 변경
  Future<bool> setMarginMode(MarginMode newMode) async {
    if (state.marginMode == newMode) return true;

    try {
      final result = await ServerAPI().setMarginMode(newMode.apiValue);
      if (result != null && result['result'] == 0) {
        state = state.copyWith(marginMode: newMode);
        Util.toastNotice('마진 모드가 ${newMode.label}(으)로 변경되었습니다');
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '마진 모드 변경 실패';
        Util.toastError(errorMsg);
        return false;
      }
    } catch (e) {
      Util.toastError('마진 모드 변경 오류: $e');
      return false;
    }
  }

  /// 자산 모드 변경
  Future<bool> setAssetMode(AssetMode newMode) async {
    if (state.assetMode == newMode) return true;

    try {
      final result = await ServerAPI().setMultiAssetMode(newMode.apiValue);
      if (result != null && result['result'] == 0) {
        state = state.copyWith(assetMode: newMode);
        Util.toastNotice('자산 모드가 ${newMode.label}(으)로 변경되었습니다');
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '자산 모드 변경 실패';
        Util.toastError(errorMsg);
        return false;
      }
    } catch (e) {
      Util.toastError('자산 모드 변경 오류: $e');
      return false;
    }
  }
}

/// 계정 설정 provider
final accountSettingsProvider =
    NotifierProvider<AccountSettingsNotifier, AccountSettings>(() {
  return AccountSettingsNotifier();
});
