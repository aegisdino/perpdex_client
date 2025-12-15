import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import '/common/all.dart';
import '../game/websocket_client.dart';
import '../data/providers.dart';

abstract class GameWebViewController {
  bool get canOpenInNewTab;

  void goBack();
  void goForward();
  void reload();
  void toggleFullscreen();
  void openInNewTab();
}

class GameWebView extends ConsumerStatefulWidget {
  final String gameUrl;
  final String gameName;
  final Function(GameWebViewController) onControllerReady;

  const GameWebView({
    Key? key,
    required this.gameUrl,
    required this.gameName,
    required this.onControllerReady,
  }) : super(key: key);

  @override
  ConsumerState<GameWebView> createState() => GameWebViewState();
}

class GameWebViewState extends ConsumerState<GameWebView>
    implements GameWebViewController {
  web.HTMLIFrameElement? _iframeElement;
  bool isLoadingWebView = true;
  Timer? _loadingTimer;
  String _iframeViewType = '';

  static String? _currentIframeViewType;

  static bool get isGameActive {
    if (_currentIframeViewType == null) return false;
    try {
      // Check if iframe element exists in DOM
      final elements = web.document.querySelectorAll('iframe');
      for (int i = 0; i < elements.length; i++) {
        final element = elements.item(i);
        if (element != null && element is web.HTMLIFrameElement) {
          // iframe이 존재하면 게임이 활성화된 것으로 판단
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  bool get canOpenInNewTab => true;

  @override
  void initState() {
    super.initState();
    _iframeViewType = 'iframe-${DateTime.now().millisecondsSinceEpoch}';
    _currentIframeViewType = _iframeViewType; // static 변수에 저장
    _createIframe();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerReady(this);
    });
    _startLoadingTimer();
  }

  void _createIframe() {
    _iframeElement =
        web.document.createElement('iframe') as web.HTMLIFrameElement;
    _iframeElement!.src = widget.gameUrl;
    _iframeElement!.style.border = 'none';
    _iframeElement!.style.width = '100%';
    _iframeElement!.style.height = '100%';
    _iframeElement!.style
        .setProperty('pointer-events', 'none'); // 오버레이가 있을 때는 터치 차단

    // iframe 로딩 이벤트 감지
    _iframeElement!.addEventListener(
        'load',
        (web.Event event) {
          // iframe 로딩 완료 후 오버레이 제거
          if (mounted && isLoadingWebView) {
            _hideLoadingOverlay();
          }
        }.toJS);

    _iframeElement!.addEventListener(
        'error',
        (web.Event event) {
          print("Iframe loading error");
          if (mounted && isLoadingWebView) {
            _hideLoadingOverlay();
          }
        }.toJS);

    // HtmlElementView로 등록
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeViewType,
      (int viewId) => _iframeElement!,
    );
  }

  void _startLoadingTimer() {
    // 최대 15초 후 강제로 오버레이 제거 (타임아웃)
    _loadingTimer = Timer(Duration(seconds: 10), () {
      if (mounted && isLoadingWebView) {
        print("Loading timeout - force hiding overlay");
        _hideLoadingOverlay();
      }
    });
  }

  void _hideLoadingOverlay() {
    setState(() {
      isLoadingWebView = false;
    });
    // 오버레이가 사라지면 iframe이 터치를 받을 수 있도록 함
    _iframeElement?.style.setProperty('pointer-events', 'auto');
  }

  final String iframeId = 'pp-game-iframe';

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationProvider, (prev, next) async {
      final notification = next as dynamic;
      if (notification?.type == 'duplicatedlogin') {
        _iframeElement?.style.setProperty('pointer-events', 'none');

        Util.showAlert(
            'Disconnected from the server.\nThis might be caused by being signed in from a different device.',
            onOK: () {
          _iframeElement?.style.setProperty('pointer-events', 'auto');
          goBack();
        });
      }
    });

    return Stack(
      children: [
        // iframe을 HtmlElementView로 표시
        HtmlElementView(viewType: _iframeViewType),

        // 로딩 오버레이 - 이제 터치가 정상 작동함
        if (isLoadingWebView)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                print("Loading screen tapped - hiding overlay");
                _loadingTimer?.cancel();
                _hideLoadingOverlay();
              },
              child: Container(
                color: Colors.black87.withAlpha(200),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Loading Game...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      Text(
                        widget.gameName,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 30),
                      Text(
                        'TAP ANYWHERE TO HIDE',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Starting shortly...',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void goBack() {
    // Web에서 iframe의 뒤로가기는 제한적이므로 브라우저 히스토리 사용
    web.window.history.back();
  }

  @override
  void goForward() {
    web.window.history.forward();
  }

  @override
  void reload() {
    if (_iframeElement != null) {
      _iframeElement!.src = widget.gameUrl;
    }
  }

  @override
  void toggleFullscreen() {
    web.document.documentElement?.requestFullscreen();
  }

  @override
  void openInNewTab() {
    web.window.open(widget.gameUrl, '_blank');
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _currentIframeViewType = null; // dispose 시 static 변수 초기화
    super.dispose();
  }
}
