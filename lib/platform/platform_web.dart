// ignore_for_file: avoid_web_libraries_in_flutter, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web/web.dart' as web;

import '/common/all.dart';
import '../data/account.dart';

Map<String, String>? _initParams;

bool _appInBackground = false;

void setAppInBackground(bool v) => _appInBackground = v;

void initPlatform() {
  _initParams = getParams();

  setUrlStrategy(PathUrlStrategy());
  //setUrlStrategy(HashUrlStrategy());
}

String getWindowLocation() => web.window.location.href;

String getUrlFragment() {
  String fullHash = web.window.location.hash;

  if (fullHash.startsWith('#')) {
    return fullHash.substring(1);
  }

  return fullHash;
}

bool isIOS() => false;

bool isMobileWeb() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('mobile') ||
      userAgent.contains('android') ||
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
}

Future<String> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  WebBrowserInfo webBrowserInfo = await deviceInfo.webBrowserInfo;
  return '${webBrowserInfo.userAgent}';
}

String? _deviceId;

Future<String?> getDeviceId() async {
  if (_deviceId == null) {
    final pref = await SharedPreferences.getInstance();
    // secure storage에서 로딩
    final savedId = await pref.getString('webdeviceid');
    if (savedId.isNotNullEmptyOrWhitespace) {
      _deviceId = savedId;
      //debugPrint('getDeviceId: saved in SecureStorage $savedId');
    } else {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final webBrowserInfo = await deviceInfo.webBrowserInfo;

      // 더 많은 브라우저 정보 수집
      final navigator = web.window.navigator;
      final screen = web.window.screen;

      // 추가 정보 수집
      final screenResolution =
          '${screen.width}x${screen.height}x${screen.colorDepth}';
      final timezone = DateTime.now().timeZoneOffset.inMinutes.toString();
      final language = navigator.language;
      final languages = navigator.languages.toDart.join(',');
      final platform = navigator.platform;
      final cookieEnabled = navigator.cookieEnabled ? '1' : '0';
      final onLine = navigator.onLine ? '1' : '0';
      final deviceMemory = _getDeviceMemory();
      final maxTouchPoints = navigator.maxTouchPoints.toString();

      // Canvas fingerprinting - 간단한 캔버스 기반 핑거프린트
      final canvasFingerprint = _getCanvasFingerprint();

      // WebGL 정보
      final webglInfo = _getWebGLInfo();

      // 모든 정보를 조합하여 고유한 ID 생성
      final tmpText = [
        webBrowserInfo.vendor ?? '-',
        webBrowserInfo.userAgent ?? '-',
        webBrowserInfo.hardwareConcurrency?.toString() ?? '-',
        screenResolution,
        timezone,
        language,
        languages,
        platform,
        cookieEnabled,
        onLine,
        deviceMemory,
        maxTouchPoints,
        canvasFingerprint,
        webglInfo,
        webBrowserInfo.platform ?? '-',
        webBrowserInfo.product ?? '-',
        webBrowserInfo.appCodeName ?? '-',
        webBrowserInfo.appName ?? '-',
        webBrowserInfo.appVersion ?? '-',
      ].join('_');

      _deviceId = createSHA1Hash(tmpText);
      // secure storage에 저장
      await pref.setString('webdeviceid', _deviceId ?? '');
    }
  }
  return _deviceId;
}

// Device memory 가져오기 (Chrome 기반 브라우저)
String _getDeviceMemory() {
  try {
    // navigator.deviceMemory 접근 시도
    final jsMemory = web.window.navigator.getProperty('deviceMemory'.toJS);
    if (jsMemory != null && jsMemory.isA<JSNumber>()) {
      return (jsMemory as JSNumber).toDartDouble.toString();
    }
  } catch (e) {
    // 지원하지 않는 브라우저
  }
  return '-';
}

// Canvas fingerprinting
String _getCanvasFingerprint() {
  try {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = 200;
    canvas.height = 50;

    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context != null) {
      // 텍스트 그리기
      context.textBaseline = 'top';
      context.font = '14px Arial';
      context.fillStyle = 'rgb(255, 0, 0)'.toJS;
      context.fillText('Browser Fingerprint 🚀', 2, 2);

      // 도형 그리기
      context.fillStyle = 'rgb(0, 255, 0)'.toJS;
      context.fillRect(10, 10, 50, 50);

      // Canvas 데이터를 문자열로 변환
      final dataUrl = canvas.toDataURL();
      // 데이터 URL의 일부만 사용 (너무 길지 않게)
      return dataUrl.substring(dataUrl.length > 100 ? dataUrl.length - 100 : 0);
    }
  } catch (e) {
    // Canvas를 지원하지 않거나 오류 발생
  }
  return '-';
}

// WebGL 정보 가져오기
String _getWebGLInfo() {
  try {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    final gl =
        canvas.getContext('webgl') ?? canvas.getContext('experimental-webgl');

    if (gl != null && gl.isA<web.WebGLRenderingContext>()) {
      final glContext = gl as web.WebGLRenderingContext;

      // WebGL renderer 정보
      final debugInfo = glContext.getExtension('WEBGL_debug_renderer_info');
      if (debugInfo != null) {
        final vendor = glContext.getParameter(0x9245); // UNMASKED_VENDOR_WEBGL
        final renderer =
            glContext.getParameter(0x9246); // UNMASKED_RENDERER_WEBGL

        String vendorStr = '-';
        String rendererStr = '-';

        if (vendor != null && vendor.isA<JSString>()) {
          vendorStr = (vendor as JSString).toDart;
        }
        if (renderer != null && renderer.isA<JSString>()) {
          rendererStr = (renderer as JSString).toDart;
        }

        return '${vendorStr}_${rendererStr}';
      }

      // 기본 WebGL 파라미터들
      final params = [
        glContext.getParameter(0x1F00), // MAX_VERTEX_ATTRIBS
        glContext.getParameter(0x1F01), // MAX_VERTEX_UNIFORM_VECTORS
        glContext.getParameter(0x1F02), // MAX_VARYING_VECTORS
      ];

      return params.map((p) => p?.toString() ?? '-').join('_');
    }
  } catch (e) {
    // WebGL을 지원하지 않거나 오류 발생
  }
  return '-';
}

Future disableScreenShot() async {
  // not supported
}

Future enableScreenShot() async {
  // not supported
}

void _setHttpResult(Completer completer, int statusCode,
    {String? data, bool? dontWrap}) {
  if (!completer.isCompleted) {
    completer.complete((dontWrap == true)
        ? data
        : {'statusCode': statusCode, if (statusCode == 200) 'data': data});
  }
}

Future<dynamic> getUri(
  Uri uri, {
  Duration? timeout,
  Function(dynamic client)? onConnected,
  Function(Object? data)? onData,
  bool? dontWrapStatusCode = false,
}) async {
  final Completer completer = Completer();

  var request = http.Request('GET', uri);

  try {
    http.StreamedResponse response = await http.Client()
        .send(request)
        //.timeout(timeout)
        .catchError((e, s) {
      hideLoading();
      Util.showAlert("Server connect error: $e");
      throw e;
    });

    if (response.statusCode == 200) {
      onConnected?.call(request);

      final contents = StringBuffer();
      response.stream.transform(utf8.decoder).listen((data) {
        contents.write(data);
        onData?.call(data);
      }).onDone(() async {
        try {
          Map<String, dynamic> result = json.decode(contents.toString());

          // 우리 서버에서 공통으로 사용하는 accesstoken 관련 처리
          AccountManager().checkUpdateToken(result);
        } catch (e) {}

        _setHttpResult(completer, 200,
            data: contents.toString(), dontWrap: dontWrapStatusCode);
      });
    } else {
      debugPrint('getUri: statusCode ${response.statusCode}');
      _setHttpResult(completer, response.statusCode);
    }
  } on TimeoutException catch (e) {
    hideLoading();
    Util.showAlert("Server connect timeout");
    _setHttpResult(completer, 408);
  } on Error catch (e) {
    debugPrint('Error: $e');
    hideLoading();
    Util.showAlert("Fail to process server result: $e");
    _setHttpResult(completer, 500);
  }

  return completer.future;
}

@JS()
extension type EventSource._(JSObject _) implements JSObject {
  external EventSource(String url);
  external void close();
  external int get readyState;
  external set onopen(JSFunction? handler);
  external set onmessage(JSFunction? handler);
  external set onerror(JSFunction? handler);
}

@JS()
extension type MessageEvent._(JSObject _) implements JSObject {
  external String get data;
}

Future subscribeToSSE(
  Uri uri, {
  Function(dynamic)? onConnected,
  Function(Object?)? onData,
  Function(dynamic)? onError,
  Function(int)? onClose,
}) async {
  final eventSource = EventSource(uri.toString());

  eventSource.onmessage = (MessageEvent event) {
    onData?.call(event.data);
  }.toJS;

  eventSource.onopen = (JSAny _) {
    onConnected?.call(eventSource);
  }.toJS;

  eventSource.onerror = (JSAny error) {
    eventSource.close();
    onError?.call(error);
  }.toJS;
}

void closeHttpClient(dynamic client) {
  if (client is http.Request) {
    client.finalize();
  } else if (client is EventSource) {
    client.close();
  }
}

Future<dynamic> postUri(
  Uri uri,
  Map<String, dynamic> params, {
  Map<String, String>? headers,
  String? authroization,
  Duration? timeout,
  Function(String)? onStreamData,
}) async {
  final Completer completer = Completer();

  try {
    var request = http.Request('POST', uri);
    request.headers['Accept'] = "application/json";
    request.headers['Content-Type'] = 'application/json';
    if (headers != null) {
      for (var key in headers.keys) {
        request.headers[key] = headers[key]!;
      }
    }
    if (authroization != null) {
      request.headers['Authorization'] = authroization;
    }
    request.body = jsonEncode(params);
    http.StreamedResponse response = await http.Client()
        .send(request)
        .timeout(const Duration(seconds: 10))
        .onError((error, stackTrace) async {
      throw error!;
    });

    if (response.statusCode == 200) {
      final contents = StringBuffer();
      response.stream.transform(utf8.decoder).listen((data) {
        try {
          final decoded = jsonDecode(data);
          if (!(decoded.containsKey('type') && decoded['type'] == 'progress')) {
            contents.write(data);
          }
        } catch (e) {
          contents.write(data);
        }
        if (onStreamData != null) onStreamData.call(data);
      }).onDone(() async {
        collectPostResult(contents, completer);
      });
    } else {
      debugPrint('postServerWeb: statusCode ${response.statusCode}');
      completer.complete({'result': 99, 'error': 'server error'});
    }
  } on TimeoutException catch (e) {
    Util.showAlert("fail_msg_timeout");
  } on Error catch (e) {
    debugPrint('Error: $e');
    Util.showAlert("fail_msg_connect");
  }

  return completer.future;
}

void collectPostResult(StringBuffer contents, Completer completer) {
  String data = contents.toString();

  //debugPrint('collectPostResult: $data');

  try {
    Map<String, dynamic> result = json.decode(data);

    // 우리 서버에서 공통으로 사용하는 accesstoken 관련 처리
    AccountManager().checkUpdateToken(result);
    completer.complete(result);
  } on Exception catch (e) {
    completer.complete(data);
    debugPrint('postMainServer: exception ${e.toString()}');
  }
}

Map<String, String> getParams() {
  if (_initParams != null) {
    return _initParams!;
  }
  var uri = Uri.dataFromString(web.window.location.href);
  return uri.queryParameters;
}

Future<WebSocketChannel> connectToWebSocket(String url) async {
  return WebSocketChannel.connect(Uri.parse(url));
}

Future openUrl(String urlPath, {String? target}) async {
  web.window.open(urlPath, target ?? '_blank');
}

void enterFullScreen() {
  web.document.documentElement?.requestFullscreen();
}

void exitFullScreen() {
  web.document.exitFullscreen();
}

bool isFullScreen() {
  return web.document.fullscreenElement != null;
}

void toggleFullScreen() {
  if (isFullScreen()) {
    exitFullScreen();
  } else {
    enterFullScreen();
  }
}

bool isAppHidden() {
  return web.document.hidden;
}

// http 연결의 경우
// - window.crypto.subtle이 uefined인 관계로 FlutterSecureStorage 가 동작하지 않음
// - 때문에 http의 경우 FlutterSecureStorage를 사용할 수 없음!
// - 그래도 간단한 암호화는 추가하자
class SecureStorageImpl {
  static FlutterSecureStorage? _secureStorage;

  static FlutterSecureStorage get secureStorage {
    _secureStorage ??= FlutterSecureStorage();
    return _secureStorage!;
  }

  static bool get isSecureContext {
    // Check if crypto is available
    try {
      return web.window.isSecureContext;
    } catch (_) {
      return Uri.base.scheme == 'https' || Uri.base.host == 'localhost';
    }
  }

  static Future<void> write(
      {required String key, required String? value}) async {
    if (isSecureContext) {
      // HTTPS 환경 - flutter_secure_storage 사용
      final storage = FlutterSecureStorage();
      if (value != null) {
        await storage.write(key: key, value: value);
      } else {
        await storage.delete(key: key);
      }
    } else {
      // HTTP 환경 - localStorage 사용
      if (value != null) {
        web.window.localStorage.setItem(key, encryptAES(value));
      } else {
        web.window.localStorage.removeItem(key);
      }
    }
  }

  // 나머지 메서드들도 같은 방식으로 수정
  static Future<String?> read({required String key}) async {
    if (isSecureContext) {
      return await secureStorage.read(key: key);
    } else {
      return Future.value(
          decryptAES(web.window.localStorage.getItem(key) ?? ''));
    }
  }

  static Future<void> delete({required String key}) async {
    if (isSecureContext) {
      await secureStorage.delete(key: key);
    } else {
      web.window.localStorage.removeItem(key);
    }
  }

  static Future<void> deleteAll() async {
    if (isSecureContext) {
      await secureStorage.deleteAll();
    } else {
      web.window.localStorage.clear();
    }
  }
}

void setupVisibilityListener(Function(bool)? callback) {
  if (callback == null) return;

  // Set up a global JavaScript function that Dart can call
  web.window.setProperty(
    'onVisibilityChange'.toJS,
    ((JSBoolean isHidden) {
      callback(isHidden.toDart);
    }).toJS,
  );

  // Add visibility change event listener
  web.document.addEventListener(
    'visibilitychange',
    ((web.Event event) {
      final isHidden = web.document.visibilityState == 'hidden';
      print(
          'visibilitychange: new visibilityState ${web.document.visibilityState}');
      // Call our callback directly
      callback(isHidden);
    }).toJS,
  );
}

@JS('window.sessionStorage')
external JSObject get sessionStorage;

@JS()
extension type SessionStorage._(JSObject _) implements JSObject {
  external void setItem(String key, String value);
  external String? getItem(String key);
  external void removeItem(String key);
  external void clear();
}

class WebSessionStorage {
  static final SessionStorage _storage = sessionStorage as SessionStorage;

  static void save(String key, String value) {
    _storage.setItem(key, value);
  }

  static String? load(String key) {
    return _storage.getItem(key);
  }

  static void remove(String key) {
    _storage.removeItem(key);
  }

  static void clear() {
    _storage.clear();
  }
}
