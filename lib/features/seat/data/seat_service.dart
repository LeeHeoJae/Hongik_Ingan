import 'dart:convert';

// ignore: implementation_imports
import 'package:charset/src/euc_kr_table.dart' as euc_kr_table;
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class SeatServiceException implements Exception {
  const SeatServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SeatParseException extends SeatServiceException {
  const SeatParseException(super.message);
}

class SeatService {
  SeatService(this._transport, {Map<SeatLocation, String>? statusUrls})
    : _statusUrls = statusUrls ?? _defaultStatusUrls;

  static const Map<SeatLocation, String> _defaultStatusUrls = {
    SeatLocation.studentHall: 'http://203.249.67.222/',
    SeatLocation.tBuilding: 'http://203.249.65.81/',
    SeatLocation.rBuilding: 'http://223.194.83.66/',
  };

  final SchoolHttpTransport _transport;
  final Map<SeatLocation, String> _statusUrls;

  Future<SeatStatus> fetchStatus(SeatLocation location) async {
    final url = _statusUrls[location];
    if (url == null) {
      throw const SeatServiceException('지원하지 않는 열람실 위치입니다.');
    }

    try {
      final response = await _transport.get<List<int>>(
        url,
        options: const SchoolRequestOptions(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'text/html,*/*'},
        ),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw const SeatServiceException('열람실 서버가 정상 응답을 보내지 않았습니다.');
      }

      final body = _decodeResponseBody(response);
      if (body == null || body.trim().isEmpty) {
        throw const SeatParseException('열람실 응답이 비어 있습니다.');
      }
      return parseStatus(location, body);
    } on SeatServiceException {
      rethrow;
    } on DioException catch (e) {
      logMsg('열람실 현황 요청 실패: ${e.message}', level: .error);
      throw const SeatServiceException('열람실 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      logMsg('열람실 현황 처리 실패: $e', level: .error);
      throw const SeatParseException('열람실 페이지 형식이 변경되어 좌석 정보를 읽지 못했습니다.');
    }
  }

  String? _decodeResponseBody(Response<List<int>> response) {
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final utf8Body = utf8.decode(bytes, allowMalformed: true);
    if (_looksLikeSeatStatusHtml(utf8Body)) {
      return utf8Body;
    }

    final contentType = response.headers.value('content-type') ?? '';
    final charset = RegExp(
      r'charset=([^;]+)',
      caseSensitive: false,
    ).firstMatch(contentType)?.group(1)?.trim().toLowerCase();

    if (charset == 'euc-kr' ||
        charset == 'cp949' ||
        charset == 'ks_c_5601-1987') {
      return _decodeEucKr(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _decodeEucKr(List<int> bytes) {
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
      // The charset package table name is reversed; this map is EUC-KR to Unicode.
      final charCode = euc_kr_table.utf8ToEucKr[code];
      buffer.writeCharCode(charCode ?? unicodeReplacementCharacterRune);
    }
    return buffer.toString();
  }

  bool _looksLikeSeatStatusHtml(String body) {
    return body.contains('열람실명') &&
        body.contains('전체좌석') &&
        body.contains('사용좌석') &&
        body.contains('잔여좌석');
  }

  SeatStatus parseStatus(SeatLocation location, String html) {
    final document = html_parser.parse(html);
    final statusTable = _findStatusTable(document);
    if (statusTable == null) {
      throw const SeatParseException('열람실 페이지에서 좌석 현황 표를 찾지 못했습니다.');
    }

    final cells = statusTable
        .querySelectorAll('td')
        .where((cell) => !cell.classes.contains('table_title'))
        .map((cell) => _normalizeText(cell.text))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);

    final seats = <Seat>[];
    for (var index = 0; index + 4 < cells.length; index += 5) {
      final name = cells[index];
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
      throw const SeatParseException('열람실 좌석 데이터가 비어 있습니다.');
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
    final numericText = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numericText) ?? 0;
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
