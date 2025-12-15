# NEAR Wallet Selector 통합 가이드

## 개요

이 문서는 NEAR Wallet Selector를 사용하여 추가 지갑을 통합하는 방법을 설명합니다.

## 현재 지원 지갑

- **Meteor Wallet** - 브라우저 확장 지갑
- **MyNearWallet** - 브라우저 기반 지갑
- **HERE Wallet** - 모바일 지갑

## 추가 가능한 지갑 목록

NEAR Wallet Selector는 다음 지갑들을 지원합니다:

### 브라우저 지갑
- `@near-wallet-selector/arepa-wallet` - Arepa Wallet

### 주입형 지갑 (브라우저 확장)
- `@near-wallet-selector/bitget-wallet` - Bitget Wallet
- `@near-wallet-selector/bitte-wallet` - Bitte Wallet
- `@near-wallet-selector/coin98-wallet` - Coin98 Wallet
- `@near-wallet-selector/ethereum-wallets` - Ethereum Wallets
- `@near-wallet-selector/hot-wallet` - HOT Wallet
- `@near-wallet-selector/math-wallet` - Math Wallet
- `@near-wallet-selector/near-snap` - MetaMask Snap for NEAR
- `@near-wallet-selector/nightly` - Nightly Wallet
- `@near-wallet-selector/narwallets` - Narwallets
- `@near-wallet-selector/okx-wallet` - OKX Wallet
- `@near-wallet-selector/ramper-wallet` - Ramper Wallet
- `@near-wallet-selector/sender` - Sender Wallet
- `@near-wallet-selector/welldone-wallet` - WELLDONE Wallet
- `@near-wallet-selector/xdefi` - XDEFI Wallet

### 모바일 지갑
- `@near-wallet-selector/near-mobile-wallet` - NEAR Mobile Wallet
- `@near-wallet-selector/unity-wallet` - Unity Wallet

### 브리지 지갑
- `@near-wallet-selector/wallet-connect` - WalletConnect

### 하드웨어 지갑
- `@near-wallet-selector/ledger` - Ledger

## 새 지갑 추가 방법

### 1단계: npm 패키지 설치

원하는 지갑의 npm 패키지를 설치합니다.

예시: Nightly, Sender, WalletConnect 추가
```bash
cd web
npm install @near-wallet-selector/nightly @near-wallet-selector/sender @near-wallet-selector/wallet-connect
```

### 2단계: wallet-selector.source.js 수정

`web/wallet-selector.source.js` 파일에 지갑 설정 함수를 import하고 export합니다.

```javascript
// wallet-selector.source.js
import { setupWalletSelector } from '@near-wallet-selector/core';
import { setupModal } from '@near-wallet-selector/modal-ui';
import { setupMyNearWallet } from '@near-wallet-selector/my-near-wallet';
import { setupMeteorWallet } from '@near-wallet-selector/meteor-wallet';
import { setupHereWallet } from '@near-wallet-selector/here-wallet';

// 새 지갑 추가
import { setupNightly } from '@near-wallet-selector/nightly';
import { setupSender } from '@near-wallet-selector/sender';
import { setupWalletConnect } from '@near-wallet-selector/wallet-connect';

window.NearWalletSelectorBundle = {
  setupWalletSelector,
  setupModal,
  setupMyNearWallet,
  setupMeteorWallet,
  setupHereWallet,
  // 새 지갑 추가
  setupNightly,
  setupSender,
  setupWalletConnect,
};
```

### 3단계: near_selector.js 수정

`web/scripts/near_selector.js` 파일의 `initNearWalletSelector` 함수에서 지갑 모듈을 추가합니다.

**파일 위치**: `web/scripts/near_selector.js:49-56`

**수정 전**:
```javascript
selector = await bundle.setupWalletSelector({
    network: networkConfig.networkId,
    modules: [
        bundle.setupMeteorWallet(),
        bundle.setupMyNearWallet(),
        bundle.setupHereWallet(),
    ],
});
```

**수정 후**:
```javascript
selector = await bundle.setupWalletSelector({
    network: networkConfig.networkId,
    modules: [
        bundle.setupMeteorWallet(),
        bundle.setupMyNearWallet(),
        bundle.setupHereWallet(),
        // 새 지갑 추가
        bundle.setupNightly(),
        bundle.setupSender(),
        bundle.setupWalletConnect({
            projectId: "your-walletconnect-project-id",
            metadata: {
                name: "Perpdex",
                description: "Perpdex DEX Platform",
                url: "https://perpdex.io",
                icons: ["https://perpdex.io/icon.png"],
            },
            chainId: "near:mainnet",
        }),
    ],
});
```

> **참고**: WalletConnect는 추가 설정이 필요합니다. [WalletConnect Cloud](https://cloud.walletconnect.com/)에서 프로젝트 ID를 발급받아야 합니다.

### 4단계: 번들 재빌드

```bash
cd web
node build.mjs
```

빌드가 완료되면 `wallet-selector.bundle.js` 파일이 업데이트됩니다.

### 5단계: 테스트

1. 브라우저를 완전히 새로고침 (Ctrl+Shift+R 또는 Cmd+Shift+R)
2. NEAR 체인 선택
3. "NEAR Wallets" 버튼 클릭
4. 모달에서 새로 추가된 지갑들이 나타나는지 확인

## 지갑별 특이사항

### WalletConnect
- 프로젝트 ID 필수
- metadata 설정 필요
- 모바일 지갑 연결에 특화

### Ledger
- 하드웨어 지갑이므로 USB 연결 필요
- 추가 권한 설정 필요할 수 있음

### MetaMask Snap (near-snap)
- MetaMask 브라우저 확장이 설치되어 있어야 함
- NEAR Snap이 MetaMask에 설치되어야 함

## 자동 재연결

NEAR Wallet Selector는 localStorage를 사용하여 연결 상태를 자동으로 저장하고 복원합니다.

앱 재시작 시:
1. JavaScript가 `initNearWalletSelector()` 호출
2. localStorage에서 이전 세션 확인
3. 저장된 계정이 있으면 `selector.store.getState()`에서 복원
4. Dart의 `NearWalletNotifier._autoReconnect()`가 상태 업데이트

## 서명 및 트랜잭션

모달로 연결한 후 서명 요청:

### 메시지 서명 (NEP-413)
```dart
final result = await NearJsInterop.signMessage(
  message: 'Hello NEAR',
  recipient: 'perpdex.near',
  nonce: [1, 2, 3, ...], // 32 bytes
);
// result = { 'signature': '...', 'publicKey': '...' }
```

### 트랜잭션 전송
```dart
final txHash = await NearJsInterop.sendTransaction(
  receiverId: 'contract.near',
  actions: [
    {
      'type': 'FunctionCall',
      'params': {
        'methodName': 'deposit',
        'args': {...},
        'gas': '30000000000000',
        'deposit': '1000000000000000000000000',
      }
    }
  ],
  walletType: 'near-modal',
);
```

## 참고 자료

- [NEAR Wallet Selector GitHub](https://github.com/near/wallet-selector)
- [NEAR Wallet Selector 문서](https://docs.near.org/tools/wallet-selector)
- [WalletConnect Cloud](https://cloud.walletconnect.com/)
- [NEP-413 (메시지 서명 표준)](https://github.com/near/NEPs/blob/master/neps/nep-0413.md)

## 파일 구조

```
perp_client/
├── web/
│   ├── wallet-selector.source.js      # 번들링할 소스 파일
│   ├── build.mjs                       # esbuild 설정
│   ├── wallet-selector.bundle.js       # 생성된 번들 (3.9MB)
│   ├── scripts/
│   │   └── near_selector.js           # NEAR API 래퍼
│   └── index.html                      # 메인 HTML (번들 로드)
├── lib/
│   └── wallet/
│       ├── utils/
│       │   └── near_js_interop.dart   # Dart-JS 인터롭
│       ├── providers/
│       │   └── near_wallet_provider.dart  # 상태 관리
│       └── widgets/
│           └── wallet_connect_button.dart # UI
└── docs/
    └── near_wallet_integration.md      # 이 문서
```

## 트러블슈팅

### 번들 로드 실패
- 브라우저 콘솔에서 `window.NearWalletSelectorBundle` 확인
- `build.mjs` 실행 후 에러 메시지 확인
- `wallet-selector.bundle.js` 파일이 생성되었는지 확인

### 모달에 지갑이 안 나타남
- `near_selector.js`의 `modules` 배열에 추가했는지 확인
- npm 패키지가 정확히 설치되었는지 확인
- 번들을 재빌드했는지 확인

### 연결은 되는데 서명이 안됨
- NEP-413 표준을 지원하지 않는 지갑일 수 있음
- `recipient`와 `nonce` 파라미터 확인
- 브라우저 콘솔에서 에러 메시지 확인

## 버전 정보

- NEAR Wallet Selector: v8.9.13
- 번들 크기: ~3.9MB (압축 전)
- Node.js 폴리필: buffer, process 포함
