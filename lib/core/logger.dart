import 'package:flutter/foundation.dart';

void logMsg(String msg) {
  if (kDebugMode) {
    print('[Debug]: $msg');
  }
}
