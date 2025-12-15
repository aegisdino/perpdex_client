import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _leverageStorageKey = 'dex_leverage_settings';

/// 심볼별 레버리지 상태를 관리하는 provider
class LeverageNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    // 초기화 시 저장된 레버리지 설정 로드
    _loadFromStorage();
    return {};
  }

  /// 저장소에서 레버리지 설정 로드
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_leverageStorageKey);
      if (data != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(data);
        final Map<String, double> leverageMap = {};
        jsonMap.forEach((key, value) {
          leverageMap[key] = (value as num).toDouble();
        });
        state = leverageMap;
      }
    } catch (e) {
      print('[Leverage] Error loading from storage: $e');
    }
  }

  /// 저장소에 레버리지 설정 저장
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_leverageStorageKey, jsonEncode(state));
    } catch (e) {
      print('[Leverage] Error saving to storage: $e');
    }
  }

  /// 특정 심볼의 레버리지 값을 가져옴 (기본값: 20.0)
  double getLeverage(String symbol) {
    return state[symbol] ?? 20.0;
  }

  /// 특정 심볼의 레버리지 값을 설정하고 저장
  void setLeverage(String symbol, double leverage) {
    state = {...state, symbol: leverage};
    _saveToStorage();
  }
}

final leverageProvider =
    NotifierProvider<LeverageNotifier, Map<String, double>>(() {
  return LeverageNotifier();
});
