import 'seat_response_decoder_native.dart'
    if (dart.library.js_interop) 'seat_response_decoder_web.dart'
    as platform;

String decodeSeatResponse(List<int> bytes) {
  return platform.decodeSeatResponse(bytes);
}
