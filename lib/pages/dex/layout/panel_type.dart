/// DEX 거래 화면의 패널 타입 정의
enum PanelType {
  chart, // K-line 차트
  orderbook, // 호가창
  orderPanel, // 주문 패널
  accountInfo, // 계정 정보
  trades, // 최근 체결
  positions, // 포지션
  orders, // 주문 내역
  history, // 거래 내역
  funds, // 입출금
}

/// 패널 데이터 모델
class PanelData {
  final String id;
  final PanelType type;
  final String title;
  int gridX;
  int gridY;
  int gridWidth;
  int gridHeight;
  bool isVisible;

  // 인접 패널 관계 (크기 조정 시 사용)
  String? rightPanelId; // 오른쪽 패널 ID
  String? bottomPanelId; // 아래 패널 ID

  PanelData({
    required this.id,
    required this.type,
    required this.title,
    this.gridX = 0,
    this.gridY = 0,
    this.gridWidth = 1,
    this.gridHeight = 1,
    this.isVisible = true,
    this.rightPanelId,
    this.bottomPanelId,
  });

  PanelData copyWith({
    String? id,
    PanelType? type,
    String? title,
    int? gridX,
    int? gridY,
    int? gridWidth,
    int? gridHeight,
    bool? isVisible,
    String? rightPanelId,
    String? bottomPanelId,
  }) {
    return PanelData(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      isVisible: isVisible ?? this.isVisible,
      rightPanelId: rightPanelId ?? this.rightPanelId,
      bottomPanelId: bottomPanelId ?? this.bottomPanelId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'gridX': gridX,
      'gridY': gridY,
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'isVisible': isVisible,
    };
  }

  factory PanelData.fromJson(Map<String, dynamic> json) {
    return PanelData(
      id: json['id'],
      type: PanelType.values.firstWhere((e) => e.name == json['type']),
      title: json['title'],
      gridX: json['gridX'] ?? 0,
      gridY: json['gridY'] ?? 0,
      gridWidth: json['gridWidth'] ?? 1,
      gridHeight: json['gridHeight'] ?? 1,
      isVisible: json['isVisible'] ?? true,
    );
  }
}

/// 기본 레이아웃 프리셋 (100x100 퍼센트 기준)
class DefaultLayouts {
  /// 표준 레이아웃
  static List<PanelData> get standard => [
        PanelData(
          id: 'chart',
          type: PanelType.chart,
          title: '차트',
          gridX: 0,
          gridY: 0,
          gridWidth: 60, // 60%
          gridHeight: 50,
        ),
        PanelData(
          id: 'orderbook',
          type: PanelType.orderbook,
          title: '호가창',
          gridX: 60,
          gridY: 0,
          gridWidth: 20, // 20%
          gridHeight: 50,
        ),
        PanelData(
          id: 'order',
          type: PanelType.orderPanel,
          title: '주문',
          gridX: 80,
          gridY: 0,
          gridWidth: 20, // 20%
          gridHeight: 50,
        ),
        PanelData(
          id: 'accountInfo',
          type: PanelType.accountInfo,
          title: '계정',
          gridX: 80,
          gridY: 50,
          gridWidth: 20,
          gridHeight: 40,
        ),
        PanelData(
          id: 'positions',
          type: PanelType.positions,
          title: '포지션',
          gridX: 0,
          gridY: 50,
          gridWidth: 80, // 차트와 호가창 너비만큼
          gridHeight: 40,
        ),
      ];

  /// 차트 중심 레이아웃
  static List<PanelData> get chartFocused => [
        PanelData(
          id: 'chart',
          type: PanelType.chart,
          title: '차트',
          gridX: 0,
          gridY: 0,
          gridWidth: 80, // 80%
          gridHeight: 70,
        ),
        PanelData(
          id: 'orderbook',
          type: PanelType.orderbook,
          title: '호가창',
          gridX: 80,
          gridY: 0,
          gridWidth: 20,
          gridHeight: 35,
        ),
        PanelData(
          id: 'order',
          type: PanelType.orderPanel,
          title: '주문',
          gridX: 80,
          gridY: 35,
          gridWidth: 20,
          gridHeight: 35,
        ),
        PanelData(
          id: 'positions',
          type: PanelType.positions,
          title: '포지션',
          gridX: 0,
          gridY: 70,
          gridWidth: 100,
          gridHeight: 30,
        ),
      ];

  /// 트레이딩 중심 레이아웃
  static List<PanelData> get tradingFocused => [
        PanelData(
          id: 'chart',
          type: PanelType.chart,
          title: '차트',
          gridX: 0,
          gridY: 0,
          gridWidth: 40, // 40%
          gridHeight: 70,
        ),
        PanelData(
          id: 'orderbook',
          type: PanelType.orderbook,
          title: '호가창',
          gridX: 40,
          gridY: 0,
          gridWidth: 20,
          gridHeight: 70,
        ),
        PanelData(
          id: 'order',
          type: PanelType.orderPanel,
          title: '주문',
          gridX: 60,
          gridY: 0,
          gridWidth: 40,
          gridHeight: 35,
        ),
        PanelData(
          id: 'trades',
          type: PanelType.trades,
          title: '최근 체결',
          gridX: 60,
          gridY: 35,
          gridWidth: 40,
          gridHeight: 35,
        ),
        PanelData(
          id: 'positions',
          type: PanelType.positions,
          title: '포지션',
          gridX: 0,
          gridY: 70,
          gridWidth: 100,
          gridHeight: 30,
        ),
      ];
}
