// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart' as url;
//import 'package:flutter_windowmanager/flutter_windowmanager.dart';

import '../common/util.dart';
import '../data/account.dart';

bool _appInBackground = false;

void setAppInBackground(bool v) => _appInBackground = v;

void initPlatform() {}

String getWindowLocation() => '';

String getUrlFragment() => '';

bool isIOS() => Platform.isIOS;

bool isMobileWeb() => false;

Future<String> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.display;
  } else {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    return '${iosInfo.utsname.sysname}.${iosInfo.utsname.version}.${iosInfo.utsname.machine}';
  }
}

String? _deviceId;

Future<String?> getDeviceId() async {
  if (_deviceId == null) {
    const androidId = AndroidId();
    if (Platform.isAndroid) {
      _deviceId = await androidId.getId();
    } else {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    }
  }
  return _deviceId;
}

Future disableScreenShot() async {
  //await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
}

Future enableScreenShot() async {
  //await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
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
  Function(dynamic)? onError,
  Function(int)? onClose,
  bool? dontWrapStatusCode = false,
}) async {
  final Completer completer = Completer();

  HttpClient client = HttpClient();
  client.badCertificateCallback =
      ((X509Certificate cert, String host, int port) {
    return true;
  });

  try {
    var request = await client.getUrl(uri).onError((error, stackTrace) {
      debugPrint(error.toString());
      throw TimeoutException;
    });
    var response = await request.close()
      ..timeout(timeout ?? const Duration(seconds: 5));

    if (response.statusCode == 200) {
      onConnected?.call(client);

      final contents = StringBuffer();
      response.transform(utf8.decoder).listen(
        (data) {
          contents.write(data);
          onData?.call(data);
        },
        onDone: () {
          String data = contents.toString();
          try {
            Map<String, dynamic>? result = json.decode(data);

            if (result != null) {
              // 우리 서버에서 공통으로 사용하는 accesstoken 관련 처리
              AccountManager().checkUpdateToken(result);
            }
          } catch (e) {}

          _setHttpResult(completer, 200,
              data: contents.toString(), dontWrap: dontWrapStatusCode);
          onClose?.call(200);
        },
      );
    } else {
      debugPrint('getUri: statusCode ${response.statusCode}');
      _setHttpResult(completer, response.statusCode);
      onClose?.call(response.statusCode);
    }
  } on TimeoutException catch (_) {
    Util.showAlert("서버 접속 타임아웃");
    _setHttpResult(completer, 408);
  } on Error catch (e) {
    debugPrint('Error: $e');
    Util.showAlert("서버 결과 처리중 오류 발생: $e");
    _setHttpResult(completer, 500);
    onError?.call(e);
  }

  return completer.future;
}

Future subscribeToSSE(
  Uri uri, {
  Function(dynamic)? onConnected,
  Function(Object?)? onData,
  Function(dynamic)? onError,
  Function(int)? onClose,
}) async {
  return await getUri(
    uri,
    onConnected: onConnected,
    onData: onData,
    onError: onError,
    onClose: onClose,
  );
}

void closeHttpClient(dynamic client) {
  if (client is HttpClient) {
    client.close();
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Dio getDio() {
  Dio dio = Dio();
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      return client;
    },
  );

  // dio version 4
  // (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
  //     (HttpClient client) {
  //   client.badCertificateCallback =
  //       (X509Certificate cert, String host, int port) => true;
  //   return client;
  // };
  return dio;
}

Future<dynamic> postUri(
  Uri uri,
  Map<String, dynamic> params, {
  Map<String, String>? headers,
  String? authroization,
  Function(String)? onStreamData,
  Duration? timeout,
}) async {
  final Completer completer = Completer();

  HttpClient client = HttpClient();
  client.badCertificateCallback =
      ((X509Certificate cert, String host, int port) {
    final isValidHost = host.contains("ateon.io");
    // Allowing multiple hosts
    // final isValidHost = host == "api.my_app" || host == "my_second_host";
    return isValidHost;
  });

  HttpClientRequest request;
  try {
    request = await client
        .postUrl(uri)
        .timeout(timeout ?? const Duration(seconds: 5));
    request.headers.set('Accept', "application/json");
    request.headers.set('Content-Type', "application/json");
    if (headers != null) {
      for (var key in headers.keys) {
        request.headers.set(key, headers[key]!);
      }
    }
    if (authroization != null) {
      request.headers.set('Authorization', authroization);
    }
    request.add(utf8.encode(json.encode(params)));

    final contents = StringBuffer();
    HttpClientResponse response = await request.close()
      ..timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      response.transform(utf8.decoder).listen((data) {
        try {
          // SSE 때문에 데이터가 일부만 오는 경우도 디코딩을 해보고 contents에 write를 해준다.
          final decoded = jsonDecode(data);
          if (!(decoded.containsKey('type') && decoded['type'] == 'progress')) {
            contents.write(data);
          }
        } catch (e) {
          // 이건 정상적인 것임. contents에 write해주고 onDone에서 처리함
          contents.write(data);
        }
        onStreamData?.call(data);
      }, onDone: () {
        String data = contents.toString();
        try {
          Map<String, dynamic>? result = json.decode(data);

          if (result != null) {
            // 우리 서버에서 공통으로 사용하는 accesstoken 관련 처리
            AccountManager().checkUpdateToken(result);
          }
          completer.complete(result);
        } catch (e) {
          completer.complete(data);
          debugPrint('postUri: exception ${e.toString()}');
        }
      });
    } else {
      debugPrint('postUri: statusCode ${response.statusCode}');
      response.transform(utf8.decoder).listen((data) {
        debugPrint(data);
      });
      completer.complete({'result': 99, 'error': 'server error'});
    }
  } on TimeoutException catch (_) {
    Util.toastError('서버 접속 시간 초과');
    debugPrint('postUri: timeout $uri');
    return null;
  } on SocketException catch (e) {
    debugPrint('postUri: $uri, exception ${e.toString()}');
    return {'result': 99, 'error': 'socket error'};
  }

  return completer.future;
}

Future<WebSocketChannel> connectToWebSocket(String url) async {
  try {
    // SSL 검증 무시 설정
    final socket = await WebSocket.connect(
      url,
      customClient: HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true,
    );

    return IOWebSocketChannel(socket);
  } catch (e) {
    debugPrint('WebSocket 연결 에러: $e');
    rethrow;
  }
}

Future openUrl(String urlPath, {String? target}) async {
  await url.launchUrl(Uri.parse(urlPath));
}

// web platform에 있는 것과 맞춰줌
Map<String, String> getParams() {
  return {};
}

void enterFullScreen() {}

void exitFullScreen() {}

bool isFullScreen() => true;

void toggleFullScreen() {}

bool isAppHidden() => _appInBackground;

class SecureStorageImpl {
  static FlutterSecureStorage? _secureStorage;

  static FlutterSecureStorage get secureStorage {
    _secureStorage ??= FlutterSecureStorage();
    return _secureStorage!;
  }

  static Future<void> write(
      {required String key, required String? value}) async {
    if (value != null) {
      await secureStorage.write(key: key, value: value);
    } else {
      await secureStorage.delete(key: key);
    }
  }

  static Future<String?> read({required String key}) async {
    return await secureStorage.read(key: key);
  }

  static Future<void> delete({required String key}) async {
    await secureStorage.delete(key: key);
  }

  static Future<void> deleteAll() async {
    await secureStorage.deleteAll();
  }
}

void setupVisibilityListener(Function(bool)? callback) {}

class WebSessionStorage {
  static void save(String key, String value) {}

  static String? load(String key) {
    return null;
  }

  static void remove(String key) {}

  static void clear() {}
}
