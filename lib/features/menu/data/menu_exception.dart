class MenuServiceException implements Exception {
  const MenuServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 메뉴를 파싱할 때 발생한 예외.
class MenuParseException extends MenuServiceException {
  const MenuParseException(super.message);
}
