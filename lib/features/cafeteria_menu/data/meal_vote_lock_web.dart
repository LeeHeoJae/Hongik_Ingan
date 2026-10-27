import 'dart:js_interop';

@JS('navigator.locks')
external JSObject? get _locks;

@JS('navigator.locks.request')
external JSPromise<JSString> _requestLock(String name, JSFunction callback);

Future<String> withVoteKeyLock(Future<String> Function() action) async {
  if (_locks == null) throw UnsupportedError('Web Locks unavailable');
  final result = await _requestLock(
    'hongik-meal-vote-key-v1',
    ((JSAny? _) => action().then((value) => value.toJS).toJS).toJS,
  ).toDart;
  return result.toDart;
}
