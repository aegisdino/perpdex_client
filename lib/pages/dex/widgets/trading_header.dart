import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/wallet/wallet.dart';
import '/view/common/logoview.dart';

class TradingHeader extends ConsumerStatefulWidget {
  const TradingHeader({super.key});

  @override
  ConsumerState<TradingHeader> createState() => _TradingHeaderState();
}

class _TradingHeaderState extends ConsumerState<TradingHeader> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LogoView(height: 30, path: 'logo.png'),
          Expanded(child: Container()),
          const ChainWalletView(),
        ],
      ),
    );
  }
}
