import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final uncontrolledContainer = ProviderContainer();

final balanceUpdateProvider = StateProvider<DateTime?>((ref) => null);

void setBalanceUpdated() {
  // Riverpod 3.0에서 state 접근 방식 동일
  uncontrolledContainer.read(balanceUpdateProvider.notifier).state =
      DateTime.now();
}

final menuSelectProvider = StateProvider<String?>((ref) => null);

void selectCasinoMenu(String? menu) {
  uncontrolledContainer.read(menuSelectProvider.notifier).state = menu;
}

// TokenPriceApi에서 이동
final priceUpdatedProvider = StateProvider<int>((ref) => 0);

// NoticeManager에서 이동 (normal + error 모두 사용)
final queueUpdatedProvider = StateProvider<DateTime?>((ref) => null);

// Telegram providers
final telegramDataProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

// Auth providers
final loginStateProvider = StateProvider<bool>((ref) => false);

// Dex game providers
final launchGameDataProvider = StateProvider<dynamic>((ref) => null);

// Wallet providers
final walletUpdatedProvider = StateProvider<dynamic>((ref) => null);

// Localization providers
final languageStateProvider = StateProvider<String>((ref) => '');

// Data providers
final dataLoadingStateProvider = StateProvider<String>((ref) => '');

// WebSocket providers
final notificationProvider = StateProvider<dynamic>((ref) => null);

final currentPriceProvider = StateProvider<double>((ref) => 0);
