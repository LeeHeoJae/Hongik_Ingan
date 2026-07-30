import 'dart:convert';

String decodeSeatResponse(List<int> bytes) {
  return utf8.decode(bytes, allowMalformed: true);
}
