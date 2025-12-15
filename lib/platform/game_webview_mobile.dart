import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/common/util.dart';
import '/common/styles.dart';

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
  InAppWebViewController? webViewController;
  double progress = 0;
  bool isLoadingWebView = false;

  @override
  bool get canOpenInNewTab => false; // 모바일에서는 새 탭 기능 없음

  @override
  void initState() {
    super.initState();
    widget.onControllerReady(this);
    GameWebViewState.isGameActive = true;
  }

  @override
  void dispose() {
    GameWebViewState.isGameActive = false;
    super.dispose();
  }

  static bool isGameActive = false;

  String? criticalMessage;

  Widget buildCriticalMessage() {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      backgroundColor: AppTheme.colorScheme.surface,
      title: Text('common.notice'.tr()),
      scrollable: true,
      content: ListBody(
        children: <Widget>[
          SelectionArea(
            child: MyStyledText(
              criticalMessage!,
              fontSize: 14,
              height: 1.4,
              color: AppTheme.colorScheme.onSurface,
            ),
          )
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text('common.ok'.tr()),
          onPressed: () {
            goBack();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.gameUrl)),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            useHybridComposition: true,
            //allowsInlineMediaPlaybook: true,
            preferredContentMode: UserPreferredContentMode.DESKTOP,
            supportZoom: false,
            transparentBackground: true,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            useWideViewPort: true,
            loadWithOverviewMode: true,
            allowFileAccess: true,
            allowContentAccess: true,
            allowUniversalAccessFromFileURLs: true,
            allowFileAccessFromFileURLs: true,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStart: (controller, url) {
            setState(() {
              isLoadingWebView = true;
              progress = 0;
            });
          },
          onLoadStop: (controller, url) async {
            setState(() {
              progress = 1.0;
              isLoadingWebView = false;
            });

            // 게임 화면에 맞게 자동 조정
            try {
              await controller.evaluateJavascript(source: """
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.getElementsByTagName('head')[0].appendChild(meta);
              """);
            } catch (e) {
              print("JavaScript error: $e");
            }
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              this.progress = progress / 100;
            });
          },
          onReceivedError: (controller, request, error) {
            setState(() {
              isLoadingWebView = false;
            });
            print("WebView error: ${error.description}");
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            return NavigationActionPolicy.ALLOW;
          },
          onConsoleMessage: (controller, consoleMessage) {
            print("Console: ${consoleMessage.message}");
          },
        ),

        // 모바일용 로딩 인디케이터
        if (isLoadingWebView)
          Container(
            color: Colors.black87.withOpacity(0.8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  isLoadingWebView = false;
                });
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                    SizedBox(height: 20),
                    Text(
                      progress > 0
                          ? 'Loading ${(progress * 100).toStringAsFixed(0)}%'
                          : 'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TAP TO CONTINUE',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (criticalMessage.isNotNullEmptyOrWhitespace) buildCriticalMessage(),
      ],
    );
  }

  @override
  void goBack() async {
    if (webViewController != null && await webViewController!.canGoBack()) {
      webViewController!.goBack();
    }
  }

  @override
  void goForward() async {
    if (webViewController != null && await webViewController!.canGoForward()) {
      webViewController!.goForward();
    }
  }

  @override
  void reload() {
    webViewController?.reload();
  }

  @override
  void toggleFullscreen() {
    webViewController?.evaluateJavascript(source: """
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
      } else {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        }
      }
    """);
  }

  @override
  void openInNewTab() {
    // 모바일에서는 구현되지 않음
  }
}
