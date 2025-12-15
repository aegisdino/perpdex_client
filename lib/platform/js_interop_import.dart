import 'dart:js_interop';
export 'dart:js_interop';

@JS('window')
external Window get window;

@JS()
@staticInterop
class Window {}

@JS()
@staticInterop
class History {}

extension WindowExtension on Window {
  external History get history;

  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension HistoryExtension on History {
  external void pushState(JSAny? stateObj, String title, String url);
}
