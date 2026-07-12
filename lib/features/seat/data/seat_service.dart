import 'dart:convert';

// ignore: implementation_imports
import 'package:charset/src/euc_kr_table.dart' as euc_kr_table;
import 'package:dio/dio.dart';
import 'package:hongik_ingan/core/logging/logger.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/seat/data/seat_exception.dart';
import 'package:hongik_ingan/features/seat/data/seat_status_parser.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

export 'seat_exception.dart';

class SeatService {
  SeatService(
    this._transport, {
    SeatStatusParser parser = const SeatStatusParser(),
  }) : _parser = parser;

  final SchoolHttpTransport _transport;
  final Map<SeatLocation, String> _statusUrls = {
    SeatLocation.studentHall: 'http://203.249.67.222/',
    SeatLocation.tBuilding: 'http://203.249.65.81/',
    SeatLocation.rBuilding: 'http://223.194.83.66/',
  };
  final SeatStatusParser _parser;

  /// 지정한 열람실의 좌석 현황을 조회.
  ///
  /// 서버 통신 또는 응답 파싱에 실패하면 [SeatServiceException]을 던진다.
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
      return _parser.parse(location, body);
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

    return _decodeEucKr(bytes);
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
      final charCode = euc_kr_table.utf8ToEucKr[code];
      buffer.writeCharCode(charCode ?? unicodeReplacementCharacterRune);
    }
    return buffer.toString();
  }
}
