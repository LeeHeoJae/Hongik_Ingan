class SeatServiceException implements Exception {
  const SeatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SeatParseException extends SeatServiceException {
  const SeatParseException(super.message);
}
