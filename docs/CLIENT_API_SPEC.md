# PerpDEX Client API Specification

## 개요

PerpDEX 서버와 클라이언트 간 통신을 위한 API 스펙 문서입니다.

## 서버 설정

| 항목 | 기본값 | 설명 |
|------|--------|------|
| HTTP/REST API 포트 | 3000 | `serverconfig.PORT` |
| WebSocket 포트 | 8080 | `serverconfig.WSPORT` |
| HTTPS | 비활성화 | `serverconfig.HTTPS` |

---

# REST API Endpoints

## 1. 인증 (Authentication)

### Base Path: `/api/auth`

모든 인증 API는 지갑 기반 인증을 사용합니다.

#### 1.1 Nonce 발급
```
POST /api/auth/nonce
```

**Request Body:**
```json
{
  "namespace": "evm" | "solana",
  "address": "0x1234..." | "ABC123..."
}
```

**Response:**
```json
{
  "result": 0,
  "data": {
    "nonce": "1234567890123456",
    "message": "Sign this message to verify your wallet: 1234567890123456",
    "expiresAt": "2024-01-01T00:05:00.000Z"
  }
}
```

#### 1.2 서명 검증 및 로그인
```
POST /api/auth/verify
```

**Request Body:**
```json
{
  "namespace": "evm" | "solana",
  "address": "0x1234...",
  "signature": "0xabc...",
  "nonce": "1234567890123456",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "chainId": "1",
  "chainName": "ethereum"
}
```

**Response:**
```json
{
  "result": 0,
  "data": {
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG...",
    "userId": 1,
    "userkey": "user_abc123",
    "namespace": "evm",
    "accountType": "wallet_eoa",
    "isNewUser": false
  }
}
```

#### 1.3 기존 로그인 (ID/Password)
```
POST /api/auth/login
```

**Request Body:**
```json
{
  "clientId": "client-uuid",
  "deviceId": "device-uuid",
  "memberId": "username",
  "passwd": "password"
}
```

#### 1.4 로그아웃
```
POST /api/auth/logout
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG..."
}
```

#### 1.5 세션 목록 조회
```
GET /api/auth/sessions
```

#### 1.6 모든 기기 로그아웃
```
DELETE /api/auth/sessions
```

#### 1.7 특정 기기 로그아웃
```
DELETE /api/auth/sessions/:deviceId
```

---

## 2. 선물 거래 (Futures)

### Base Path: `/api/futures`

> **인증 필요 API**: 주문, 포지션, 잔고, 개인 통계 등
> - Request Body에 `accesstoken` 필드 포함 (소문자!)
>
> **Public API (인증 불필요)**: 오더북, 체결내역, 심볼정보, Mark Price, Funding Rate, K-Line 등

---

### Public API (인증 불필요)

#### 심볼 목록 조회

```http
GET /api/futures/symbols
```

**Response:**

```json
{
  "success": true,
  "symbols": [
    {
      "symbol": "BTCUSDT",
      "baseAsset": "BTC",
      "quoteAsset": "USDT",
      "pricePrecision": 2,
      "quantityPrecision": 3,
      "minQuantity": "0.001",
      "maxQuantity": "1000",
      "tickSize": "0.01",
      "minNotional": "5",
      "maxLeverage": 100,
      "maintenanceMarginRate": "0.005",
      "makerFeeRate": "0.0002",
      "takerFeeRate": "0.0005",
      "status": "ACTIVE"
    }
  ]
}
```

#### 개별 심볼 정보 조회

```http
GET /api/futures/symbols/:symbol
```

#### 서버 시간 조회

```http
GET /api/futures/time
```

**Response:**

```json
{
  "success": true,
  "serverTime": 1704067200000
}
```

#### Mark Price 조회

```http
GET /api/futures/markPrice/:symbol
```

**Response:**

```json
{
  "success": true,
  "symbol": "BTCUSDT",
  "markPrice": "50500.00000000",
  "indexPrice": "50480.00000000",
  "timestamp": 1704067200000
}
```

#### 모든 심볼 Mark Price 조회

```http
GET /api/futures/markPrices
```

#### Funding Rate 조회

```http
GET /api/futures/fundingRate/:symbol
```

**Response:**

```json
{
  "success": true,
  "symbol": "BTCUSDT",
  "fundingRate": "0.0001",
  "nextFundingTime": 1704096000000,
  "timestamp": 1704067200000
}
```

#### 모든 심볼 Funding Rate 조회

```http
GET /api/futures/fundingRates
```

#### 24시간 통계

```http
GET /api/futures/ticker24h/:symbol
```

**Response:**

```json
{
  "success": true,
  "symbol": "BTCUSDT",
  "open": "50000.0",
  "high": "52000.0",
  "low": "49000.0",
  "close": "51000.0",
  "volume": "12345.67",
  "change": "1000.0",
  "changePercent": "2.0",
  "timestamp": 1704067200000
}
```

#### 오더북 조회

```http
GET /api/futures/orderbook/:symbol?depth=20
```

**Response:**

```json
{
  "result": 0,
  "orderbook": {
    "symbol": "BTCUSDT",
    "bids": [
      { "price": "50000.00", "quantity": "1.5", "orderCount": 3 }
    ],
    "asks": [
      { "price": "50100.00", "quantity": "2.0", "orderCount": 2 }
    ],
    "timestamp": 1704067200000
  }
}
```

#### 최근 체결 내역

```http
GET /api/futures/trades/:symbol?limit=50
```

#### Insurance Fund 조회

```http
GET /api/futures/insurance-fund
GET /api/futures/insurance-fund/:symbol
GET /api/futures/insurance-fund/:symbol/details
GET /api/futures/insurance-fund-stats
```

#### Socialized Loss 조회

```http
GET /api/futures/socialized-losses
GET /api/futures/socialized-losses/:symbol
GET /api/futures/socialized-loss-distribution/:lossId
```

#### ADL 이력 조회

```http
GET /api/futures/adl-history?symbol=BTCUSDT&limit=50
```

#### Exchange Reserve 통계

```http
GET /api/futures/exchange-reserve-stats
GET /api/futures/exchange-reserve-history
```

#### VIP 등급 조회

```http
GET /api/futures/vip/tiers
```

---

### Private API (인증 필요)

#### 2.1 잔고 조회
```
GET /api/futures/balance
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid"
}
```

**Response:**
```json
{
  "result": 0,
  "totalBalance": "10000.00000000",
  "availableBalance": "8000.00000000",
  "lockedBalance": "2000.00000000"
}
```

#### 2.2 주문 생성
```
POST /api/futures/orders
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "symbol": "BTCUSDT",
  "side": "BUY" | "SELL",
  "type": "LIMIT" | "MARKET" | "POST_ONLY",
  "quantity": "0.1",
  "price": "50000.00",
  "leverage": 10,
  "marginMode": "ISOLATED" | "CROSS",
  "timeInForce": "GTC" | "IOC" | "FOK" | "POST_ONLY",
  "reduceOnly": false,
  "positionSide": "LONG" | "SHORT",
  "hidden": false,
  "isIceberg": false,
  "visibleQuantity": "0.01",
  "takeProfit": {
    "price": "55000.00",
    "triggerType": "MARK_PRICE" | "LAST_PRICE"
  },
  "stopLoss": {
    "price": "45000.00",
    "triggerType": "MARK_PRICE" | "LAST_PRICE"
  }
}
```

**Response:**
```json
{
  "result": 0,
  "orderId": 12345,
  "status": "NEW" | "PARTIALLY_FILLED" | "FILLED" | "REJECTED",
  "message": "Order created",
  "tpslOrders": [12346, 12347]
}
```

**주문 타입:**
| Type | 설명 |
|------|------|
| `LIMIT` | 지정가 주문 |
| `MARKET` | 시장가 주문 |
| `POST_ONLY` | Maker 전용 (Taker 시 취소) |
| `TRAILING_STOP` | 트레일링 스탑 |

**Time In Force:**
| TIF | 설명 |
|-----|------|
| `GTC` | Good Till Cancel |
| `IOC` | Immediate or Cancel |
| `FOK` | Fill or Kill |
| `POST_ONLY` | Maker 전용 |

#### 2.3 주문 취소
```
DELETE /api/futures/orders/:orderId
```

**Response:**
```json
{
  "result": 0,
  "orderId": 12345,
  "status": "CANCELLED",
  "message": "Order cancelled"
}
```

#### 2.4 주문 목록 조회
```
GET /api/futures/orders?symbol=BTCUSDT&status=OPEN
```

**Response:**
```json
{
  "result": 0,
  "orders": [
    {
      "id": 12345,
      "symbol": "BTCUSDT",
      "side": "BUY",
      "type": "LIMIT",
      "quantity": "0.10000000",
      "price": "50000.00000000",
      "filledQuantity": "0.05000000",
      "status": "PARTIALLY_FILLED",
      "leverage": 10,
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

#### 2.5 개별 주문 조회
```
GET /api/futures/orders/:orderId
```

#### 2.6 포지션 조회
```
GET /api/futures/positions?symbol=BTCUSDT
```

**Response:**
```json
{
  "result": 0,
  "positions": [
    {
      "id": 1,
      "symbol": "BTCUSDT",
      "side": "LONG",
      "quantity": "0.10000000",
      "entryPrice": "50000.00000000",
      "leverage": 10,
      "margin": "500.00000000",
      "liquidationPrice": "45000.00000000",
      "unrealizedPnl": "100.00000000",
      "realizedPnl": "0.00000000",
      "markPrice": "51000.00000000",
      "marginRatio": "0.15",
      "isAtRisk": false
    }
  ]
}
```

#### 2.7 포지션 청산 (시장가)
```
POST /api/futures/positions/:positionId/close
```

#### 2.8 오더북 조회 (Public)
```
GET /api/futures/orderbook/:symbol?depth=20
```

**Response:**
```json
{
  "result": 0,
  "orderbook": {
    "symbol": "BTCUSDT",
    "bids": [
      { "price": "50000.00", "quantity": "1.5", "orderCount": 3 }
    ],
    "asks": [
      { "price": "50100.00", "quantity": "2.0", "orderCount": 2 }
    ],
    "timestamp": 1704067200000
  }
}
```

#### 2.9 최근 체결 내역 (Public)
```
GET /api/futures/trades/:symbol?limit=50
```

#### 2.10 조건부 주문 생성
```
POST /api/futures/conditional-orders
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "symbol": "BTCUSDT",
  "orderType": "STOP_MARKET" | "STOP_LIMIT" | "TAKE_PROFIT" | "STOP_LOSS" | "TRAILING_STOP",
  "side": "BUY" | "SELL",
  "quantity": "0.1",
  "triggerPrice": "48000.00",
  "orderPrice": "47900.00",
  "triggerType": "MARK_PRICE" | "LAST_PRICE",
  "leverage": 10,
  "reduceOnly": true,
  "callbackRate": "1.0",
  "activationPrice": "50000.00"
}
```

#### 2.11 조건부 주문 조회
```
GET /api/futures/conditional-orders?symbol=BTCUSDT
```

#### 2.12 조건부 주문 취소
```
DELETE /api/futures/conditional-orders/:orderId
```

#### 2.13 거래 통계
```
GET /api/futures/stats
```

#### 2.14 Insurance Fund 조회 (Public)
```
GET /api/futures/insurance-fund
GET /api/futures/insurance-fund/:symbol
GET /api/futures/insurance-fund/:symbol/details
GET /api/futures/insurance-fund-stats
```

#### 2.15 Socialized Loss 조회 (Public)
```
GET /api/futures/socialized-losses
GET /api/futures/socialized-losses/:symbol
GET /api/futures/socialized-loss-distribution/:lossId
```

#### 2.16 내 Socialized Loss 이력
```
GET /api/futures/my-socialized-loss-distributions
```

#### 2.17 ADL 이력 조회
```
GET /api/futures/adl-history?symbol=BTCUSDT&limit=50
GET /api/futures/my-adl-impact
```

#### 2.18 Exchange Reserve 통계 (Public)
```
GET /api/futures/exchange-reserve-stats
GET /api/futures/exchange-reserve-history
```

#### 2.19 VIP 시스템
```
GET /api/futures/vip/status
GET /api/futures/vip/tiers
GET /api/futures/vip/volume-history?days=14
```

---

## 3. 현물 거래 (Spot)

### Base Path: `/api/spot`

#### 3.1 주문 생성
```
POST /api/spot/order
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "symbol": "BTCUSDT",
  "side": "BUY" | "SELL",
  "orderType": "LIMIT" | "MARKET",
  "price": "50000.00",
  "quantity": "0.1",
  "timeInForce": "GTC"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "12345",
    "status": "NEW",
    "matched": true,
    "filledQuantity": "0.05000000",
    "averagePrice": "50000.00000000",
    "trades": 1
  }
}
```

#### 3.2 주문 취소
```
DELETE /api/spot/order/:orderId
```

#### 3.3 주문 목록 조회
```
GET /api/spot/orders?symbol=BTCUSDT&status=OPEN
```

#### 3.4 개별 주문 조회
```
GET /api/spot/order/:orderId
```

#### 3.5 오더북 조회 (Public)
```
GET /api/spot/orderbook/:symbol?depth=20
```

#### 3.6 Best Bid/Ask 조회 (Public)
```
GET /api/spot/ticker/:symbol
```

**Response:**
```json
{
  "success": true,
  "data": {
    "symbol": "BTCUSDT",
    "bestBid": "49990.00000000",
    "bestAsk": "50010.00000000",
    "spread": "20.00000000"
  }
}
```

#### 3.7 잔고 조회
```
GET /api/spot/balance
GET /api/spot/balance/:asset
```

---

## 4. K-Line (캔들스틱)

### Base Path: `/api/klines`

#### 4.1 K-Line 조회 (TradingView 형식)
```
GET /api/klines?symbol=BTCUSDT&interval=1h&from=1704067200&to=1704153600&limit=500
```

**Intervals:** `1m`, `5m`, `15m`, `1h`, `4h`, `1D`

**Response:**
```json
{
  "result": 0,
  "symbol": "BTCUSDT",
  "interval": "1h",
  "klines": [
    {
      "time": 1704067200,
      "open": 50000.0,
      "high": 51000.0,
      "low": 49500.0,
      "close": 50500.0,
      "volume": 1234.5
    }
  ]
}
```

#### 4.2 K-Line 조회 (Binance 형식)
```
GET /api/klines/binance?symbol=BTCUSDT&interval=1m&startTime=1704067200000&endTime=1704153600000&limit=500
```

**Response:** (Binance 배열 형식)
```json
[
  [1704067200000, "50000.0", "51000.0", "49500.0", "50500.0", "1234.5", 1704070800000, "61725000.0", 500, "0", "0", "0"]
]
```

#### 4.3 최신 K-Line 조회
```
GET /api/klines/latest?symbol=BTCUSDT&interval=1h
```

#### 4.4 현재 진행 중인 K-Line
```
GET /api/klines/current?symbol=BTCUSDT&interval=1h
```

#### 4.5 24시간 변동률
```
GET /api/klines/24h?symbol=BTCUSDT
```

**Response:**
```json
{
  "result": 0,
  "symbol": "BTCUSDT",
  "data": {
    "open": 50000.0,
    "close": 51000.0,
    "change": 1000.0,
    "changePercent": 2.0,
    "high": 52000.0,
    "low": 49000.0,
    "volume": 12345.6
  }
}
```

#### 4.6 K-Line 통계
```
GET /api/klines/stats?symbol=BTCUSDT&interval=1h&from=1704067200&to=1704153600
```

---

## 5. Grid Trading Bot

### Base Path: `/api/futures/grid-orders`

그리드 트레이딩 봇 API입니다. 지정된 가격 범위 내에서 자동으로 매매 주문을 생성하고 관리합니다.

#### 전략 (Strategy)
| 전략 | 설명 |
|------|------|
| `LONG` | 롱 포지션 기반 그리드 (하락 시 매수, 상승 시 매도) |
| `SHORT` | 숏 포지션 기반 그리드 (상승 시 매도, 하락 시 매수) |
| `NEUTRAL` | 중립 그리드 (양방향 거래) |

#### 봇 상태 (Status)
| 상태 | 설명 |
|------|------|
| `PENDING` | 트리거 대기 중 |
| `RUNNING` | 실행 중 |
| `STOPPED` | 정지 조건 충족으로 중지 |
| `TERMINATED` | 사용자에 의해 종료 |

---

#### 5.1 Grid 봇 생성
```
POST /api/futures/grid-orders
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "symbol": "BTCUSDT",
  "strategy": "LONG",
  "lowerPrice": "40000",
  "upperPrice": "50000",
  "gridCount": 10,
  "initialMargin": "1000",
  "leverage": 5,
  "triggerPrice": "45000",
  "stopLossPrice": "100",
  "stopPriceTop": "55000",
  "stopPriceBottom": "35000",
  "cancelAllOnStop": true,
  "closeAllOnStop": false
}
```

**Parameters:**
| 파라미터 | 필수 | 타입 | 설명 |
|----------|------|------|------|
| `symbol` | O | string | 거래쌍 (예: BTCUSDT) |
| `strategy` | O | string | 전략: `LONG`, `SHORT`, `NEUTRAL` |
| `lowerPrice` | O | string | 그리드 하한 가격 |
| `upperPrice` | O | string | 그리드 상한 가격 |
| `gridCount` | O | number | 그리드 개수 (2~100) |
| `initialMargin` | O | string | 초기 증거금 (USDT) |
| `leverage` | O | number | 레버리지 |
| `triggerPrice` | X | string | 트리거 가격 (도달 시 봇 시작) |
| `stopLossPrice` | X | string | 손절 금액 (USDT, PnL 기준) |
| `stopPriceTop` | X | string | 가격 상한 도달 시 정지 |
| `stopPriceBottom` | X | string | 가격 하한 도달 시 정지 |
| `cancelAllOnStop` | X | boolean | 정지 시 미체결 주문 취소 (기본: true) |
| `closeAllOnStop` | X | boolean | 정지 시 포지션 청산 (기본: false) |

**Response:**
```json
{
  "result": 0,
  "gridBotId": 12345
}
```

#### 5.2 Grid 봇 목록 조회
```
GET /api/futures/grid-orders?symbol=BTCUSDT
```

**Query Parameters:**
| 파라미터 | 필수 | 설명 |
|----------|------|------|
| `symbol` | X | 필터링할 심볼 |

**Response:**
```json
{
  "result": 0,
  "gridBots": [
    {
      "gridBotId": 12345,
      "symbol": "BTCUSDT",
      "strategy": "LONG",
      "lowerPrice": "40000.00000000",
      "upperPrice": "50000.00000000",
      "gridCount": 10,
      "initialMargin": "1000.00000000",
      "leverage": 5,
      "status": "RUNNING",
      "totalProfit": "123.45678900",
      "matchedOrders": 15,
      "createdAt": "2024-01-01T00:00:00.000Z",
      "startedAt": "2024-01-01T00:01:00.000Z",
      "stoppedAt": null
    }
  ]
}
```

#### 5.3 Grid 봇 상세/통계 조회
```
GET /api/futures/grid-orders/:gridBotId
```

**Response:**
```json
{
  "result": 0,
  "gridBotId": 12345,
  "symbol": "BTCUSDT",
  "strategy": "LONG",
  "status": "RUNNING",
  "lowerPrice": "40000.00000000",
  "upperPrice": "50000.00000000",
  "gridCount": 10,
  "initialMargin": "1000.00000000",
  "leverage": 5,
  "totalProfit": "123.45678900",
  "realizedPnl": "100.00000000",
  "unrealizedPnl": "23.45678900",
  "matchedOrders": 15,
  "pendingOrders": 8,
  "currentPosition": {
    "side": "LONG",
    "quantity": "0.05",
    "entryPrice": "42500.00"
  },
  "createdAt": "2024-01-01T00:00:00.000Z",
  "startedAt": "2024-01-01T00:01:00.000Z"
}
```

#### 5.4 Grid 봇 종료
```
DELETE /api/futures/grid-orders/:gridBotId
```

**Response:**
```json
{
  "result": 0,
  "message": "grid_bot_terminated"
}
```

#### Grid Bot 에러 코드

| result | 에러 | 설명 |
|--------|------|------|
| 101 | `invalid_params` | 필수 파라미터 누락 |
| 101 | `invalid_grid_bot_id` | 유효하지 않은 봇 ID |
| 102 | `invalid_strategy` | 유효하지 않은 전략 |
| 102 | `grid_bot_not_found` | 봇을 찾을 수 없음 |
| 103 | `lower_price_must_be_less_than_upper_price` | 가격 범위 오류 |
| 103 | `unauthorized` | 권한 없음 (다른 사용자의 봇) |
| 104 | `grid_count_must_be_between_2_and_100` | 그리드 개수 범위 초과 |
| 99 | 기타 | 서버 오류 |

---

## 6. 2FA (Two-Factor Authentication)

### Base Path: `/api/2fa`

> **상세 문서**: [2FA_GUIDE.md](./2FA_GUIDE.md)

TOTP 기반 2FA를 지원합니다. Google Authenticator, Microsoft Authenticator 등과 호환됩니다.

#### 2FA 모드
| 모드 | 설명 | 사용자 변경 |
|------|------|------------|
| `normal` | 고액 인출(≥1,000 USDT)에만 2FA 필수 | O |
| `always` | 모든 인출에 2FA 필수 | O |
| `admin_enforced` | 관리자 강제 모드 | X |

---

#### 5.1 2FA 설정 시작 (QR 코드 생성)
```
POST /api/2fa/setup
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "qrCodeDataUrl": "data:image/png;base64,...",
    "secret": "ABCDEFGHIJKLMNOP",
    "backupCodes": ["A1B2C3D4", "E5F6G7H8", ...]
  },
  "message": "Scan the QR code with Google Authenticator or Authy"
}
```

#### 5.2 2FA 활성화
```
POST /api/2fa/enable
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "totpCode": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA enabled successfully"
}
```

#### 5.3 2FA 상태 조회
```
POST /api/2fa/status
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "enabled": true,
    "mode": "normal"
  }
}
```

#### 5.4 2FA 코드 검증
```
POST /api/2fa/verify
```

인출, 고액 거래 등 중요 작업 전 2FA 검증에 사용됩니다.

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "totpCode": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA verification successful"
}
```

> **참고**: TOTP 코드 (6자리) 또는 백업 코드 (8자리 HEX) 모두 사용 가능. 백업 코드 사용 시 해당 코드는 자동 삭제됨.

#### 5.5 2FA 비활성화
```
POST /api/2fa/disable
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "totpCode": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "message": "2FA disabled successfully"
}
```

#### 5.6 백업 코드 재생성
```
POST /api/2fa/regenerate-backup-codes
```

기존 백업 코드를 모두 무효화하고 새로운 10개의 백업 코드를 생성합니다.

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "totpCode": "123456"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "backupCodes": ["A1B2C3D4", "E5F6G7H8", ...]
  },
  "message": "Backup codes regenerated. Save them securely!"
}
```

> **주의**: TOTP 코드로만 검증 가능 (백업 코드 사용 불가)

#### 5.7 2FA 모드 변경
```
POST /api/2fa/set-mode
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "mode": "always",
  "totpCode": "123456"
}
```

**허용 모드:** `normal`, `always`

**Response:**
```json
{
  "success": true,
  "data": {
    "mode": "always"
  },
  "message": "2FA mode changed to always"
}
```

#### 5.8 관리자 전용: 2FA 강제 설정
```
POST /api/2fa/admin/enforce
```

**Request Body:**
```json
{
  "accesstoken": "eyJhbG...",
  "deviceId": "device-uuid",
  "clientId": "client-uuid",
  "targetUserId": 12345,
  "enforce": true
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "targetUserId": 12345,
    "mode": "admin_enforced"
  },
  "message": "2FA enforced successfully"
}
```

#### 2FA 에러 코드

| HTTP Status | 메시지 | 설명 |
|-------------|--------|------|
| 400 | `totpCode is required` | TOTP 코드 누락 |
| 400 | `Invalid TOTP code` | 잘못된 TOTP 코드 |
| 401 | `accesstoken is required` | 인증 토큰 누락 |
| 403 | `Your 2FA mode is enforced by administrator...` | 관리자 강제 모드 |
| 403 | `Please enable 2FA first before changing mode.` | 2FA 미활성화 |
| 404 | `User not found` | 사용자 없음 |

---

## 6. 헬스체크

### Base Path: `/`

```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1704067200000,
  "services": {
    "database": "ok",
    "redis": "ok",
    "timescaledb": "ok"
  }
}
```

---

# WebSocket API

## 연결

```
ws://localhost:8080?clientId={clientId}&deviceId={deviceId}&accessToken={accessToken}
```

**Parameters:**
| 파라미터 | 필수 | 설명 |
|----------|------|------|
| `clientId` | O | 고유 클라이언트 ID (UUID) |
| `deviceId` | O | 기기 ID |
| `accessToken` | X | 인증 토큰 (없으면 게스트) |

## 연결 성공 응답

```json
{
  "type": "join",
  "clientId": "client-uuid",
  "authenticated": true,
  "assets": {
    "cash": "10000.00",
    "bonus": "0.00"
  },
  "availableChannels": ["public_data", "game_stats", "market_data", "user_data"]
}
```

## 메시지 타입

### 클라이언트 → 서버

#### 1. 채널 구독
```json
{
  "type": "subscribe",
  "channel": "market_data"
}
```

**채널 목록:**
| 채널 | 권한 | 설명 |
|------|------|------|
| `public_data` | 공개 | 기본 구독 (해제 불가) |
| `game_stats` | 공개 | 게임 통계 |
| `market_data` | 공개 | 시장 데이터 |
| `user_data` | 인증 필요 | 개인 데이터 |

#### 2. 채널 구독 해제
```json
{
  "type": "unsubscribe",
  "channel": "market_data"
}
```

#### 3. 인증 (연결 후)
```json
{
  "type": "authenticate",
  "data": {
    "deviceId": "device-uuid",
    "accessToken": "eyJhbG..."
  }
}
```

#### 4. Ping
```json
{
  "type": "ping",
  "data": { "timestamp": 1704067200000 }
}
```

### 서버 → 클라이언트

#### 1. 구독 확인
```json
{
  "type": "subscribed",
  "channel": "market_data"
}
```

#### 2. Pong
```json
{
  "type": "pong",
  "message": { "timestamp": 1704067200000 }
}
```

#### 3. 오더북 업데이트
```json
{
  "type": "orderbook",
  "symbol": "BTCUSDT",
  "bids": [["50000.00", "1.5"]],
  "asks": [["50100.00", "2.0"]],
  "timestamp": 1704067200000
}
```

#### 4. 티커 업데이트
```json
{
  "type": "ticker",
  "symbol": "BTCUSDT",
  "price": "50500.00",
  "change24h": "2.5",
  "volume24h": "12345.67",
  "high24h": "52000.00",
  "low24h": "49000.00",
  "timestamp": 1704067200000
}
```

#### 5. 체결 내역
```json
{
  "type": "trade",
  "symbol": "BTCUSDT",
  "price": "50500.00",
  "quantity": "0.1",
  "side": "BUY",
  "timestamp": 1704067200000
}
```

#### 6. 포지션 업데이트 (개인)
```json
{
  "type": "position",
  "symbol": "BTCUSDT",
  "side": "LONG",
  "quantity": "0.1",
  "entryPrice": "50000.00",
  "markPrice": "50500.00",
  "unrealizedPnl": "50.00",
  "leverage": 10,
  "marginMode": "ISOLATED",
  "timestamp": 1704067200000
}
```

#### 7. 계좌 업데이트 (개인)
```json
{
  "type": "account",
  "asset": "USDT",
  "totalBalance": "10050.00",
  "availableBalance": "8050.00",
  "lockedInOrders": "2000.00",
  "lockedInPositions": "0.00",
  "unrealizedPnl": "50.00",
  "timestamp": 1704067200000
}
```

#### 8. K-Line 업데이트
```json
{
  "type": "kline",
  "symbol": "BTCUSDT",
  "interval": "1m",
  "open": "50000.00",
  "high": "50600.00",
  "low": "49900.00",
  "close": "50500.00",
  "volume": "123.45",
  "timestamp": 1704067200000
}
```

#### 9. Mark Price 업데이트
```json
{
  "type": "mark_price",
  "symbol": "BTCUSDT",
  "markPrice": "50500.00",
  "indexPrice": "50480.00",
  "timestamp": 1704067200000
}
```

#### 10. Funding Rate 업데이트
```json
{
  "type": "funding_rate",
  "symbol": "BTCUSDT",
  "fundingRate": "0.0001",
  "nextFundingTime": 1704096000000,
  "timestamp": 1704067200000
}
```

#### 11. 청산 알림 (개인)
```json
{
  "type": "liquidation",
  "symbol": "BTCUSDT",
  "side": "LONG",
  "quantity": "0.1",
  "price": "45000.00",
  "reason": "MARGIN_CALL",
  "timestamp": 1704067200000
}
```

#### 12. 청산 알림 (공개, 익명)
```json
{
  "type": "liquidation_public",
  "symbol": "BTCUSDT",
  "side": "LONG",
  "quantity": "10.5",
  "price": "45000.00",
  "timestamp": 1704067200000
}
```

#### 13. 사용자 수 브로드캐스트
```json
{
  "type": "users",
  "ccu": 150,
  "auth": 120,
  "guest": 30
}
```

#### 14. 에러
```json
{
  "type": "error",
  "message": "auth_failed",
  "data": {}
}
```

**에러 타입:**
| 에러 | 설명 |
|------|------|
| `invalid_auth_params` | 인증 파라미터 누락 |
| `auth_failed` | 인증 실패 |
| `duplicated_login` | 중복 로그인 |
| `idleexpel` | 유휴 시간 초과로 연결 종료 |

---

# 공통 사항

## 숫자 형식

모든 금액, 수량, 가격은 **문자열**로 전송됩니다.
- 내부적으로 10^8 스케일 BigInt 사용
- 소수점 8자리까지 지원
- 예: `"50000.12345678"`

## 심볼 형식

내부 키: `BTCUSDT` (슬래시 없음, 대문자)
표시용: `BTC/USDT` (슬래시 포함)

## 에러 코드

### 공통 에러
| 코드 | 설명 |
|------|------|
| 0 | 성공 |
| 1 | 일반 에러 |
| 99 | 내부 에러 |
| 101 | 필수 파라미터 누락 |

### 주문 에러
| 코드 | 설명 |
|------|------|
| 102 | 가격 필수 (LIMIT 주문) |
| 103 | Trailing Stop 파라미터 누락 |
| 104 | 레버리지 범위 초과 |
| 105 | 최소 주문 크기 미달 |
| 106 | Hedge Mode에서 positionSide 필수 |
| 107 | Reduce-Only에서 positionSide 필수 |
| 201 | 증거금 부족 |
| 400 | 취소 불가 상태 |
| 403 | 권한 없음 |
| 404 | 주문 없음 |
| 999 | 내부 에러 |

## Rate Limiting

| API | 제한 |
|-----|------|
| Nonce 발급 | 10회/분 |
| 로그인 | 5회/분 |
| 주문 생성 | 10회/초 |

---

# 클라이언트 구현 예제

## JavaScript/TypeScript

```typescript
// REST API 예제
const API_BASE = 'http://localhost:3000';

async function placeOrder(accessToken: string, order: {
  symbol: string;
  side: 'BUY' | 'SELL';
  type: 'LIMIT' | 'MARKET';
  quantity: string;
  price?: string;
  leverage: number;
}) {
  const response = await fetch(`${API_BASE}/api/futures/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      accesstoken: accessToken,
      deviceId: 'my-device',
      clientId: 'my-client',
      ...order
    })
  });
  return response.json();
}

// WebSocket 예제
const WS_URL = 'ws://localhost:8080';

function connectWebSocket(clientId: string, deviceId: string, accessToken?: string) {
  const url = new URL(WS_URL);
  url.searchParams.set('clientId', clientId);
  url.searchParams.set('deviceId', deviceId);
  if (accessToken) {
    url.searchParams.set('accessToken', accessToken);
  }

  const ws = new WebSocket(url.toString());

  ws.onopen = () => {
    console.log('Connected');
    // 시장 데이터 구독
    ws.send(JSON.stringify({ type: 'subscribe', channel: 'market_data' }));
  };

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);

    switch (data.type) {
      case 'orderbook':
        console.log('Orderbook update:', data);
        break;
      case 'ticker':
        console.log('Ticker update:', data);
        break;
      case 'position':
        console.log('Position update:', data);
        break;
      case 'account':
        console.log('Account update:', data);
        break;
    }
  };

  // Heartbeat
  setInterval(() => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'ping', data: { timestamp: Date.now() } }));
    }
  }, 30000);

  return ws;
}
```

## 지갑 인증 플로우

```typescript
import { ethers } from 'ethers';

async function walletLogin(provider: ethers.BrowserProvider) {
  const signer = await provider.getSigner();
  const address = await signer.getAddress();

  // 1. Nonce 발급
  const nonceRes = await fetch(`${API_BASE}/api/auth/nonce`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ namespace: 'evm', address })
  });
  const { data: { nonce, message } } = await nonceRes.json();

  // 2. 메시지 서명
  const signature = await signer.signMessage(message);

  // 3. 서명 검증 및 토큰 발급
  const verifyRes = await fetch(`${API_BASE}/api/auth/verify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      namespace: 'evm',
      address,
      signature,
      nonce,
      deviceId: 'browser-device',
      clientId: crypto.randomUUID()
    })
  });

  return verifyRes.json();
}
```
