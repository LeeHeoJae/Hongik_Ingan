import 'dart:convert';

import 'package:dio/dio.dart';

import '../logging/log_diagnostics.dart' show boundedLogText;
import '../logging/logger.dart';

const _requestLogKey = 'diagnosticRequest';
const logRequestIdKey = 'diagnosticRequestId';
const logStageKey = 'diagnosticStage';
int _nextRequestId = 0;
final _requestSession = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

void _writeLog(String message, LogLevel level) => logMsg(message, level: level);

/// Does not log headers, request payloads, query strings, or binary bodies.
class SchoolLogInterceptor extends Interceptor {
  SchoolLogInterceptor({this.write = _writeLog});

  final void Function(String, LogLevel) write;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final request = SchoolRequestLog(
      options.uri,
      options.method,
      stage: options.extra[logStageKey]?.toString() ?? 'standard',
      write: write,
    );
    options.extra[_requestLogKey] = request;
    options.extra[logRequestIdKey] = request.id;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    (response.requestOptions.extra[_requestLogKey] as SchoolRequestLog?)
        ?.finish(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    (err.requestOptions.extra[_requestLogKey] as SchoolRequestLog?)?.finish(
      err.response,
      errorType: err.type,
    );
    handler.next(err);
  }
}

class SchoolRequestLog {
  SchoolRequestLog(
    Uri target,
    this.method, {
    required this.stage,
    this.write = _writeLog,
  }) : endpoint = '${target.host}${target.path}',
       id = '$_requestSession-${++_nextRequestId}' {
    write('http start id=$id $method $endpoint stage=$stage', LogLevel.debug);
  }

  final String id;
  final String endpoint;
  final String method;
  final String stage;
  final void Function(String, LogLevel) write;
  final _watch = Stopwatch()..start();

  void finish(
    Response<dynamic>? response, {
    DioExceptionType? errorType,
    Map<String, Object?> context = const {},
  }) {
    _watch.stop();
    response?.requestOptions.extra[logRequestIdKey] = id;
    if (response != null) logResponseDiagnostics(response, write: write);
    final data = response?.data;
    final bytes = data is List<int>
        ? data.length
        : data is String
        ? utf8.encode(data).length
        : null;
    final failed =
        (response?.statusCode ?? 0) >= 400 ||
        (errorType != null && errorType != DioExceptionType.cancel);
    final fields = context.entries.map((e) => '${e.key}=${e.value}').join(' ');
    write(
      'http id=$id $method $endpoint stage=$stage '
      'status=${response?.statusCode ?? 'none'} elapsedMs=${_watch.elapsedMilliseconds} '
      'bytes=${bytes ?? 'unknown'} error=${errorType?.name ?? 'none'}'
      '${fields.isEmpty ? '' : ' $fields'}',
      failed ? LogLevel.warning : LogLevel.info,
    );
  }
}

Map<String, Object?> responseLogContext(
  Response<dynamic>? response, {
  RequestOptions? request,
}) {
  final options = response?.requestOptions ?? request;
  return {
    if (options != null)
      'requestId': options.extra[logRequestIdKey] ?? 'untracked',
    if (response != null) 'status': response.statusCode,
  };
}

/// Kept in the diagnostic buffer until failure, sharing, or detailed mode.
void logResponseDiagnostics(
  Response<dynamic> response, {
  void Function(String, LogLevel) write = _writeLog,
}) {
  final data = response.data;
  if (data == null ||
      data is List<int> ||
      response.requestOptions.responseType == ResponseType.stream) {
    return;
  }
  if (response.requestOptions.extra['diagnosticBodyRecorded'] == true) return;
  response.requestOptions.extra['diagnosticBodyRecorded'] = true;
  final text = maskLogMessage(data.toString());
  // Prefer semantic failure clues when they appear beyond a large HTML header.
  final clue = RegExp(
    r'alert\s*\(|SSO 시스템 연동|시스템 연동|통합 로그인',
    caseSensitive: false,
  ).firstMatch(text);
  final start = clue == null || clue.start < 256 ? 0 : clue.start - 256;
  final preview = boundedLogText(
    text.substring(start).replaceAll(RegExp(r'\s+'), ' '),
  );
  write(
    'http body id=${response.requestOptions.extra[logRequestIdKey] ?? 'untracked'} '
    'status=${response.statusCode} originalChars=${data.toString().length} '
    'excerptOffset=$start $preview',
    LogLevel.debug,
  );
}
