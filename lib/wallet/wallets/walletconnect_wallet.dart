// Conditional import: Web과 Mobile에서 다른 구현 사용
export 'walletconnect_mobile.dart' if (dart.library.js_interop) 'walletconnect_web.dart';
