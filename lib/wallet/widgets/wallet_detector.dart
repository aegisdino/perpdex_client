import 'wallet_detector_stub.dart'
    if (dart.library.js_interop) 'wallet_detector_web.dart';

/// 지갑 설치 여부 확인 클래스
/// Web과 Mobile에서 다른 구현을 사용
class WalletDetector {
  /// Provider에 지갑 타입별 마커를 추가하고 반환
  /// 이미 마킹된 provider가 있으면 그것을 우선 반환
  ///
  /// [walletType]: 'metamask', 'phantom', 'coinbase', 'trust'
  /// [cachedProvider]: 캐시된 provider (있으면 마커 확인 후 재사용)
  static dynamic findAndMarkProvider({
    required String walletType,
    dynamic cachedProvider,
  }) {
    return WalletDetectorImpl.findAndMarkProvider(
      walletType: walletType,
      cachedProvider: cachedProvider,
    );
  }

  /// MetaMask 설치 여부 확인
  static bool isMetaMaskInstalled() {
    return WalletDetectorImpl.isMetaMaskInstalled();
  }

  static bool isMetaMaskProvider(dynamic provider, {String? debugText}) {
    return WalletDetectorImpl.isMetaMaskProvider(provider, debugText: debugText);
  }

  /// Trust Wallet 설치 여부 확인
  static bool isTrustWalletInstalled() {
    return WalletDetectorImpl.isTrustWalletInstalled();
  }

  /// Phantom 지갑 설치 여부 확인
  static bool isPhantomInstalled() {
    return WalletDetectorImpl.isPhantomInstalled();
  }

  /// Coinbase Wallet 설치 여부 확인
  static bool isCoinbaseWalletInstalled() {
    return WalletDetectorImpl.isCoinbaseWalletInstalled();
  }

  /// Meteor Wallet 설치 여부 확인 (NEAR Protocol)
  static bool isMeteorWalletInstalled() {
    return WalletDetectorImpl.isMeteorWalletInstalled();
  }

  /// MyNearWallet 설치 여부 확인
  static bool isMyNearWalletInstalled() {
    return WalletDetectorImpl.isMyNearWalletInstalled();
  }

  /// HERE Wallet 설치 여부 확인
  static bool isHereWalletInstalled() {
    return WalletDetectorImpl.isHereWalletInstalled();
  }

  /// MetaMask 다운로드 페이지 열기
  static void openMetaMaskDownload() {
    WalletDetectorImpl.openMetaMaskDownload();
  }

  /// Phantom 다운로드 페이지 열기
  static void openPhantomDownload() {
    WalletDetectorImpl.openPhantomDownload();
  }

  /// Coinbase Wallet 다운로드 페이지 열기
  static void openCoinbaseDownload() {
    WalletDetectorImpl.openCoinbaseDownload();
  }

  /// Meteor Wallet 다운로드 페이지 열기
  static void openMeteorDownload() {
    WalletDetectorImpl.openMeteorDownload();
  }

  /// MyNearWallet 다운로드 페이지 열기
  static void openMyNearWalletDownload() {
    WalletDetectorImpl.openMyNearWalletDownload();
  }

  /// HERE Wallet 다운로드 페이지 열기
  static void openHereWalletDownload() {
    WalletDetectorImpl.openHereWalletDownload();
  }
}
