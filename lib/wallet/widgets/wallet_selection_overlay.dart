import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../common/theme.dart';
import '../wallet.dart';
import '../utils/near_js_interop.dart';
import 'wallet_detector.dart';

/// 지갑 선택을 위한 공용 오버레이를 표시하는 함수
void showWalletSelectionOverlay(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  void removeOverlay() {
    overlayEntry.remove();
  }

  overlayEntry = OverlayEntry(
    builder: (context) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: removeOverlay,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: WalletSelectionOverlay(
              onClose: removeOverlay,
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);
}

/// 지갑 선택 오버레이
class WalletSelectionOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const WalletSelectionOverlay({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<WalletSelectionOverlay> createState() =>
      _WalletSelectionOverlayState();
}

class _WalletSelectionOverlayState
    extends ConsumerState<WalletSelectionOverlay> {
  bool _isCheckingWallets = true;
  final Map<String, bool> _availableWallets = {};

  @override
  void initState() {
    super.initState();
    _checkAvailableWallets();
  }

  Future<void> _checkAvailableWallets() async {
    setState(() => _isCheckingWallets = true);

    // Web 환경에서는 window.ethereum, window.trustwallet 등을 확인
    // 모바일 환경에서는 항상 딥링크 지원으로 표시
    if (kIsWeb) {
      // Web: JS interop으로 확인
      _availableWallets['metamask'] = _isMetaMaskInstalled();
      _availableWallets['trustwallet'] = _isTrustWalletInstalled();
      _availableWallets['phantom'] = _isPhantomInstalled();
    } else {
      // Mobile: 딥링크는 항상 사용 가능 (앱 미설치시 스토어로 이동)
      _availableWallets['metamask'] = true;
      _availableWallets['phantom'] = true;
      _availableWallets['walletconnect'] = true; // 향후 구현
    }

    setState(() => _isCheckingWallets = false);
  }

  bool _isMetaMaskInstalled() {
    return WalletDetector.isMetaMaskInstalled();
  }

  bool _isTrustWalletInstalled() {
    return WalletDetector.isTrustWalletInstalled();
  }

  bool _isPhantomInstalled() {
    return WalletDetector.isPhantomInstalled();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                const Text(
                  'Connect Wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              kIsWeb
                  ? 'Choose your wallet extension'
                  : 'Choose your mobile wallet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 24),

            // 지갑 확인 중
            if (_isCheckingWallets)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._buildWalletOptions(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWalletOptions(BuildContext context) {
    final widgets = <Widget>[];

    // 선택된 체인 가져오기
    final selectedChain = ref.watch(selectedChainProvider);

    // MetaMask - EVM 체인 지원
    if (_availableWallets['metamask'] == true &&
        selectedChain.supportsWallet(WalletType.metamask)) {
      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_metamask.svg',
        title: 'MetaMask',
        description: kIsWeb
            ? 'Connect using browser extension'
            : 'Connect via MetaMask mobile app',
        onTap: () => _connectWallet(context, 'metamask'),
        isEnabled: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // Phantom - 여러 체인 지원 (Ethereum, Base, Polygon, Solana)
    if (_availableWallets['phantom'] == true &&
        selectedChain.supportsWallet(WalletType.phantom)) {
      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_phantom.png',
        title: 'Phantom',
        description: kIsWeb
            ? 'Connect using browser extension'
            : 'Connect via Phantom mobile app',
        onTap: () => _connectWallet(context, 'phantom'),
        isEnabled: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // Coinbase Wallet - EVM 체인만 지원
    if (selectedChain.supportsWallet(WalletType.coinbase)) {
      final isCoinbaseInstalled = kIsWeb
          ? WalletDetector.isCoinbaseWalletInstalled()
          : false; // 모바일은 딥링크로 시도

      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_cbw.svg',
        title: 'Coinbase Wallet',
        description: kIsWeb
            ? (isCoinbaseInstalled
                ? 'Connect using browser extension'
                : 'Install Coinbase Wallet extension')
            : 'Connect via Coinbase Wallet app',
        onTap: () {
          if (kIsWeb && !isCoinbaseInstalled) {
            // 설치되지 않은 경우 다운로드 페이지 열기
            WalletDetector.openCoinbaseDownload();
            widget.onClose();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please install Coinbase Wallet extension'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            _connectWallet(context, 'coinbase');
          }
        },
        isEnabled: true, // 설치 확인으로 변경하여 항상 활성화
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // Trust Wallet - EVM 체인 지원
    if (_availableWallets['trustwallet'] == true &&
        selectedChain.supportsWallet(WalletType.trustwallet)) {
      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_trust.png',
        title: 'Trust Wallet',
        description: kIsWeb
            ? 'Connect using browser extension'
            : 'Connect via Trust Wallet app',
        onTap: () => _connectWallet(context, 'trustwallet'),
        isEnabled: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // WalletConnect - 모든 플랫폼 지원 (Web: wagmi_web, Mobile: reown_appkit)
    if (selectedChain.supportsWallet(WalletType.walletconnect)) {
      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_walletconnect.svg',
        title: 'WalletConnect',
        description: 'Connect with QR in mobile phone',
        onTap: () => _connectWallet(context, 'walletconnect'),
        isEnabled: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // NEAR Protocol - 통합 모달 사용
    if (selectedChain == Chain.near && kIsWeb) {
      widgets.add(_WalletOptionButton(
        icon: 'assets/logo/icon_near.svg', // NEAR Protocol 로고
        title: 'NEAR Wallets',
        description: 'Connect with Meteor, MyNearWallet, or HERE Wallet',
        onTap: () => _connectWallet(context, 'near-modal'),
        isEnabled: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    // 사용 가능한 지갑이 없을 때
    if (widgets.isEmpty) {
      final chainName = selectedChain.name;
      final isSolana = selectedChain == Chain.solana;

      widgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.grey[600],
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  isSolana
                      ? 'Phantom wallet required for Solana'
                      : (kIsWeb
                          ? 'No wallet extension detected for $chainName'
                          : 'No wallet available for $chainName'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    widget.onClose();
                    if (isSolana) {
                      WalletDetector.openPhantomDownload();
                    } else {
                      WalletDetector.openMetaMaskDownload();
                    }
                  },
                  child:
                      Text(isSolana ? 'Install Phantom' : 'Install MetaMask'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Future<void> _connectWallet(BuildContext context, String walletType) async {
    // 선택된 체인 가져오기
    final selectedChain = ref.read(selectedChainProvider);

    // NEAR Protocol 지갑 연결 처리 - 통합 모달 사용
    if (walletType == 'near-modal') {
      if (selectedChain != Chain.near) {
        widget.onClose();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select NEAR Protocol chain first'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      widget.onClose();

      // NEAR Wallet Selector 모달 표시 및 연결
      try {
        final accountId = await NearJsInterop.showWalletModal();

        if (accountId != null && accountId.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to NEAR wallet: $accountId'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet connection cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        debugPrint('[NEAR Modal] Connection error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Solana 체인은 아직 지원하지 않음
    if (!selectedChain.isEVM) {
      widget.onClose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedChain.name} is not supported yet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final walletNotifier = ref.read(ethereumWalletProvider.notifier);

    // 1단계: 지갑 연결 (주소만 획득, 서명은 나중에)
    bool isConnected = false;
    switch (walletType) {
      case 'metamask':
        isConnected =
            await walletNotifier.connectMetaMask(autoAuthenticate: false);
        break;
      case 'phantom':
        isConnected =
            await walletNotifier.connectPhantom(autoAuthenticate: false);
        break;
      case 'coinbase':
        isConnected =
            await walletNotifier.connectCoinbase(autoAuthenticate: false);
        break;
      case 'trustwallet':
        isConnected =
            await walletNotifier.connectTrustWallet(autoAuthenticate: false);
        break;
      case 'walletconnect':
        // WalletConnect는 context가 필요하므로 특별 처리
        // 먼저 지갑 인스턴스를 생성하고 context 설정
        isConnected = await walletNotifier.connectWalletConnect(
          autoAuthenticate: false,
          context: context,
        );
        break;
    }

    // 연결 실패 확인
    if (!isConnected) {
      // 연결 실패 시 에러 메시지만 표시하고 지갑 선택 화면은 그대로 유지
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to connect to wallet. Please try another wallet.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // 지갑 선택 화면으로 돌아감
    }

    // 연결 직후 선택된 체인으로 전환 (overlay를 닫기 전에 수행)
    try {
      debugPrint(
          '[WalletConnect] Switching to ${selectedChain.name} before authentication...');
      await walletNotifier.switchChain(selectedChain.chainId);
      debugPrint('[WalletConnect] Chain switched successfully');
    } catch (e) {
      // 체인 전환 실패 시 네트워크 추가 시도
      debugPrint(
          '[WalletConnect] Chain switch failed, trying to add network: $e');
      try {
        await walletNotifier.addNetwork(
          EthereumNetwork(
            chainId: selectedChain.chainId,
            chainName: selectedChain.name,
            rpcUrl: selectedChain.rpcUrl,
            currencyName: _getCurrencyName(selectedChain),
            currencySymbol: _getCurrencySymbol(selectedChain),
            currencyDecimals: 18,
            blockExplorerUrl: _getBlockExplorerUrl(selectedChain),
          ),
        );
        debugPrint('[WalletConnect] Network added successfully');
      } catch (addError) {
        debugPrint('[WalletConnect] Failed to add network: $addError');
        // 체인 전환/추가 실패 시 경고만 표시하고 계속 진행
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not switch to ${selectedChain.name}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    // 연결 성공! 이제 지갑 선택 화면 닫기
    widget.onClose();

    // 2단계 안내 다이얼로그 표시
    if (!context.mounted) {
      debugPrint(
          '[WalletConnect] ❌ Context not mounted, aborting authentication');
      return;
    }

    debugPrint('[WalletConnect] Showing signature request dialog...');
    final shouldAuthenticate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignatureRequestDialog(walletType: walletType),
    );
    debugPrint('[WalletConnect] Signature dialog result: $shouldAuthenticate');

    if (shouldAuthenticate == true) {
      // 서명 진행 다이얼로그 표시
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _SignatureAuthDialog(walletType: walletType),
        );
      }

      // 2단계: 서명 인증 (이미 올바른 체인에 있는 상태)
      await walletNotifier.authenticate();
    } else {
      // 사용자가 서명 취소 → 연결 해제
      await walletNotifier.disconnect();
      return;
    }
  }

  // 체인별 통화 이름
  String _getCurrencyName(Chain chain) {
    switch (chain) {
      case Chain.ethereum:
        return 'Ether';
      case Chain.bnb:
        return 'BNB';
      case Chain.arbitrum:
        return 'Ether';
      case Chain.optimism:
        return 'Ether';
      case Chain.base:
        return 'Ether';
      case Chain.polygon:
        return 'MATIC';
      case Chain.solana:
        return 'SOL';
      case Chain.near:
        return 'NEAR';
    }
  }

  // 체인별 통화 심볼
  String _getCurrencySymbol(Chain chain) {
    switch (chain) {
      case Chain.ethereum:
      case Chain.arbitrum:
      case Chain.optimism:
      case Chain.base:
        return 'ETH';
      case Chain.bnb:
        return 'BNB';
      case Chain.polygon:
        return 'MATIC';
      case Chain.solana:
        return 'SOL';
      case Chain.near:
        return 'NEAR';
    }
  }

  // 체인별 블록 탐색기 URL
  String _getBlockExplorerUrl(Chain chain) {
    switch (chain) {
      case Chain.ethereum:
        return 'https://etherscan.io';
      case Chain.bnb:
        return 'https://bscscan.com';
      case Chain.arbitrum:
        return 'https://arbiscan.io';
      case Chain.optimism:
        return 'https://optimistic.etherscan.io';
      case Chain.base:
        return 'https://basescan.org';
      case Chain.polygon:
        return 'https://polygonscan.com';
      case Chain.solana:
        return 'https://explorer.solana.com';
      case Chain.near:
        return 'https://explorer.near.org';
    }
  }
}

/// 서명 요청 안내 다이얼로그 (2단계 전 안내)
class _SignatureRequestDialog extends StatelessWidget {
  final String walletType;

  const _SignatureRequestDialog({required this.walletType});

  String _getWalletName() {
    switch (walletType) {
      case 'metamask':
        return 'MetaMask';
      case 'phantom':
        return 'Phantom';
      case 'coinbase':
        return 'Coinbase Wallet';
      case 'trustwallet':
        return 'Trust Wallet';
      case 'walletconnect':
        return 'WalletConnect';
      default:
        return 'Wallet';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2329),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.dexSecondary,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.edit_note,
                size: 32,
                color: Color(0xFFF0B90B),
              ),
            ),
            const SizedBox(height: 20),

            // 제목
            const Text(
              'Signature Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // 설명
            Text(
              '${_getWalletName()} 연결이 완료되었습니다.\n\n서명은 소유권 확인 및 지갑 호환성 확인에 사용됩니다.\n\n계속하려면 지갑에서 메시지에 서명해주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFB7BDC6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                // 취소 버튼
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: AppTheme.dexSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),

                // 계속 버튼
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0B90B),
                      foregroundColor: const Color(0xFF1E2329),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Sign Message',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 서명 인증 진행 다이얼로그
class _SignatureAuthDialog extends ConsumerStatefulWidget {
  final String walletType;

  const _SignatureAuthDialog({required this.walletType});

  @override
  ConsumerState<_SignatureAuthDialog> createState() =>
      _SignatureAuthDialogState();
}

class _SignatureAuthDialogState extends ConsumerState<_SignatureAuthDialog> {
  bool _dialogClosed = false;

  @override
  Widget build(BuildContext context) {
    // 다이얼로그가 이미 닫혔으면 ref 사용 안함
    if (_dialogClosed) {
      return const SizedBox.shrink();
    }

    final walletState = ref.watch(ethereumWalletProvider);

    // 인증 완료 시 1초 후 다이얼로그 자동 닫기
    if (walletState.isAuthenticated && !_dialogClosed) {
      _dialogClosed = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    // 에러 발생 시 다이얼로그 즉시 닫기
    // isConnecting, isAuthenticating 상태와 관계없이 에러가 있으면 닫기
    if (walletState.error != null &&
        !walletState.isConnecting &&
        !walletState.isAuthenticating &&
        !_dialogClosed) {
      _dialogClosed = true;
      Future.microtask(() {
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    return Dialog(
      backgroundColor: AppTheme.dexSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            const Text(
              'Signature Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 아이콘
            if (walletState.isAuthenticating)
              CircularProgressIndicator(
                color: AppTheme.primary,
              )
            else if (walletState.isAuthenticated)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              )
            else
              CircularProgressIndicator(
                color: AppTheme.primary,
              ),

            const SizedBox(height: 24),

            // 설명 텍스트
            Text(
              walletState.isAuthenticating
                  ? '서명 요청 중...'
                  : walletState.isAuthenticated
                      ? '인증 완료!'
                      : '지갑 연결 중...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            // 상세 설명
            Text(
              _getWalletDescription(widget.walletType),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 24),

            // 진행 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusDot(
                  isActive: walletState.address != null,
                  label: '지갑 연결',
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 2,
                  color: walletState.isAuthenticating ||
                          walletState.isAuthenticated
                      ? AppTheme.primary
                      : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                _buildStatusDot(
                  isActive: walletState.isAuthenticating ||
                      walletState.isAuthenticated,
                  label: '서명 요청',
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 2,
                  color: walletState.isAuthenticated
                      ? AppTheme.primary
                      : Colors.grey[700],
                ),
                const SizedBox(width: 8),
                _buildStatusDot(
                  isActive: walletState.isAuthenticated,
                  label: '완료',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot({required bool isActive, required String label}) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primary : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  String _getWalletDescription(String walletType) {
    switch (walletType) {
      case 'metamask':
        return 'DEX 사이트와 MetaMask를 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
      case 'phantom':
        return 'DEX 사이트와 Phantom을 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
      case 'coinbase':
        return 'DEX 사이트와 Coinbase Wallet을 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
      case 'trustwallet':
        return 'DEX 사이트와 Trust Wallet을 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
      case 'walletconnect':
        return 'DEX 사이트와 WalletConnect를 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
      default:
        return 'DEX 사이트와 지갑을 연결하기 위한 서명입니다.\n지갑에서 서명 요청을 승인해주세요.';
    }
  }
}

/// 지갑 옵션 버튼
class _WalletOptionButton extends StatefulWidget {
  final String icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isEnabled;

  const _WalletOptionButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<_WalletOptionButton> createState() => _WalletOptionButtonState();
}

class _WalletOptionButtonState extends State<_WalletOptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.isEnabled ? widget.onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered && widget.isEnabled
                ? Color.lerp(AppTheme.dexSurface, Colors.white, 0.1)
                : AppTheme.dexSurface,
            borderRadius: BorderRadius.circular(0),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 아이콘
              SizedBox(
                width: 32,
                height: 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (widget.icon.endsWith('svg'))
                      ? SvgPicture.asset(
                          widget.icon,
                        )
                      : Image.asset(
                          widget.icon,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.black,
                              size: 24,
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isEnabled ? Colors.white : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // 화살표
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: widget.isEnabled ? Colors.grey[400] : Colors.grey[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
