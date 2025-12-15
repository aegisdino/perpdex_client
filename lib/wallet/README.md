# Wallet SDK

재사용 가능한 Web3 지갑 연동 라이브러리입니다. 여러 지갑을 쉽게 통합하고 관리할 수 있습니다.

## 지원 지갑

- ✅ **MetaMask** - 가장 인기있는 Ethereum 지갑
- ✅ **Phantom** - Solana 및 Ethereum 지원
- ✅ **Coinbase Wallet** - Coinbase의 공식 지갑
- ✅ **Trust Wallet** - 멀티체인 모바일 지갑
- ⏳ **WalletConnect** - 모든 지갑 지원 (향후 구현)

## 지원 체인

- Ethereum Mainnet
- BNB Chain
- Arbitrum
- Optimism
- Base
- Polygon
- Solana (Phantom만 지원)

## 주요 기능

### 1. Nonce 기반 서명 인증
- UUID nonce 생성 및 SessionStorage 관리
- 재사용 공격(Replay Attack) 방지
- 모든 지갑에서 자동으로 동작

### 2. 멀티 플랫폼 지원
- **Web**: Browser extension 자동 감지 및 연결
- **Mobile**: Deep link를 통한 네이티브 앱 연동

### 3. 상태 관리
- Riverpod 기반 상태 관리
- 실시간 지갑 상태 업데이트
- 연결, 체인 변경, 잔액 조회 등

## 설치

이 SDK는 프로젝트 내부에 포함되어 있습니다.

```dart
import 'package:perpdex/wallet/wallet.dart';
```

## 사용법

### 인증 모드 설정 (필수)

앱 시작 시 인증 모드를 설정해야 합니다:

```dart
import 'package:perpdex/wallet/wallet.dart';

void main() {
  // 옵션 1: 클라이언트 모드 (프로토타입/개발용)
  AuthService.configure(mode: AuthMode.client);

  // 옵션 2: 서버 모드 (프로덕션 권장)
  // AuthService.configure(
  //   mode: AuthMode.server,
  //   serverBaseUrl: 'https://api.yourservice.com',
  // );

  runApp(MyApp());
}
```

### 기본 연결

#### 방식 1: 원스텝 연결 (기본값)
연결과 서명 인증을 한 번에 처리합니다:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perpdex/wallet/wallet.dart';

// MetaMask 연결 (자동으로 서명 요청)
await ref.read(ethereumWalletProvider.notifier).connectMetaMask();

// Phantom 연결
await ref.read(ethereumWalletProvider.notifier).connectPhantom();

// Coinbase Wallet 연결
await ref.read(ethereumWalletProvider.notifier).connectCoinbase();

// Trust Wallet 연결
await ref.read(ethereumWalletProvider.notifier).connectTrustWallet();
```

#### 방식 2: 투스텝 연결 (Aster DEX 스타일)
연결과 서명 인증을 분리하여 사용자에게 명확하게 안내합니다:

```dart
// 1단계: 지갑 연결 (주소만 획득)
await ref.read(ethereumWalletProvider.notifier).connectMetaMask(
  autoAuthenticate: false,
);

// 연결 완료 확인
final walletState = ref.read(ethereumWalletProvider);
if (walletState.isWalletConnected) {
  print('지갑 연결 완료: ${walletState.address}');

  // 사용자에게 안내 메시지 표시
  // "서명은 소유권 확인 및 지갑 호환성 확인에 사용됩니다."

  // 2단계: 서명 인증 (소유권 확인)
  await ref.read(ethereumWalletProvider.notifier).authenticate();

  // 완전한 연결 확인
  if (ref.read(ethereumWalletProvider).isConnected) {
    print('서명 인증 완료!');
  }
}
```

**서명 메시지 예시**:
```
You are signing into DEX Trading Platform 357193
```

이 메시지는 Aster DEX와 동일한 스타일로, 간단하고 명확합니다.

### 지갑 상태 확인

```dart
final walletState = ref.watch(ethereumWalletProvider);

// 1단계 완료 확인 (지갑 연결됨, 주소 획득)
if (walletState.isWalletConnected) {
  print('지갑 주소: ${walletState.address}');
  print('체인 ID: ${walletState.chainId}');
  print('지갑 타입: ${walletState.walletType}');
}

// 2단계 완료 확인 (서명 인증까지 완료)
if (walletState.isConnected) {
  print('✅ 완전히 연결 및 인증 완료');
  print('잔액: ${walletState.balance}');
}

// 진행 상태 확인
if (walletState.isConnecting) {
  print('지갑 연결 중...');
}

if (walletState.isAuthenticating) {
  print('서명 인증 중...');
}
```

### 체인 전환

```dart
await ref.read(ethereumWalletProvider.notifier).switchChain('0x1'); // Ethereum
await ref.read(ethereumWalletProvider.notifier).switchChain('0x38'); // BSC
await ref.read(ethereumWalletProvider.notifier).switchChain('0xa4b1'); // Arbitrum
```

### 서명 및 트랜잭션

```dart
// 메시지 서명 (자동으로 nonce 인증)
final walletNotifier = ref.read(ethereumWalletProvider.notifier);
// 연결 시 자동으로 서명 인증이 수행됩니다

// 트랜잭션 전송 (직접 wallet 인스턴스 사용 필요)
final tx = await wallet.sendTransaction(
  to: '0x...',
  value: BigInt.from(1000000000000000000), // 1 ETH
);
```

### 연결 해제

```dart
await ref.read(ethereumWalletProvider.notifier).disconnect();
```

## 폴더 구조

```
lib/wallet/
├── wallet.dart              # Main export file
├── README.md               # 이 파일
│
├── core/                   # 핵심 인터페이스
│   └── ethereum_wallet.dart    # 지갑 추상 클래스
│
├── services/               # 공통 서비스
│   ├── auth_nonce_service.dart # Nonce 생성 및 관리
│   └── signature_verifier.dart  # 서명 검증
│
├── wallets/                # 지갑 구현체
│   ├── metamask_wallet.dart    # MetaMask (Web)
│   ├── metamask_mobile.dart    # MetaMask (Mobile)
│   ├── phantom_ethereum_wallet.dart  # Phantom (Web)
│   ├── phantom_mobile.dart     # Phantom (Mobile)
│   ├── coinbase_wallet.dart    # Coinbase (Web)
│   ├── coinbase_mobile.dart    # Coinbase (Mobile)
│   ├── trust_wallet.dart       # Trust Wallet (Web)
│   └── trust_mobile.dart       # Trust Wallet (Mobile)
│
└── providers/              # 상태 관리
    └── ethereum_wallet_provider.dart  # Riverpod provider
```

## 아키텍처

### 1. 추상화 계층 (core/)
`EthereumWallet` 추상 클래스가 모든 지갑의 공통 인터페이스를 정의합니다.

### 2. 서비스 계층 (services/)
- `AuthNonceService`: Nonce 생성, 저장, 검증
- `SignatureVerifier`: 서명 검증 (백엔드 연동 준비)

### 3. 구현 계층 (wallets/)
각 지갑의 Web/Mobile 구현체가 `EthereumWallet`을 상속받아 구현합니다.

### 4. 상태 관리 계층 (providers/)
Riverpod을 사용하여 전역 상태를 관리합니다.

## 보안

SDK는 두 가지 인증 모드를 지원합니다:

### 모드 비교

| 특징 | 클라이언트 모드 | 서버 모드 |
|------|----------------|-----------|
| **용도** | 개발/프로토타입 | 프로덕션 |
| **Nonce 생성** | 클라이언트 (UUID) | 서버 (DB 저장) |
| **서명 검증** | 로컬 (SessionStorage) | 서버 (ecrecover) |
| **재사용 방지** | 세션 내에서만 | 모든 디바이스/탭 |
| **만료 시간** | 없음 | 설정 가능 (예: 5분) |
| **JWT 토큰** | 없음 | 발급됨 |
| **서버 필요** | ❌ | ✅ |
| **보안 수준** | ⚠️ 낮음 | ✅ 높음 |

### 모드 1: 클라이언트 모드 (개발/프로토타입)

서버 없이 빠르게 개발할 수 있습니다:

```dart
AuthService.configure(mode: AuthMode.client);
```

**동작 방식**:
1. 클라이언트가 UUID nonce 생성
2. Nonce를 포함한 메시지 서명 요청
3. SessionStorage에 사용된 nonce 저장
4. 재사용 공격 방지 (세션 내에서만)

**⚠️ 주의**: 클라이언트 측 nonce는 보안상 완전하지 않습니다. 개발 단계에서만 사용하세요.

### 모드 2: 서버 모드 (프로덕션 권장)

백엔드 API를 통한 완전한 보안 인증:

```dart
AuthService.configure(
  mode: AuthMode.server,
  serverBaseUrl: 'https://api.yourservice.com',
);
```

**동작 방식**:
1. 서버에서 nonce 생성 및 DB 저장
2. 클라이언트가 nonce를 받아 서명
3. 서버에서 ecrecover로 서명 검증
4. Nonce를 사용됨으로 표시 (재사용 방지)
5. JWT 토큰 발급

**SDK가 자동으로 처리합니다** - 위 설정만 하면 지갑 연결 시 자동으로 서버 API를 호출합니다!

#### 서버 측 구현 예시 (Node.js)
```javascript
// POST /auth/nonce
app.get('/auth/nonce', async (req, res) => {
  const { address } = req.query;
  const nonce = uuid.v4();
  const expiresAt = Date.now() + 5 * 60 * 1000; // 5분

  // DB에 저장
  await db.nonces.insert({
    nonce,
    address: address.toLowerCase(),
    expiresAt,
    used: false,
  });

  const message = `Welcome to DEX Trading Platform!\n\n` +
    `Please sign this message to verify your wallet ownership.\n\n` +
    `Wallet Address: ${address}\n` +
    `Nonce: ${nonce}\n` +
    `Timestamp: ${new Date().toISOString()}\n\n` +
    `This request will not trigger a blockchain transaction or cost any gas fees.`;

  res.json({ nonce, message, expiresAt });
});

// POST /auth/verify
app.post('/auth/verify', async (req, res) => {
  const { address, signature, nonce } = req.body;

  // 1. DB에서 nonce 조회
  const nonceRecord = await db.nonces.findOne({ nonce });
  if (!nonceRecord) {
    return res.status(401).json({ error: 'Invalid nonce' });
  }

  // 2. 만료 확인
  if (Date.now() > nonceRecord.expiresAt) {
    return res.status(401).json({ error: 'Nonce expired' });
  }

  // 3. 이미 사용된 nonce인지 확인
  if (nonceRecord.used) {
    return res.status(401).json({ error: 'Nonce already used' });
  }

  // 4. 서명 검증 (ethers.js 사용)
  const message = createMessage(address, nonce, nonceRecord.createdAt);
  const recoveredAddress = ethers.verifyMessage(message, signature);

  if (recoveredAddress.toLowerCase() !== address.toLowerCase()) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  // 5. Nonce를 사용됨으로 표시
  await db.nonces.update({ nonce }, { used: true, usedAt: Date.now() });

  // 6. JWT 토큰 발급
  const token = jwt.sign(
    { address: address.toLowerCase() },
    process.env.JWT_SECRET,
    { expiresIn: '1h' }
  );

  res.json({ token, expiresIn: 3600 });
});
```

#### 보안 이점
1. **서버가 nonce 제어** - 클라이언트가 nonce를 조작할 수 없음
2. **DB 기반 재사용 방지** - SessionStorage 한계 극복, 모든 탭/디바이스에서 방지
3. **만료 시간 관리** - 오래된 nonce 자동 무효화
4. **서명 위조 불가** - 서버에서 ecrecover로 검증
5. **JWT 기반 인증** - 이후 API 요청에 안전한 토큰 사용

## 확장하기

### 새로운 지갑 추가

1. `wallets/` 폴더에 새 지갑 클래스 생성
2. `EthereumWallet` 추상 클래스 상속
3. 필수 메서드 구현
4. `providers/ethereum_wallet_provider.dart`에 연결 메서드 추가
5. `wallet.dart`에 export 추가

예시:
```dart
class MyWallet extends EthereumWallet {
  @override
  Future<String?> connect() async {
    // 구현
  }

  @override
  Future<String> signMessage(String message) async {
    // 구현
  }

  // ... 기타 메서드
}
```

## 라이선스

이 SDK는 프로젝트 내부에서 자유롭게 사용할 수 있습니다.

## 기여

새로운 지갑 추가나 개선사항이 있다면 언제든지 제안해주세요!
