class CafeteriaMenuServiceException implements Exception {
  const CafeteriaMenuServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 메뉴를 파싱할 때 발생한 예외.
class CafeteriaMenuParseException extends CafeteriaMenuServiceException {
  const CafeteriaMenuParseException(super.message);
}
