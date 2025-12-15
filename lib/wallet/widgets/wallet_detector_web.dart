import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

/// Web용 지갑 감지 구현
/// window.ethereum 등을 JS interop으로 확인
class WalletDetectorImpl {
  // 마커 키 상수
  static const String _metamaskMarker = '__flutter_metamask_marker__';
  static const String _phantomMarker = '__flutter_phantom_marker__';
  static const String _coinbaseMarker = '__flutter_coinbase_marker__';
  static const String _trustMarker = '__flutter_trust_marker__';

  /// Provider에 지갑 타입별 마커를 추가하고 반환
  /// 이미 마킹된 provider가 있으면 그것을 우선 반환
  static JSObject? findAndMarkProvider({
    required String walletType,
    JSObject? cachedProvider,
  }) {
    try {
      final String markerKey;
      final bool Function(JSObject) isTargetWallet;

      // 지갑 타입에 따라 마커와 검증 함수 설정
      switch (walletType.toLowerCase()) {
        case 'metamask':
          markerKey = _metamaskMarker;
          isTargetWallet = (provider) => _isMetaMaskProvider(provider);
          break;
        case 'phantom':
          markerKey = _phantomMarker;
          isTargetWallet = (provider) => _isPhantomProvider(provider);
          break;
        case 'coinbase':
          markerKey = _coinbaseMarker;
          isTargetWallet = (provider) => _isCoinbaseProvider(provider);
          break;
        case 'trust':
        case 'trustwallet':
          markerKey = _trustMarker;
          isTargetWallet = (provider) => _isTrustProvider(provider);
          break;
        default:
          print('[WalletDetector] Unknown wallet type: $walletType');
          return null;
      }

      // 캐시된 provider가 있고 마커가 유효하면 재사용
      if (cachedProvider != null) {
        final marker = cachedProvider.getProperty(markerKey.toJS);
        if (marker != null && (marker as JSBoolean).toDart) {
          //print('[WalletDetector] Using cached provider for $walletType');
          return cachedProvider;
        } else {
          print(
              '[WalletDetector] Cached provider marker invalid for $walletType, re-searching...');
        }
      }

      print('[WalletDetector] Searching for $walletType provider...');
      final windowObj = web.window as JSObject;

      // 지갑별 특수 경로 확인
      JSObject? specialProvider = _checkSpecialPath(walletType, windowObj);
      if (specialProvider != null) {
        specialProvider.setProperty(markerKey.toJS, true.toJS);
        return specialProvider;
      }

      // window.ethereum의 providers 배열 확인
      if (windowObj.has('ethereum')) {
        final ethereum = windowObj.getProperty('ethereum'.toJS);
        if (ethereum != null) {
          final ethereumObj = ethereum as JSObject;

          final providers = ethereumObj.getProperty('providers'.toJS);
          if (providers != null && providers is JSArray) {
            final providerList = providers.toDart;
            print(
                '[WalletDetector] Found providers array with ${providerList.length} providers');

            for (var i = 0; i < providerList.length; i++) {
              final provider = providerList[i] as JSObject;

              // 중첩된 providers 배열 확인 (Coinbase의 특수 케이스)
              final nestedProviders = provider.getProperty('providers'.toJS);
              if (nestedProviders != null && nestedProviders is JSArray) {
                print(
                    '[WalletDetector] Found nested providers in provider[$i]');
                final nestedList = nestedProviders.toDart;
                for (var j = 0; j < nestedList.length; j++) {
                  final nestedProvider = nestedList[j] as JSObject;
                  if (isTargetWallet(nestedProvider)) {
                    print(
                        '[WalletDetector] ✅ Found $walletType in providers[$i].providers[$j]');
                    nestedProvider.setProperty(markerKey.toJS, true.toJS);
                    return nestedProvider;
                  }
                }
              }

              // 일반 provider 체크
              if (isTargetWallet(provider)) {
                print('[WalletDetector] ✅ Found $walletType in providers[$i]');
                provider.setProperty(markerKey.toJS, true.toJS);
                return provider;
              }
            }
          }

          // window.ethereum 자체 확인
          if (isTargetWallet(ethereumObj)) {
            print('[WalletDetector] ✅ Found $walletType via window.ethereum');
            ethereumObj.setProperty(markerKey.toJS, true.toJS);
            return ethereumObj;
          }
        }
      }

      print('[WalletDetector] ❌ No $walletType provider found');
      return null;
    } catch (e) {
      print('[WalletDetector] Error finding $walletType: $e');
      return null;
    }
  }

  /// 지갑별 특수 경로 확인 (window.phantom.ethereum, window.trustwallet 등)
  static JSObject? _checkSpecialPath(String walletType, JSObject windowObj) {
    switch (walletType.toLowerCase()) {
      case 'phantom':
        if (windowObj.has('phantom')) {
          final phantom = windowObj.getProperty('phantom'.toJS);
          if (phantom != null) {
            final phantomObj = phantom as JSObject;
            final ethereum = phantomObj.getProperty('ethereum'.toJS);
            if (ethereum != null) {
              print(
                  '[WalletDetector] ✅ Found Phantom via window.phantom.ethereum');
              return ethereum as JSObject;
            }
          }
        }
        break;
      case 'coinbase':
        if (windowObj.has('coinbaseWalletExtension')) {
          final coinbase =
              windowObj.getProperty('coinbaseWalletExtension'.toJS);
          if (coinbase != null) {
            print(
                '[WalletDetector] ✅ Found Coinbase via window.coinbaseWalletExtension');
            return coinbase as JSObject;
          }
        }
        break;
      case 'trust':
      case 'trustwallet':
        if (windowObj.has('trustwallet')) {
          final trustwallet = windowObj.getProperty('trustwallet'.toJS);
          if (trustwallet != null) {
            print(
                '[WalletDetector] ✅ Found Trust Wallet via window.trustwallet');
            return trustwallet as JSObject;
          }
        }
        break;
    }
    return null;
  }

  /// MetaMask provider 확인
  static bool _isMetaMaskProvider(JSObject provider) {
    final isMetaMask = provider.getProperty('isMetaMask'.toJS);
    final isPhantom = provider.getProperty('isPhantom'.toJS);
    final isCoinbaseWallet = provider.getProperty('isCoinbaseWallet'.toJS);
    final providerMap = provider.getProperty('providerMap'.toJS);

    final hasMetaMask = isMetaMask != null && (isMetaMask as JSBoolean).toDart;
    final hasPhantom = isPhantom != null && (isPhantom as JSBoolean).toDart;
    final hasCoinbase =
        isCoinbaseWallet != null && (isCoinbaseWallet as JSBoolean).toDart;

    // providerMap is a JavaScript Map, need to call its has() method
    bool hasCoinbaseMap = false;
    if (providerMap != null) {
      try {
        final result = (providerMap as JSObject).callMethod('has'.toJS, 'CoinbaseWallet'.toJS);
        hasCoinbaseMap = result != null && (result as JSBoolean).toDart;
      } catch (e) {
        // If callMethod fails, providerMap might not be a Map, ignore
        hasCoinbaseMap = false;
      }
    }

    return hasMetaMask && !hasPhantom && !hasCoinbase && !hasCoinbaseMap;
  }

  /// Phantom provider 확인
  static bool _isPhantomProvider(JSObject provider) {
    final isPhantom = provider.getProperty('isPhantom'.toJS);
    final isMetaMask = provider.getProperty('isMetaMask'.toJS);
    final isCoinbaseWallet = provider.getProperty('isCoinbaseWallet'.toJS);
    final isTrust = provider.getProperty('isTrust'.toJS);

    final hasPhantom = isPhantom != null && (isPhantom as JSBoolean).toDart;
    final hasMetaMask = isMetaMask != null && (isMetaMask as JSBoolean).toDart;
    final hasCoinbase =
        isCoinbaseWallet != null && (isCoinbaseWallet as JSBoolean).toDart;
    final hasTrust = isTrust != null && (isTrust as JSBoolean).toDart;

    return hasPhantom && !hasMetaMask && !hasCoinbase && !hasTrust;
  }

  /// Coinbase provider 확인
  static bool _isCoinbaseProvider(JSObject provider) {
    final isCoinbaseWallet = provider.getProperty('isCoinbaseWallet'.toJS);
    final isMetaMask = provider.getProperty('isMetaMask'.toJS);
    final isPhantom = provider.getProperty('isPhantom'.toJS);
    final isTrust = provider.getProperty('isTrust'.toJS);

    final hasCoinbase =
        isCoinbaseWallet != null && (isCoinbaseWallet as JSBoolean).toDart;
    final hasMetaMask = isMetaMask != null && (isMetaMask as JSBoolean).toDart;
    final hasPhantom = isPhantom != null && (isPhantom as JSBoolean).toDart;
    final hasTrust = isTrust != null && (isTrust as JSBoolean).toDart;

    return hasCoinbase && !hasMetaMask && !hasPhantom && !hasTrust;
  }

  /// Trust Wallet provider 확인
  static bool _isTrustProvider(JSObject provider) {
    final isTrust = provider.getProperty('isTrust'.toJS);
    final isMetaMask = provider.getProperty('isMetaMask'.toJS);
    final isPhantom = provider.getProperty('isPhantom'.toJS);
    final isCoinbaseWallet = provider.getProperty('isCoinbaseWallet'.toJS);

    final hasTrust = isTrust != null && (isTrust as JSBoolean).toDart;
    final hasMetaMask = isMetaMask != null && (isMetaMask as JSBoolean).toDart;
    final hasPhantom = isPhantom != null && (isPhantom as JSBoolean).toDart;
    final hasCoinbase =
        isCoinbaseWallet != null && (isCoinbaseWallet as JSBoolean).toDart;

    return hasTrust && !hasMetaMask && !hasPhantom && !hasCoinbase;
  }

  /// MetaMask 설치 여부 확인
  static bool isMetaMaskInstalled() {
    return findAndMarkProvider(walletType: 'metamask') != null;
  }

  /// Public API: MetaMask provider 확인
  /// 외부에서 사용 가능한 헬퍼 함수
  static bool isMetaMaskProvider(dynamic provider, {String? debugText}) {
    if (provider is! JSObject) return false;
    return _isMetaMaskProvider(provider);
  }

  /// Trust Wallet 설치 여부 확인
  static bool isTrustWalletInstalled() {
    return findAndMarkProvider(walletType: 'trust') != null;
  }

  /// Coinbase Wallet 설치 여부 확인
  static bool isCoinbaseWalletInstalled() {
    return findAndMarkProvider(walletType: 'coinbase') != null;
  }

  /// 사용 가능한 모든 지갑 목록 가져오기
  /// 여러 지갑이 설치된 경우를 대비
  static Map<String, bool> getAvailableWallets() {
    return {
      'metamask': isMetaMaskInstalled(),
      'trustwallet': isTrustWalletInstalled(),
      'coinbase': isCoinbaseWalletInstalled(),
    };
  }

  /// window.ethereum이 어느 지갑인지 확인
  /// 여러 지갑이 설치된 경우 우선순위 반환
  static String? getPrimaryWallet() {
    if (!_hasEthereum()) return null;

    // 우선순위: MetaMask > Coinbase > Trust Wallet
    if (isMetaMaskInstalled()) return 'metamask';
    if (isCoinbaseWalletInstalled()) return 'coinbase';
    if (isTrustWalletInstalled()) return 'trustwallet';

    return 'unknown'; // window.ethereum은 있지만 알 수 없는 지갑
  }

  static bool _hasEthereum() {
    try {
      return (web.window as JSObject).has('ethereum');
    } catch (e) {
      return false;
    }
  }

  /// Phantom 지갑 설치 여부 확인
  static bool isPhantomInstalled() {
    return findAndMarkProvider(walletType: 'phantom') != null;
  }

  /// Meteor Wallet 설치 여부 확인 (NEAR Protocol)
  /// NEAR Wallet Modal을 통해 항상 사용 가능
  static bool isMeteorWalletInstalled() {
    try {
      // NEAR Wallet Modal API가 로드되어 있는지 확인
      final windowObj = web.window as JSObject;
      final nearAPI = windowObj.getProperty('NearWalletAPI'.toJS);

      // Modal API가 있으면 모든 NEAR 지갑 사용 가능
      return nearAPI != null;
    } catch (e) {
      return false;
    }
  }

  /// MyNearWallet 설치 여부 확인
  /// NEAR Wallet Modal을 통해 항상 사용 가능
  static bool isMyNearWalletInstalled() {
    try {
      // NEAR Wallet Modal API가 로드되어 있는지 확인
      final windowObj = web.window as JSObject;
      final nearAPI = windowObj.getProperty('NearWalletAPI'.toJS);

      // Modal API가 있으면 모든 NEAR 지갑 사용 가능
      return nearAPI != null;
    } catch (e) {
      return false;
    }
  }

  /// HERE Wallet 설치 여부 확인
  /// NEAR Wallet Modal을 통해 항상 사용 가능
  static bool isHereWalletInstalled() {
    try {
      // NEAR Wallet Modal API가 로드되어 있는지 확인
      final windowObj = web.window as JSObject;
      final nearAPI = windowObj.getProperty('NearWalletAPI'.toJS);

      // Modal API가 있으면 모든 NEAR 지갑 사용 가능
      return nearAPI != null;
    } catch (e) {
      return false;
    }
  }

  /// MetaMask 다운로드 페이지 열기
  static void openMetaMaskDownload() {
    try {
      web.window.open('https://metamask.io/download/', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }

  /// Phantom 다운로드 페이지 열기
  static void openPhantomDownload() {
    try {
      web.window.open('https://phantom.app/download', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }

  /// Coinbase Wallet 다운로드 페이지 열기
  static void openCoinbaseDownload() {
    try {
      web.window.open('https://www.coinbase.com/wallet/downloads', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }

  /// Meteor Wallet 다운로드 페이지 열기
  static void openMeteorDownload() {
    try {
      web.window.open('https://meteorwallet.app/', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }

  /// MyNearWallet 다운로드 페이지 열기
  static void openMyNearWalletDownload() {
    try {
      web.window.open('https://mynearwallet.com/', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }

  /// HERE Wallet 다운로드 페이지 열기
  static void openHereWalletDownload() {
    try {
      web.window.open('https://herewallet.app/', '_blank');
    } catch (e) {
      // Fallback - 에러 무시
    }
  }
}
