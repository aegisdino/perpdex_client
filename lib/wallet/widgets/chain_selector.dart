import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

import '../../common/theme.dart';
import '../../wallet/providers/ethereum_wallet_provider.dart';
import '../../wallet/core/ethereum_wallet.dart';

/// 지원하는 지갑 타입
enum WalletType {
  metamask,
  walletconnect,
  phantom,
  coinbase,
  trustwallet,
  meteor,
  mynearwallet,
  herewallet,
}

class ChainIconData {
  final String path;
  final double? scale;
  final Color? color;

  const ChainIconData(this.path, {this.scale, this.color});
}

/// 지원하는 블록체인
enum Chain {
  ethereum(
    'Ethereum',
    ChainIconData('assets/logo/icon_ethereum.svg', scale: 1.2),
    '0x1',
    'https://eth.llamarpc.com',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
      WalletType.phantom
    ],
  ),
  bnb(
    'BNB Chain',
    ChainIconData('assets/logo/icon_bnb.svg', scale: 1.3),
    '0x38',
    'https://bsc-dataseed.binance.org',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
    ],
  ),
  arbitrum(
    'Arbitrum',
    ChainIconData('assets/logo/icon_arbitrum.png', scale: 1.1),
    '0xa4b1',
    'https://arb1.arbitrum.io/rpc',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
    ],
  ),
  optimism(
    'Optimism',
    ChainIconData('assets/logo/icon_optimism.png'),
    '0xa',
    'https://mainnet.optimism.io',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
    ],
  ),
  base(
    'Base',
    ChainIconData('assets/logo/icon_base.png'),
    '0x2105',
    'https://mainnet.base.org',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
      WalletType.phantom
    ],
  ),
  polygon(
    'Polygon',
    ChainIconData('assets/logo/icon_polygon.png'),
    '0x89',
    'https://polygon-rpc.com',
    [
      WalletType.metamask,
      WalletType.walletconnect,
      WalletType.coinbase,
      WalletType.trustwallet,
      WalletType.phantom
    ],
  ),
  solana(
    'Solana',
    ChainIconData('assets/logo/icon_solana.png'),
    'solana',
    'https://api.mainnet-beta.solana.com',
    [WalletType.phantom], // Solana는 Phantom만 지원
  ),
  near(
    'NEAR Protocol',
    ChainIconData(
      'assets/logo/icon_near.svg',
      scale: 0.8,
      color: Colors.white,
    ),
    'near',
    'https://rpc.mainnet.near.org',
    [
      WalletType.meteor,
      WalletType.mynearwallet,
      WalletType.herewallet
    ], // NEAR는 Meteor, MyNearWallet, HERE Wallet 지원
  );

  const Chain(
      this.name, this.icon, this.chainId, this.rpcUrl, this.supportedWallets);
  final String name;
  final ChainIconData icon;
  final String chainId; // EVM: hex chainId, Solana: 'solana'
  final String rpcUrl;
  final List<WalletType> supportedWallets;

  /// EVM 호환 체인인지 확인
  bool get isEVM => chainId != 'solana' && chainId != 'near';

  /// 특정 지갑이 이 체인에서 지원되는지 확인
  bool supportsWallet(WalletType wallet) => supportedWallets.contains(wallet);
}

class IconView extends StatelessWidget {
  final ChainIconData icon;
  final double? size;
  const IconView({
    required this.icon,
    this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: Transform.scale(
        scale: icon.scale ?? 1.0,
        child: icon.path.endsWith('svg')
            ? SvgPicture.asset(
                icon.path,
                width: size ?? 20,
                height: size ?? 20,
                fit: BoxFit.fitWidth,
                colorFilter: icon.color != null
                    ? ColorFilter.mode(
                        icon.color!,
                        BlendMode.srcIn,
                      )
                    : null,
                placeholderBuilder: (context) => const SizedBox.shrink(),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    icon.path,
                    width: size ?? 20,
                    height: size ?? 20,
                    fit: BoxFit.fitWidth,
                    filterQuality: FilterQuality.high, // 높은 품질의 다운샘플링
                    isAntiAlias: true, // 앤티앨리어싱 활성화
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// 선택된 체인 상태 관리
class SelectedChainNotifier extends Notifier<Chain> {
  @override
  Chain build() => Chain.ethereum;

  void selectChain(Chain chain) {
    state = chain;
  }
}

/// 선택된 체인 Provider
final selectedChainProvider = NotifierProvider<SelectedChainNotifier, Chain>(
  () => SelectedChainNotifier(),
);

/// 체인 선택 드롭다운 버튼
class ChainSelector extends ConsumerStatefulWidget {
  const ChainSelector({super.key});

  @override
  ConsumerState<ChainSelector> createState() => _ChainSelectorState();
}

class _ChainSelectorState extends ConsumerState<ChainSelector> {
  @override
  Widget build(BuildContext context) {
    final selectedChain = ref.watch(selectedChainProvider);

    return PopupMenuButton<Chain>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 체인 아이콘만 표시
            IconView(icon: selectedChain.icon, size: 20),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 18,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => Chain.values
          .map((chain) => PopupMenuItem<Chain>(
                value: chain,
                child: Row(
                  children: [
                    IconView(
                      icon: chain.icon,
                    ),
                    const SizedBox(width: 12),
                    // 체인 이름
                    Text(
                      chain.name,
                      style: TextStyle(
                        color: selectedChain == chain
                            ? AppTheme.primary
                            : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    // 선택된 체인 표시
                    if (selectedChain == chain)
                      Icon(
                        Icons.check,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              ))
          .toList(),
      onSelected: (chain) async {
        final previousChain = ref.read(selectedChainProvider);

        // 체인 선택 업데이트
        ref.read(selectedChainProvider.notifier).selectChain(chain);

        // 지갑이 연결되어 있으면 체인 전환 시도
        final walletState = ref.read(ethereumWalletProvider);
        if (walletState.isConnected && walletState.isAuthenticated) {
          // Solana와 NEAR는 아직 체인 전환 미지원 (별도 지갑 연결 필요)
          if (!chain.isEVM) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('${chain.name} requires separate wallet connection'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            // 이전 체인으로 롤백
            ref.read(selectedChainProvider.notifier).selectChain(previousChain);
            return;
          }

          // 현재 지갑의 체인과 다르면 전환 시도
          if (walletState.chainId != chain.chainId) {
            try {
              final walletNotifier = ref.read(ethereumWalletProvider.notifier);

              debugPrint('[ChainSelector] Switching chain to ${chain.name}...');
              await walletNotifier.switchChain(chain.chainId);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to ${chain.name}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              debugPrint('[ChainSelector] Chain switch failed: $e');

              // 체인 전환 실패 시 네트워크 추가 시도
              try {
                final walletNotifier =
                    ref.read(ethereumWalletProvider.notifier);
                await walletNotifier.addNetwork(
                  EthereumNetwork(
                    chainId: chain.chainId,
                    chainName: chain.name,
                    rpcUrl: chain.rpcUrl,
                    currencyName: _getCurrencyName(chain),
                    currencySymbol: _getCurrencySymbol(chain),
                    currencyDecimals: 18,
                    blockExplorerUrl: _getBlockExplorerUrl(chain),
                  ),
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${chain.name} network'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (addError) {
                debugPrint('[ChainSelector] Failed to add network: $addError');

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to switch to ${chain.name}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }

                // 실패 시 이전 체인으로 롤백
                ref
                    .read(selectedChainProvider.notifier)
                    .selectChain(previousChain);
              }
            }
          }
        }
      },
    );
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
