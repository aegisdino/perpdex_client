import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/api/netclient.dart';

/// 마진 모드 타입
enum MarginMode {
  cross('CROSS'),
  isolated('ISOLATED');

  final String value;
  const MarginMode(this.value);

  static MarginMode fromString(String? value) {
    if (value == 'ISOLATED') return MarginMode.isolated;
    return MarginMode.cross; // 기본값
  }
}

/// 포지션 모드 타입
enum PositionMode {
  oneWay('ONE_WAY'),
  hedge('HEDGE');

  final String value;
  const PositionMode(this.value);

  static PositionMode fromString(String? value) {
    if (value == 'HEDGE') return PositionMode.hedge;
    return PositionMode.oneWay; // 기본값
  }
}

/// 멀티 에셋 모드 타입
enum MultiAssetMode {
  singleAsset('SINGLE_ASSET'),
  multiAsset('MULTI_ASSET');

  final String value;
  const MultiAssetMode(this.value);

  static MultiAssetMode fromString(String? value) {
    if (value == 'MULTI_ASSET') return MultiAssetMode.multiAsset;
    return MultiAssetMode.singleAsset; // 기본값
  }
}

/// 심볼별 설정
class SymbolConfig {
  final String symbol;
  final PositionMode positionMode;
  final MarginMode marginMode;
  final int leverage;

  SymbolConfig({
    required this.symbol,
    this.positionMode = PositionMode.oneWay,
    this.marginMode = MarginMode.cross,
    this.leverage = 20,
  });

  factory SymbolConfig.fromJson(String symbol, Map<String, dynamic> json) {
    return SymbolConfig(
      symbol: symbol,
      positionMode: PositionMode.fromString(json['positionMode']),
      marginMode: MarginMode.fromString(json['marginMode']),
      leverage: json['leverage'] ?? 20,
    );
  }

  SymbolConfig copyWith({
    PositionMode? positionMode,
    MarginMode? marginMode,
    int? leverage,
  }) {
    return SymbolConfig(
      symbol: symbol,
      positionMode: positionMode ?? this.positionMode,
      marginMode: marginMode ?? this.marginMode,
      leverage: leverage ?? this.leverage,
    );
  }
}

/// 계정 설정 상태
class AccountConfigState {
  // 계정 기본 설정
  final MarginMode defaultMarginMode;
  final PositionMode defaultPositionMode;
  final int defaultLeverage;
  final MultiAssetMode multiAssetMode;
  final bool autoAddMargin;

  // 심볼별 설정
  final Map<String, SymbolConfig> symbolConfigs;

  final bool isLoading;
  final String? error;

  AccountConfigState({
    this.defaultMarginMode = MarginMode.cross,
    this.defaultPositionMode = PositionMode.oneWay,
    this.defaultLeverage = 10,
    this.multiAssetMode = MultiAssetMode.singleAsset,
    this.autoAddMargin = false,
    this.symbolConfigs = const {},
    this.isLoading = false,
    this.error,
  });

  AccountConfigState copyWith({
    MarginMode? defaultMarginMode,
    PositionMode? defaultPositionMode,
    int? defaultLeverage,
    MultiAssetMode? multiAssetMode,
    bool? autoAddMargin,
    Map<String, SymbolConfig>? symbolConfigs,
    bool? isLoading,
    String? error,
  }) {
    return AccountConfigState(
      defaultMarginMode: defaultMarginMode ?? this.defaultMarginMode,
      defaultPositionMode: defaultPositionMode ?? this.defaultPositionMode,
      defaultLeverage: defaultLeverage ?? this.defaultLeverage,
      multiAssetMode: multiAssetMode ?? this.multiAssetMode,
      autoAddMargin: autoAddMargin ?? this.autoAddMargin,
      symbolConfigs: symbolConfigs ?? this.symbolConfigs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 심볼의 마진 모드 가져오기 (없으면 기본값)
  MarginMode getMarginMode(String symbol) {
    return symbolConfigs[symbol]?.marginMode ?? defaultMarginMode;
  }

  /// 심볼의 포지션 모드 가져오기 (없으면 기본값)
  PositionMode getPositionMode(String symbol) {
    return symbolConfigs[symbol]?.positionMode ?? defaultPositionMode;
  }

  /// 심볼의 레버리지 가져오기 (없으면 기본값)
  int getLeverage(String symbol) {
    return symbolConfigs[symbol]?.leverage ?? defaultLeverage;
  }
}

/// 계정 설정 Provider
class AccountConfigNotifier extends Notifier<AccountConfigState> {
  @override
  AccountConfigState build() {
    return AccountConfigState();
  }

  /// 전체 설정 조회
  Future<void> fetchConfig() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await ServerAPI().getAccountConfig();
      print('[AccountConfig] API response: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final data = result['data'] ?? result;

        // 계정 기본 설정 파싱
        final account = data['account'] as Map<String, dynamic>?;
        final defaultMarginMode = MarginMode.fromString(account?['marginMode']);
        final defaultPositionMode = PositionMode.fromString(account?['positionMode']);
        final defaultLeverage = account?['defaultLeverage'] ?? 10;
        final multiAssetMode = MultiAssetMode.fromString(account?['multiAssetMode']);
        final autoAddMargin = account?['autoAddMargin'] ?? false;

        // 심볼별 설정 파싱
        final symbolsJson = data['symbols'] as Map<String, dynamic>? ?? {};
        final symbolConfigs = <String, SymbolConfig>{};
        symbolsJson.forEach((symbol, config) {
          symbolConfigs[symbol] = SymbolConfig.fromJson(symbol, config);
        });

        state = state.copyWith(
          defaultMarginMode: defaultMarginMode,
          defaultPositionMode: defaultPositionMode,
          defaultLeverage: defaultLeverage,
          multiAssetMode: multiAssetMode,
          autoAddMargin: autoAddMargin,
          symbolConfigs: symbolConfigs,
          isLoading: false,
        );

        print('[AccountConfig] Loaded - defaultMargin: ${defaultMarginMode.value}, symbols: ${symbolConfigs.keys.toList()}');
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '설정 조회 실패';
        print('[AccountConfig] Error: $errorMsg');
        state = state.copyWith(isLoading: false, error: errorMsg);
      }
    } catch (e) {
      print('[AccountConfig] Exception: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 심볼별 마진 모드 변경
  Future<bool> setMarginMode(String symbol, MarginMode marginMode) async {
    try {
      final result = await ServerAPI().setSymbolMarginMode(symbol, marginMode.value);
      print('[AccountConfig] setMarginMode result: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        // 로컬 상태 업데이트
        final symbolConfigs = Map<String, SymbolConfig>.from(state.symbolConfigs);
        final existingConfig = symbolConfigs[symbol];

        if (existingConfig != null) {
          symbolConfigs[symbol] = existingConfig.copyWith(marginMode: marginMode);
        } else {
          symbolConfigs[symbol] = SymbolConfig(
            symbol: symbol,
            marginMode: marginMode,
            positionMode: state.defaultPositionMode,
            leverage: state.defaultLeverage,
          );
        }

        state = state.copyWith(symbolConfigs: symbolConfigs);
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '마진 모드 변경 실패';
        print('[AccountConfig] setMarginMode error: $errorMsg');
        return false;
      }
    } catch (e) {
      print('[AccountConfig] setMarginMode exception: $e');
      return false;
    }
  }

  /// 심볼별 포지션 모드 변경
  Future<bool> setPositionMode(String symbol, PositionMode positionMode) async {
    try {
      final result = await ServerAPI().setSymbolPositionMode(symbol, positionMode.value);
      print('[AccountConfig] setPositionMode result: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final symbolConfigs = Map<String, SymbolConfig>.from(state.symbolConfigs);
        final existingConfig = symbolConfigs[symbol];

        if (existingConfig != null) {
          symbolConfigs[symbol] = existingConfig.copyWith(positionMode: positionMode);
        } else {
          symbolConfigs[symbol] = SymbolConfig(
            symbol: symbol,
            positionMode: positionMode,
            marginMode: state.defaultMarginMode,
            leverage: state.defaultLeverage,
          );
        }

        state = state.copyWith(symbolConfigs: symbolConfigs);
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '포지션 모드 변경 실패';
        print('[AccountConfig] setPositionMode error: $errorMsg');
        return false;
      }
    } catch (e) {
      print('[AccountConfig] setPositionMode exception: $e');
      return false;
    }
  }

  /// 심볼별 레버리지 변경 (서버 저장)
  Future<bool> setLeverage(String symbol, int leverage) async {
    try {
      final result = await ServerAPI().setSymbolLeverage(symbol, leverage);
      print('[AccountConfig] setLeverage result: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        final symbolConfigs = Map<String, SymbolConfig>.from(state.symbolConfigs);
        final existingConfig = symbolConfigs[symbol];

        if (existingConfig != null) {
          symbolConfigs[symbol] = existingConfig.copyWith(leverage: leverage);
        } else {
          symbolConfigs[symbol] = SymbolConfig(
            symbol: symbol,
            leverage: leverage,
            marginMode: state.defaultMarginMode,
            positionMode: state.defaultPositionMode,
          );
        }

        state = state.copyWith(symbolConfigs: symbolConfigs);
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '레버리지 변경 실패';
        print('[AccountConfig] setLeverage error: $errorMsg');
        return false;
      }
    } catch (e) {
      print('[AccountConfig] setLeverage exception: $e');
      return false;
    }
  }

  /// 기본 포지션 모드 변경 (계정 전체에 적용)
  Future<bool> setDefaultPositionMode(PositionMode positionMode) async {
    try {
      final result = await ServerAPI().setPositionMode(positionMode.value);
      print('[AccountConfig] setDefaultPositionMode result: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        state = state.copyWith(defaultPositionMode: positionMode);
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '포지션 모드 변경 실패';
        print('[AccountConfig] setDefaultPositionMode error: $errorMsg');
        return false;
      }
    } catch (e) {
      print('[AccountConfig] setDefaultPositionMode exception: $e');
      return false;
    }
  }

  /// 멀티 에셋 모드 변경 (계정 단위)
  Future<bool> setMultiAssetMode(MultiAssetMode mode) async {
    try {
      final result = await ServerAPI().setMultiAssetMode(mode.value);
      print('[AccountConfig] setMultiAssetMode result: $result');

      if (result != null && (result['result'] == 0 || result['success'] == true)) {
        state = state.copyWith(multiAssetMode: mode);
        return true;
      } else {
        final errorMsg = result?['message'] ?? result?['error'] ?? '멀티 에셋 모드 변경 실패';
        print('[AccountConfig] setMultiAssetMode error: $errorMsg');
        return false;
      }
    } catch (e) {
      print('[AccountConfig] setMultiAssetMode exception: $e');
      return false;
    }
  }
}

final accountConfigProvider = NotifierProvider<AccountConfigNotifier, AccountConfigState>(() {
  return AccountConfigNotifier();
});
