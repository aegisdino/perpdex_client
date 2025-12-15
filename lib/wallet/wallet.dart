/// Wallet SDK - 재사용 가능한 지갑 연동 라이브러리
///
/// 이 라이브러리는 다양한 Web3 지갑(MetaMask, Phantom, Coinbase, Trust Wallet)을
/// 쉽게 연동할 수 있도록 설계되었습니다.
///
/// ## 주요 기능
/// - 멀티 지갑 지원 (MetaMask, Phantom, Coinbase, Trust Wallet)
/// - Nonce 기반 서명 인증
/// - Web/Mobile 환경 자동 감지
/// - Riverpod 상태 관리 통합
///
/// ## 사용법
/// ```dart
/// // Provider import
/// import 'package:perpdex/wallet/wallet.dart';
///
/// // 지갑 연결
/// await ref.read(ethereumWalletProvider.notifier).connectMetaMask();
///
/// // 지갑 상태 확인
/// final walletState = ref.watch(ethereumWalletProvider);
/// if (walletState.isConnected) {
///   print('Connected: ${walletState.address}');
/// }
/// ```
library wallet;

// Core
export 'core/ethereum_wallet.dart';

// Services
export 'services/auth_service.dart';
export 'services/auth_nonce_service.dart';
export 'services/signature_verifier.dart';

// Wallets - Web implementations
export 'wallets/metamask_wallet.dart'
    if (dart.library.io) 'wallets/metamask_mobile.dart';
export 'wallets/phantom_ethereum_wallet.dart'
    if (dart.library.io) 'wallets/phantom_mobile.dart';
export 'wallets/coinbase_wallet.dart'
    if (dart.library.io) 'wallets/coinbase_mobile.dart';
export 'wallets/trust_wallet.dart'
    if (dart.library.io) 'wallets/trust_mobile.dart';

// Providers
export 'providers/ethereum_wallet_provider.dart';

export 'widgets/chain_selector.dart';
export 'widgets/wallet_connect_button.dart';
export 'widgets/wallet_view.dart';
