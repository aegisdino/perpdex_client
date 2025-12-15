// wallet-selector.source.js
// Source file for bundling NEAR Wallet Selector

import { setupWalletSelector } from '@near-wallet-selector/core';
import { setupModal } from '@near-wallet-selector/modal-ui';
import { setupMyNearWallet } from '@near-wallet-selector/my-near-wallet';
import { setupMeteorWallet } from '@near-wallet-selector/meteor-wallet';
import { setupHereWallet } from '@near-wallet-selector/here-wallet';
import { setupNightly } from '@near-wallet-selector/nightly';
import { setupSender } from '@near-wallet-selector/sender';
import { setupWalletConnect } from '@near-wallet-selector/wallet-connect';

console.log("[NEAR Wallet Selector] 번들 초기화 중...");

// 글로벌 번들 객체 생성
window.NearWalletSelectorBundle = {
  setupWalletSelector,
  setupModal,
  setupMyNearWallet,
  setupMeteorWallet,
  setupHereWallet,
  setupNightly,
  setupSender,
  setupWalletConnect,
};

console.log("✅ NEAR Wallet Selector 번들 준비 완료");
