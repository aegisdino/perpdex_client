// ignore_for_file: unnecessary_this
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '/data/providers.dart';

class TokenPriceApi {
  factory TokenPriceApi() {
    return _singleton;
  }

  TokenPriceApi._internal();

  static final TokenPriceApi _singleton = TokenPriceApi._internal();

  // final String upBitAccessKey = "HQSJMMAeWnZe5nvu9CQ6IsRtESVcSaZgFlvo32Xx";
  // final String upBitSecret = "c2qMtybiif4AfBalLqdcqVeUltkUXlctcoIvfDtu";

  Map<String, double> marketPriceMap = {};

  // priceUpdatedProvider는 providers.dart로 이동

  final StreamController<Map<String, dynamic>> btcPriceStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? timer;
  Set<String> upbitTickers = {'BTC'};

  String mainCurrency = 'KRW';

  void startService() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => loadPrices(t),
    );
    loadPrices(timer);
  }

  void dispose() {
    timer?.cancel();
    timer = null;
  }

  Future loadPrices(Timer? t) async {
    await Future.wait([
      loadPricesFromUpbit(t),
    ]);
  }

  String upbitUrl = "http://api.upbit.com/v1/ticker?markets=";

  Future loadPricesFromUpbit(Timer? t) async {
    if (upbitTickers.isEmpty) return;

    var markets =
        upbitTickers.map((v) => '$mainCurrency-$v').toList().join(',');
    //debugPrint('loadPricesFromUpbit: $markets');

    bool priceUpdated = false;
    var url = upbitUrl + markets;

    final client = RetryClient(http.Client());
    try {
      var response =
          await client.read(Uri.parse(url)).catchError((error, trace) {
        //debugPrint('loadPricesFromUpbit: exception $error');
        return Future.value("");
      });
      if (response == "") return;

      Map<String, double> valueMap = {};

      var data = jsonDecode(response);
      for (var i = 0; i < data.length; i++) {
        var market = data[i]['market'];
        var price = data[i]['trade_price'].toDouble();
        if (marketPriceMap[market] != price) {
          marketPriceMap[market] = price;
          valueMap[market] = price;

          priceUpdated = true;
          //debugPrint('$market: $price updated');
        }
      }

      if (priceUpdated) {
        // 값이 바뀌었음을 알려줌
        uncontrolledContainer.read(priceUpdatedProvider.notifier).state++;
      }
    } finally {
      client.close();
    }
  }

  late WebSocketChannel channel;

  Future startWebSocketUpbit() async {
    channel = WebSocketChannel.connect(
      Uri.parse('wss://api.upbit.com/websocket/v1'),
    );

    // 구독 메시지 전송
    final subscribeMessage = [
      {
        "ticket": "UNIQUE_TICKET",
      },
      {
        "type": "trade",
        "codes": ["KRW-BTC"],
        "isOnlyRealtime": true,
      },
    ];

    channel.sink.add(jsonEncode(subscribeMessage));

    // 스트림 리스닝 시작
    channel.stream.listen(
      (dynamic message) => _onData('upbit', message),
      onError: (error) {
        debugPrint('WebSocket Error: $error');
        // 에러 발생시 재연결 시도
        Future.delayed(const Duration(seconds: 5), startWebSocketUpbit);
      },
      onDone: () {
        debugPrint('WebSocket Connection Closed');
        // 연결이 끊어졌을 때 재연결 시도
        Future.delayed(const Duration(seconds: 5), startWebSocketUpbit);
      },
    );
  }

  Timer? randomWalkTimer;
  final random = math.Random();
  double lastMarkPrice = 0;
  double lastPrice = 0;

  int lastMarkPriceTime = 0;
  int randomWalkCounter = 0;

  // GBM 파라미터
  final double mu = 0.0; // drift (추세)
  final double sigma = 0.1; // volatility (변동성)
  final double dt = 0.2; // time step (0.2초)

  // Box-Muller 변환으로 정규분포 난수 생성
  double generateGaussian() {
    double u1 = 1.0 - random.nextDouble(); // uniform(0,1)
    double u2 = 1.0 - random.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }

  void startRandomWalk() {
    randomWalkTimer?.cancel();
    randomWalkTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // 현재 가격의 변동폭 설정 (0.01% = 0.0001)
      double volatility = 1;

      // -1 ~ 1 사이의 랜덤값 * 변동폭
      double change = (random.nextDouble() * 2 - 1) * volatility;

      // 새로운 가격 계산
      double newPrice = lastPrice + change;

      Map<String, dynamic> data = {
        'price': newPrice,
        'time': lastMarkPriceTime + randomWalkCounter++ * 200,
        'type': 'randomWalk',
        'currency': 'USDT',
      };
      btcPriceStream.add(data);
    });
  }

  Future startWebSocketBinanceFuture() async {
    channel = WebSocketChannel.connect(
      Uri.parse(
          //'wss://fstream.binance.com/stream?streams=btcusdt@aggTrade/btcusdt@markPrice@1s'),
          'wss://fstream.binance.com/stream?streams=btcusdt@markPrice@1s'),
    );

    // 스트림 리스닝 시작
    channel.stream.listen(
      (dynamic message) => _onData('binance', message),
      onError: (error) {
        debugPrint('WebSocket Error: $error');
        // 에러 발생시 재연결 시도
        Future.delayed(const Duration(seconds: 5), startWebSocketBinanceFuture);
      },
      onDone: () {
        debugPrint('WebSocket Connection Closed');
        // 연결이 끊어졌을 때 재연결 시도
        Future.delayed(const Duration(seconds: 5), startWebSocketBinanceFuture);
      },
    );

    // Ping 메시지 전송 (binance는 3분마다 ping 필요)
    Timer.periodic(const Duration(minutes: 3), (timer) {
      try {
        channel.sink
            .add(jsonEncode({"ping": DateTime.now().millisecondsSinceEpoch}));
      } catch (e) {
        debugPrint('Error sending ping: $e');
        timer.cancel();
        startWebSocketBinanceFuture();
      }
    });
  }

  int? lastEventTime;

  void _onData(String where, dynamic message) {
    try {
      if (where == 'upbit') {
        final Map<String, dynamic> src = jsonDecode(utf8.decode(message));
        Map<String, dynamic> data = {
          'price': src['trade_price'],
          'time': src['trade_time'],
          'currency': 'KRW',
        };
        btcPriceStream.add(data);
      } else if (where == 'binance') {
        try {
          // pong 메시지 처리
          if (message.contains('pong')) {
            return;
          }

          final Map<String, dynamic> src = jsonDecode(message);
          final String type = src['data']['e'];
          final eventTime = src['data']['E'];

          Map<String, dynamic> data = {
            'price': double.parse(src['data']['p']),
            'time': eventTime,
            'type': type,
            'currency': 'USDT',
          };

          if (type == 'markPriceUpdate') {
            btcPriceStream.add(data);
            lastEventTime = eventTime;

            lastMarkPrice = data['price'];
            lastMarkPriceTime = eventTime;
            lastPrice = lastMarkPrice;

            startRandomWalk();

            //debugPrint('mark: ${data['price']}');
          } else if (type == 'aggTrade') {
            if (lastEventTime != null && eventTime - lastEventTime >= 200) {
              lastEventTime = eventTime;
              btcPriceStream.add(data);
              debugPrint('agg: ${data['price']}');
            }
          }
        } catch (e) {
          debugPrint('Error parsing message: $e, $message');
        }
      } else if (where == 'okx') {
        if (message.contains('pong')) {
          return;
        }
        try {
          final Map<String, dynamic> src = jsonDecode(message);

          if (src['event'] == 'subscribe') {
            return; // 구독 확인 메시지 무시
          }

          final eventTime = int.parse(src['data'][0]['ts']);

          Map<String, dynamic> data = {
            'price':
                double.parse(src['data'][0]['px'] ?? src['data'][0]['markPx']),
            'currency': 'USDT',
          };

          if (src['arg']?['channel'] == 'trades') {
            if (lastEventTime != null && eventTime - lastEventTime! >= 200) {
              lastEventTime = eventTime;
              btcPriceStream.add(data);
              debugPrint('agg: ${data['price']}');
            }
          } else if (src['arg']?['channel'] == 'mark-price') {
            btcPriceStream.add(data);
            lastEventTime = eventTime;
          }
        } catch (e, s) {
          debugPrint('Error parsing message: $message, $e, $s');
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void startWebSocketOKX() {
    // OKX WebSocket
    channel = WebSocketChannel.connect(
      Uri.parse('wss://ws.okx.com:8443/ws/v5/public'),
    );

    // 구독 메시지 전송
    final subscribeMessage = {
      "op": "subscribe",
      "args": [
        {"channel": "mark-price", "instId": "BTC-USDT-SWAP"},
        {"channel": "trades", "instId": "BTC-USDT-SWAP"}
      ]
    };

    channel.sink.add(jsonEncode(subscribeMessage));

    channel.stream.listen(
      (dynamic message) => _onData('okx', message),
      onError: (error) {
        debugPrint('WebSocket Error: $error');
        startWebSocketOKX();
      },
      onDone: () {
        debugPrint('WebSocket Connection Closed');
        startWebSocketOKX();
      },
    );

    // Ping 메시지 전송 (OKX는 30초마다 ping 필요)
    Timer.periodic(const Duration(seconds: 25), (timer) {
      try {
        channel.sink.add('ping');
      } catch (e) {
        debugPrint('Error sending ping: $e');
        timer.cancel();
        startWebSocketOKX();
      }
    });
  }

  double? getPrice(String ticker, {String? currency}) {
    currency ??= mainCurrency;
    var tickerKey = '$currency-$ticker';
    return marketPriceMap[tickerKey];
  }

  void addPrice(String ticker, double price, {String? currency}) {
    currency ??= mainCurrency;
    var tickerKey = '$currency-$ticker';
    this.marketPriceMap[tickerKey] = price;
    uncontrolledContainer.read(priceUpdatedProvider.notifier).state++;
  }

  Completer<List<Map>?>? candleCompleter;

  Future<List<Map>?> loadCandlesFromUpbit(
    String ticker, {
    DateTime? to,
    int count = 100,
  }) async {
    var url =
        "https://api.upbit.com/v1/candles/days?market=$ticker&count=$count";

    if (to != null) {
      url += '&to=${DateFormat('yyyy-MM-dd HH:mm:ss').format(to)}';
    }

    candleCompleter = Completer<List<Map>?>();

    final client = RetryClient(http.Client());
    try {
      var response =
          await client.read(Uri.parse(url)).catchError((error, trace) {
        debugPrint('loadCandlesFromUpbit: $url, exception $error');
        return Future.value("");
      });
      if (response == "") return null;
      var data = jsonDecode(response);
      candleCompleter!.complete(List<Map>.from(data));
    } catch (e) {
      debugPrint('loadCandlesFromUpbit: exception $e');
      if (!candleCompleter!.isCompleted) candleCompleter!.complete([{}]);
    } finally {
      client.close();
    }

    return candleCompleter!.future;
  }
}
