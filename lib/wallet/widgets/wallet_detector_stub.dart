/// 모바일용 지갑 감지 구현 (stub)
/// 모바일에서는 딥링크를 통해 항상 시도 가능하므로 항상 false 반환
class WalletDetectorImpl {
  /// Provider에 지갑 타입별 마커를 추가하고 반환 (모바일에서는 항상 null)
  static dynamic findAndMarkProvider({
    required String walletType,
    dynamic cachedProvider,
  }) {
    return null; // 모바일에서는 web provider가 없음
  }

  /// MetaMask 설치 여부 확인 (모바일에서는 항상 false)
  static bool isMetaMaskInstalled() {
    return false; // 모바일에서는 감지 불가, 딥링크로 시도
  }

  static bool isMetaMaskProvider(dynamic provider, {String? debugText}) {
    return false;
  }

  /// Trust Wallet 설치 여부 확인 (모바일에서는 항상 false)
  static bool isTrustWalletInstalled() {
    return false; // 모바일에서는 감지 불가
  }

  /// Phantom 지갑 설치 여부 확인 (모바일에서는 항상 false)
  static bool isPhantomInstalled() {
    return false; // 모바일에서는 감지 불가, 딥링크로 시도
  }

  /// Coinbase Wallet 설치 여부 확인 (모바일에서는 항상 false)
  static bool isCoinbaseWalletInstalled() {
    return false; // 모바일에서는 감지 불가, 딥링크로 시도
  }

  /// Meteor Wallet 설치 여부 확인 (모바일에서는 항상 false)
  static bool isMeteorWalletInstalled() {
    return false; // 모바일에서는 감지 불가
  }

  /// MyNearWallet 설치 여부 확인 (모바일에서는 항상 false)
  static bool isMyNearWalletInstalled() {
    return false; // 모바일에서는 감지 불가
  }

  /// HERE Wallet 설치 여부 확인 (모바일에서는 항상 false)
  static bool isHereWalletInstalled() {
    return false; // 모바일에서는 감지 불가
  }

  /// MetaMask 다운로드 페이지 열기
  static void openMetaMaskDownload() {
    // 모바일에서는 아무것도 하지 않음
    // 딥링크 시도 시 자동으로 앱스토어로 이동
  }

  /// Phantom 다운로드 페이지 열기
  static void openPhantomDownload() {
    // 모바일에서는 아무것도 하지 않음
    // 딥링크 시도 시 자동으로 앱스토어로 이동
  }

  /// Coinbase Wallet 다운로드 페이지 열기
  static void openCoinbaseDownload() {
    // 모바일에서는 아무것도 하지 않음
    // 딥링크 시도 시 자동으로 앱스토어로 이동
  }

  /// Meteor Wallet 다운로드 페이지 열기
  static void openMeteorDownload() {
    // 모바일에서는 아무것도 하지 않음
  }

  /// MyNearWallet 다운로드 페이지 열기
  static void openMyNearWalletDownload() {
    // 모바일에서는 아무것도 하지 않음
  }

  /// HERE Wallet 다운로드 페이지 열기
  static void openHereWalletDownload() {
    // 모바일에서는 아무것도 하지 않음
  }
}
