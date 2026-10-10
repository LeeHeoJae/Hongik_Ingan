import 'dart:js_interop';

@JS('window.history.go')
external void _go(JSNumber delta);

void goBrowserHistory(int delta) => _go(delta.toJS);
