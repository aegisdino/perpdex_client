# Ethereum Wallet Integration

이 문서는 DEX 애플리케이션에 통합된 Ethereum 지갑 기능을 설명합니다.

## 구조

### 파일 구조
```
lib/walletservice/
├── ethereum_wallet.dart              # 추상 클래스 및 네트워크 정의
├── metamask_wallet.dart              # MetaMask 구현 (Web)
├── metamask_mobile.dart              # MetaMask 구현 (Mobile - 딥링크)
├── ethereum_wallet_provider.dart     # Riverpod 상태 관리
└── ETHEREUM_WALLET_README.md        # 이 문서
```

### 주요 컴포넌트

#### 1. EthereumWallet (추상 클래스)
모든 Ethereum 지갑 구현의 기본 인터페이스입니다.

**주요 메서드:**
- `connect()`: 지갑 연결
- `disconnect()`: 지갑 연결 해제
- `getBalance(address)`: ETH 잔액 조회 (Wei 단위)
- `sendTransaction()`: 트랜잭션 전송
- `signMessage()`: 메시지 서명
- `signTypedData()`: EIP-712 타입화된 데이터 서명
- `switchChain()`: 체인 전환
- `addNetwork()`: 네트워크 추가

**이벤트 스트림:**
- `onAccountsChanged`: 계정 변경 시 발생
- `onChainChanged`: 체인 변경 시 발생
- `onDisconnect`: 연결 해제 시 발생

#### 2. MetaMaskWallet (Web 및 Mobile)
`EthereumWallet`을 구현한 MetaMask 지갑 클래스입니다.

**Conditional Import:**
- Web 환경: `metamask_wallet.dart` 사용 (`window.ethereum` JS interop)
- Mobile 환경: `metamask_mobile.dart` 사용 (딥링크 방식)

**Web 버전 특징:**
- `window.ethereum`을 통한 MetaMask 확장 프로그램 연동
- JS interop을 통한 실시간 이벤트 처리 (계정/체인 변경)
- 브라우저 확장 프로그램 미설치 시 다운로드 페이지로 리다이렉트

**Mobile 버전 특징:**
- 딥링크 스키마: `metamask://`
- 앱 간 통신을 통한 지갑 연동
- MetaMask 앱 미설치 시 앱스토어로 리다이렉트
- 콜백 URL: `[앱스키마]://metamask/callback`

**딥링크 예시:**
```
metamask://connect?redirect=myapp://metamask/callback
metamask://send?to=0x...&value=0x...&redirect=myapp://metamask/callback
```

**사용 예:**
```dart
// Web과 Mobile 모두 동일한 API 사용
final wallet = MetaMaskWallet(); // 플랫폼에 따라 자동으로 적절한 구현 선택
final address = await wallet.connect();
final balance = await wallet.getBalance(address);
```

#### 3. EthereumWalletProvider
Riverpod을 사용한 전역 상태 관리입니다.

**주요 Provider:**
- `ethereumWalletProvider`: 메인 지갑 상태
- `isWalletConnectedProvider`: 연결 여부
- `walletAddressProvider`: 연결된 주소
- `walletBalanceProvider`: ETH 잔액 (ETH 단위)
- `chainIdProvider`: 현재 체인 ID

**상태 구조:**
```dart
class EthereumWalletState {
  final String? address;        // 연결된 주소
  final String? chainId;        // 현재 체인 ID (0x1 = Mainnet)
  final BigInt? balance;        // 잔액 (Wei 단위)
  final String? walletType;     // 'metamask' 또는 'walletconnect'
  final bool isConnecting;      // 연결 진행 중 여부
  final String? error;          // 에러 메시지
}
```

#### 4. WalletConnectButton (UI 컴포넌트)
Trading 화면에 통합된 지갑 연결 버튼입니다.

**기능:**
- 미연결 시: "Connect Wallet" 버튼 표시
- 연결 시: 주소, 잔액 표시 및 메뉴 제공
  - Copy Address: 주소 클립보드 복사
  - Refresh Balance: 잔액 새로고침
  - Disconnect: 연결 해제

## 사용 방법

### 1. 지갑 연결
```dart
// Riverpod을 통한 연결
ref.read(ethereumWalletProvider.notifier).connectMetaMask();

// 연결 상태 확인
final isConnected = ref.watch(isWalletConnectedProvider);
```

### 2. 잔액 조회
```dart
// ETH 단위 잔액
final balance = ref.watch(walletBalanceProvider); // double?

// 또는 직접 업데이트
await ref.read(ethereumWalletProvider.notifier).updateBalance();
```

### 3. 트랜잭션 전송
```dart
final notifier = ref.read(ethereumWalletProvider.notifier);

try {
  final txHash = await notifier.sendTransaction(
    to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
    value: BigInt.from(1e18), // 1 ETH in Wei
  );
  print('Transaction sent: $txHash');
} catch (e) {
  print('Error: $e');
}
```

### 4. 메시지 서명
```dart
final notifier = ref.read(ethereumWalletProvider.notifier);

try {
  final signature = await notifier.signMessage('Hello, World!');
  print('Signature: $signature');
} catch (e) {
  print('Error: $e');
}
```

### 5. 체인 전환
```dart
final notifier = ref.read(ethereumWalletProvider.notifier);

// Arbitrum으로 전환
await notifier.switchChain('0xa4b1');

// 또는 네트워크 정의 사용
await notifier.switchChain(EthereumNetwork.arbitrum.chainId);
```

### 6. 네트워크 추가
```dart
final notifier = ref.read(ethereumWalletProvider.notifier);

// 미리 정의된 네트워크 추가
await notifier.addNetwork(EthereumNetwork.base);

// 또는 커스텀 네트워크 추가
await notifier.addNetwork(
  EthereumNetwork(
    chainId: '0x89',
    chainName: 'Polygon',
    rpcUrl: 'https://polygon-bor.publicnode.com',
    currencyName: 'MATIC',
    currencySymbol: 'MATIC',
    currencyDecimals: 18,
    blockExplorerUrl: 'https://polygonscan.com',
  ),
);
```

## 지원 네트워크

기본적으로 다음 네트워크가 정의되어 있습니다:

| 네트워크 | Chain ID | 심볼 |
|---------|----------|------|
| Ethereum Mainnet | 0x1 | ETH |
| Sepolia Testnet | 0xaa36a7 | ETH |
| Arbitrum One | 0xa4b1 | ETH |
| Optimism | 0xa | ETH |
| Polygon | 0x89 | MATIC |
| Base | 0x2105 | ETH |

## 이벤트 처리

지갑 이벤트는 자동으로 Provider에 반영됩니다:

```dart
// 계정 변경 감지
ref.listen(walletAddressProvider, (previous, next) {
  if (previous != next) {
    print('Account changed: $previous -> $next');
  }
});

// 체인 변경 감지
ref.listen(chainIdProvider, (previous, next) {
  if (previous != next) {
    print('Chain changed: $previous -> $next');
  }
});

// 연결 상태 변경 감지
ref.listen(isWalletConnectedProvider, (previous, next) {
  if (previous != next) {
    print('Connection status changed: $next');
  }
});
```

## 에러 처리

```dart
// 에러 상태 확인
final walletState = ref.watch(ethereumWalletProvider);
if (walletState.error != null) {
  print('Error: ${walletState.error}');
}

// 에러 초기화
ref.read(ethereumWalletProvider.notifier).clearError();
```

## 향후 계획

### WalletConnect v2 통합 (TODO)
WalletConnect를 통한 모바일 지갑 연결 지원 예정:
- QR 코드 스캔으로 모바일 지갑 연결
- Trust Wallet, Rainbow, Coinbase Wallet 등 지원
- 딥링크를 통한 모바일 앱 연동

**필요한 패키지:**
```yaml
dependencies:
  walletconnect_flutter_v2: ^2.1.0
```

## 지갑 감지 방법

### Web 환경에서 정확한 지갑 감지

`window.ethereum`은 여러 지갑이 제공할 수 있으므로, 각 지갑의 고유 속성을 확인해야 합니다:

**MetaMask 감지:**
```javascript
// window.ethereum 존재 확인
window.ethereum !== undefined
// AND
// MetaMask 고유 속성 확인
window.ethereum.isMetaMask === true
```

**Trust Wallet 감지:**
```javascript
// 방법 1: 전용 객체 확인
window.trustwallet !== undefined
// OR
// 방법 2: ethereum 객체의 속성 확인
window.ethereum.isTrust === true
```

**Coinbase Wallet 감지:**
```javascript
// 방법 1: 전용 객체 확인
window.coinbaseWalletExtension !== undefined
// OR
// 방법 2: ethereum 객체의 속성 확인
window.ethereum.isCoinbaseWallet === true
```

### 여러 지갑이 설치된 경우

여러 지갑이 설치된 경우 `window.ethereum`은 일반적으로 마지막에 설치된 지갑이 제공합니다.

**우리의 감지 우선순위:**
1. MetaMask (`window.ethereum.isMetaMask`)
2. Coinbase Wallet (`window.ethereum.isCoinbaseWallet`)
3. Trust Wallet (`window.ethereum.isTrust`)
4. 기타 (알 수 없는 지갑)

**구현 위치:** `lib/pages/dex/widgets/wallet_detector_web.dart`

## 주의사항

1. **플랫폼별 구현**: Web과 Mobile에서 다른 구현이 사용되지만 API는 동일합니다.
2. **Wei 단위**: 모든 금액은 Wei 단위로 처리됩니다. (1 ETH = 10^18 Wei)
3. **사용자 승인**: 모든 트랜잭션과 서명은 사용자의 MetaMask 승인이 필요합니다.
4. **체인 ID**: 체인 ID는 16진수 문자열로 표현됩니다. (예: '0x1', '0xa4b1')
5. **에러 처리**: 네트워크 에러, 사용자 거부 등 다양한 에러 케이스를 처리해야 합니다.
6. **딥링크 콜백**: 모바일에서는 앱의 딥링크 스키마를 등록해야 합니다.
   - Android: `AndroidManifest.xml`에 intent-filter 추가
   - iOS: `Info.plist`에 URL Scheme 추가
7. **지갑 감지**: `window.ethereum`만으로는 부족합니다. 각 지갑의 고유 속성(`isMetaMask`, `isTrust` 등)을 확인해야 정확합니다.

## 모바일 딥링크 설정

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<activity android:name=".MainActivity">
    <!-- 기존 설정... -->

    <!-- MetaMask 콜백 -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="bitupdownapp" android:host="metamask" />
    </intent-filter>
</activity>
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>bitupdownapp</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp</string>
    </dict>
</array>
```

## 모바일 제약사항

모바일 딥링크 방식에서는 다음 기능이 제한됩니다:

1. **실시간 이벤트**: 계정/체인 변경 이벤트가 자동으로 감지되지 않음
2. **체인 전환**: 딥링크로 체인 전환이 불가능 (사용자가 MetaMask 앱에서 직접 변경)
3. **네트워크 추가**: 딥링크로 네트워크 추가 불가능
4. **잔액 조회**: RPC 엔드포인트를 통해 별도로 조회해야 함

**해결 방법:**
- 잔액 조회는 `web3dart` 패키지의 `Web3Client`를 사용하여 RPC로 직접 조회
- 체인 전환은 사용자에게 MetaMask 앱에서 변경하도록 안내

## 디버깅

```dart
// 현재 상태 출력
final state = ref.read(ethereumWalletProvider);
print(state.toString());

// 잔액 Wei -> ETH 변환
final balanceWei = state.balance;
final balanceEth = balanceWei != null ? balanceWei.toDouble() / 1e18 : 0.0;
print('Balance: $balanceEth ETH');
```

## 참고 자료

- [MetaMask 문서](https://docs.metamask.io/)
- [EIP-1193](https://eips.ethereum.org/EIPS/eip-1193): Ethereum Provider JavaScript API
- [EIP-712](https://eips.ethereum.org/EIPS/eip-712): Typed structured data hashing and signing
- [web3dart 패키지](https://pub.dev/packages/web3dart)
