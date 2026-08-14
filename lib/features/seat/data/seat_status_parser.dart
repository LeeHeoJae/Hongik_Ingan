import 'package:hongik_ingan/features/seat/data/seat_exception.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class SeatStatusParser {
  const SeatStatusParser();

  SeatStatus parse(SeatLocation location, String html) {
    final document = html_parser.parse(html);
    final statusTable = _findStatusTable(document);
    if (statusTable == null) {
      throw const SeatParseException('열람실 페이지에서 좌석 현황 표를 찾지 못했어요.');
    }

    final cells = statusTable
        .querySelectorAll('td')
        .where((cell) => !cell.classes.contains('table_title'))
        .map((cell) => _normalizeText(cell.text))
        .toList(growable: false);

    if (cells.length % 5 != 0) {
      throw const SeatParseException('열람실 좌석 데이터 형식이 올바르지 않아요.');
    }

    final seats = <Seat>[];
    for (var index = 0; index < cells.length; index += 5) {
      final name = cells[index];
      if (name.isEmpty) {
        throw const SeatParseException('열람실 이름이 비어 있어요.');
      }

      final totalSeats = _parseInt(cells[index + 1]);
      final usedSeats = _parseInt(cells[index + 2]);
      final availableSeats = _parseInt(cells[index + 3]);
      final usageRate = _parseRate(cells[index + 4], totalSeats, usedSeats);

      seats.add(
        Seat(
          name: name,
          totalSeats: totalSeats,
          usedSeats: usedSeats,
          availableSeats: availableSeats,
          usageRate: usageRate,
        ),
      );

      if (name == '계') {
        break;
      }
    }

    if (seats.isEmpty) {
      throw const SeatParseException('열람실 좌석 데이터가 비어 있어요.');
    }

    return SeatStatus(
      location: location,
      seats: seats,
      updatedAt: DateTime.now(),
    );
  }

  dom.Element? _findStatusTable(dom.Document document) {
    dom.Element? statusTable;
    var statusTableCellCount = 1 << 30;

    for (final table in document.querySelectorAll('table')) {
      final headers = table
          .querySelectorAll('td.table_title')
          .map((cell) => _normalizeText(cell.text))
          .toSet();
      if (headers.contains('열람실명') &&
          headers.contains('전체좌석') &&
          headers.contains('사용좌석') &&
          headers.contains('잔여좌석')) {
        final cellCount = table.querySelectorAll('td').length;
        if (cellCount < statusTableCellCount) {
          statusTable = table;
          statusTableCellCount = cellCount;
        }
      }
    }
    return statusTable;
  }

  static String _normalizeText(String text) {
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _parseInt(String text) {
    final match = RegExp(r'[0-9][0-9,]*').firstMatch(text);
    if (match == null) {
      throw const SeatParseException('열람실 좌석 수를 읽지 못했어요.');
    }

    final numericText = match.group(0)!.replaceAll(',', '');
    final parsed = int.tryParse(numericText);
    if (parsed == null) {
      throw const SeatParseException('열람실 좌석 수를 읽지 못했어요.');
    }
    return parsed;
  }

  static double _parseRate(String text, int totalSeats, int usedSeats) {
    final numericText = text.replaceAll('%', '').trim();
    final parsed = double.tryParse(numericText);
    if (parsed != null) {
      return parsed;
    }
    if (totalSeats <= 0) {
      return 0;
    }
    return usedSeats / totalSeats * 100;
  }
}
