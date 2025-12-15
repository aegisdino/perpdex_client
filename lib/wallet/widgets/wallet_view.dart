import 'package:flutter/material.dart';

import 'chain_selector.dart';
import 'wallet_connect_button.dart';

class ChainWalletView extends StatelessWidget {
  const ChainWalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const ChainSelector(),
      const SizedBox(width: 12),
      const WalletConnectButton(),
    ]);
  }
}
