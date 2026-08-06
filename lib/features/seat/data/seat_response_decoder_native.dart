import 'dart:convert';

// ignore: implementation_imports
import 'package:charset/src/euc_kr_table.dart' as euc_kr_table;

String decodeSeatResponse(List<int> bytes) {
  final buffer = StringBuffer();
  for (var index = 0; index < bytes.length; index++) {
    final first = bytes[index];
    if (first < 0x80) {
      buffer.writeCharCode(first);
      continue;
    }

    if (index + 1 >= bytes.length) {
      buffer.writeCharCode(unicodeReplacementCharacterRune);
      continue;
    }

    final second = bytes[++index];
    final code = (first << 8) + second;
    final charCode = euc_kr_table.utf8ToEucKr[code];
    buffer.writeCharCode(charCode ?? unicodeReplacementCharacterRune);
  }
  return buffer.toString();
}
